import Foundation
import Observation
import ServiceManagement

public enum BoardTab: String {
    case mine, reviews
}

/// The single store. Views read it from the environment and call its
/// methods; nothing else touches GitHub or the disk.
@MainActor
@Observable
public final class AppState {
    public private(set) var board: Board?
    /// Every branch of yours the last scan found, before any filtering.
    public private(set) var branches: [Branch] = []
    public private(set) var catalog = RepoCatalog.empty
    public private(set) var tags: [Tag]
    public private(set) var lastUpdated: Date?
    public private(set) var isRefreshing = false
    public private(set) var isLoadingRepos = false
    public private(set) var errorMessage: String?
    /// The clock the cards' ages read against. Moved on each refresh and
    /// each open rather than ticking, so an idle board does no work.
    public private(set) var now: Date = .now
    public var tab: BoardTab = .mine {
        didSet { cursor = nil }
    }
    public var filter = BoardFilter()
    /// A short confirmation the footer shows in place of its usual line.
    public private(set) var notice: String?
    /// Nil while the shortcut palette is closed.
    public private(set) var palette: ShortcutPalette?

    public var themeID: String {
        didSet { defaults.set(themeID, forKey: AppConfig.Defaults.themeID) }
    }
    public var fontPresetID: String {
        didSet { defaults.set(fontPresetID, forKey: AppConfig.Defaults.fontPresetID) }
    }
    public var textSize: TextSize {
        didSet { defaults.set(textSize.rawValue, forKey: AppConfig.Defaults.textSize) }
    }
    public var refreshMinutes: Int {
        didSet {
            defaults.set(refreshMinutes, forKey: AppConfig.Defaults.refreshMinutes)
            if ticker != nil { start() }
        }
    }
    public var showActionDot: Bool {
        didSet { defaults.set(showActionDot, forKey: AppConfig.Defaults.showActionDot) }
    }
    public var activityWindow: ActivityWindow {
        didSet { defaults.set(activityWindow.rawValue, forKey: AppConfig.Defaults.activityWindow) }
    }
    public var hotKey: HotKey {
        didSet {
            if let data = try? JSONEncoder().encode(hotKey) {
                defaults.set(data, forKey: AppConfig.Defaults.hotKey)
            }
            onHotKeyChange?(hotKey)
        }
    }
    public var onHotKeyChange: ((HotKey) -> Void)?
    /// Settings is an AppKit window, so the app delegate opens it.
    public var onOpenSettings: (() -> Void)?
    /// Where to look for clones whose branches have no PR yet.
    public var branchFolders: [String] {
        didSet {
            defaults.set(branchFolders, forKey: AppConfig.Defaults.branchFolders)
            Task { await rescanBranches() }
        }
    }
    public private(set) var hidden: [HiddenItem] {
        didSet {
            if let data = try? JSONEncoder().encode(hidden) {
                defaults.set(data, forKey: AppConfig.Defaults.hidden)
            }
        }
    }

    private let connect: () async throws -> GitHubClient
    private let scanBranches: @Sendable ([URL]) async -> [Branch]
    private var client: GitHubClient?
    private let defaults: UserDefaults
    private let tagStore: TagStore
    private var ticker: Task<Void, Never>?
    private var cursor: BoardCursor?
    private var noticeTask: Task<Void, Never>?

    public convenience init() {
        self.init(
            connect: { GitHubAPI(token: try await GitHubCLI.token()) },
            defaults: .standard,
            tagStore: TagStore(directory: AppConfig.supportDirectory),
            scanBranches: { await LocalBranches.scan($0) }
        )
    }

    /// Tests hand in their own client, storage and branches, and never reach
    /// GitHub or the disk's repos.
    init(
        connect: @escaping () async throws -> GitHubClient,
        defaults: UserDefaults,
        tagStore: TagStore,
        scanBranches: @escaping @Sendable ([URL]) async -> [Branch] = { _ in [] }
    ) {
        self.connect = connect
        self.scanBranches = scanBranches
        self.defaults = defaults
        self.tagStore = tagStore
        self.tags = tagStore.load()
        themeID = defaults.string(forKey: AppConfig.Defaults.themeID) ?? Theme.mailroom.id
        fontPresetID = defaults.string(forKey: AppConfig.Defaults.fontPresetID) ?? FontPreset.standard.id
        textSize = defaults.string(forKey: AppConfig.Defaults.textSize)
            .flatMap(TextSize.init(rawValue:)) ?? .regular
        let minutes = defaults.integer(forKey: AppConfig.Defaults.refreshMinutes)
        refreshMinutes = AppConfig.Refresh.minuteOptions.contains(minutes)
            ? minutes : AppConfig.Refresh.defaultMinutes
        showActionDot = defaults.object(forKey: AppConfig.Defaults.showActionDot) as? Bool ?? true
        activityWindow = defaults.string(forKey: AppConfig.Defaults.activityWindow)
            .flatMap(ActivityWindow.init(rawValue:)) ?? .standard
        hotKey = defaults.data(forKey: AppConfig.Defaults.hotKey)
            .flatMap { try? JSONDecoder().decode(HotKey.self, from: $0) } ?? .standard
        branchFolders = defaults.stringArray(forKey: AppConfig.Defaults.branchFolders) ?? Self.foundCodeFolders()
        hidden = defaults.data(forKey: AppConfig.Defaults.hidden)
            .flatMap { try? JSONDecoder().decode([HiddenItem].self, from: $0) } ?? []
    }

    /// The usual homes for clones plus any other home folder that holds
    /// one, as a starting point until you pick.
    private static func foundCodeFolders() -> [String] {
        let files = FileManager.default
        let home = files.homeDirectoryForCurrentUser
        let usual = AppConfig.Branches.defaultFolders
            .map { home.appendingPathComponent($0) }
            .filter { files.fileExists(atPath: $0.path) }
        let skipped = AppConfig.Branches.skippedHomeFolders.union(AppConfig.Branches.defaultFolders)
        let others = ((try? files.contentsOfDirectory(
            at: home,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        )) ?? [])
            .filter { folder in
                let values = try? folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                return values?.isDirectory == true && values?.isSymbolicLink != true
                    && !skipped.contains(folder.lastPathComponent)
            }
            .filter { !LocalBranches.repositories(in: [$0]).isEmpty }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
        return (usual + others).map(\.path)
    }

    // MARK: - Appearance

    public var theme: Theme { Theme.named(themeID) }
    public var typography: Typography {
        Typography(preset: FontPreset.named(fontPresetID), size: textSize)
    }

    // MARK: - Fetching

    /// Starts, or restarts, the refresh loop at the current interval.
    public func start() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                let minutes = self?.refreshMinutes ?? AppConfig.Refresh.defaultMinutes
                try? await Task.sleep(for: .seconds(minutes * 60))
            }
        }
    }

    public func boardDidOpen() {
        now = .now
        cursor = nil
        notice = nil
        palette = nil
        let stale = lastUpdated.map { now.timeIntervalSince($0) > AppConfig.Refresh.staleAfter } ?? true
        if stale { Task { await refresh() } }
    }

    public func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        async let scanned = scanBranches(folderURLs)
        do {
            let fetched = try await currentClient().fetchBoard()
            board = fetched
            branches = await scanned
            lastUpdated = .now
            now = .now
            errorMessage = nil
        } catch {
            handle(error)
        }
    }

    public func rescanBranches() async {
        branches = await scanBranches(folderURLs)
    }

    private var folderURLs: [URL] {
        branchFolders.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// The tag picker's list. Fetched once when Settings asks for it, not on
    /// every refresh: it changes rarely and costs a second query.
    public func loadReposIfNeeded() async {
        guard catalog.isEmpty, !isLoadingRepos else { return }
        isLoadingRepos = true
        defer { isLoadingRepos = false }
        do {
            let fetched = try await currentClient().fetchRepos()
            catalog = fetched.adding(seenRepos)
        } catch {
            catalog = RepoCatalog.empty.adding(seenRepos)
            handle(error)
        }
    }

    private func currentClient() async throws -> GitHubClient {
        if let client { return client }
        let made = try await connect()
        client = made
        return made
    }

    private func handle(_ error: Error) {
        // A rejected token may have been refreshed by `gh auth login` since,
        // so ask the CLI again next time instead of retrying a dead one.
        if error as? GitHubError == .unauthorized || error is GitHubCLIError { client = nil }
        errorMessage = Self.describe(error)
    }

    static func describe(_ error: Error) -> String {
        switch error {
        case GitHubCLIError.notInstalled:
            return "Install the GitHub CLI (brew install gh), then run gh auth login."
        case GitHubCLIError.notLoggedIn:
            return "Run gh auth login in Terminal, then refresh."
        case GitHubError.unauthorized:
            return "GitHub turned the token down. Run gh auth login again."
        case GitHubError.http(let code):
            return "GitHub answered \(code). Trying again on the next refresh."
        case GitHubError.graphQL(let message):
            return message
        default:
            return error.localizedDescription
        }
    }

    // MARK: - What the board shows

    public var viewer: String { board?.viewer ?? "" }

    /// Everything below reads these three rather than `board`, so a card
    /// outside the activity window, or hidden, is gone from the slots, the
    /// counts, the owner list and the menu bar dot alike.
    private var mine: [PullRequest] {
        (board?.mine ?? []).filter { activityWindow.includes($0, now: now) && !isHidden($0.id) }
    }

    private var reviews: [PullRequest] {
        (board?.reviews ?? []).filter { activityWindow.includes($0, now: now) && !isHidden($0.id) }
    }

    /// Waits for the board, since until then every branch looks PR-less.
    private var branchesWithoutPRs: [Branch] {
        guard let heads = board?.heads else { return [] }
        return branches.filter {
            !heads.contains($0.id) && activityWindow.includes($0.updatedAt, now: now) && !isHidden($0.id)
        }
    }

    private var source: [BoardItem] {
        tab == .mine
            ? mine.map(BoardItem.pullRequest) + branchesWithoutPRs.map(BoardItem.branch)
            : reviews.map(BoardItem.pullRequest)
    }

    /// Unwindowed: an old PR's repo is still one you might want to tag.
    private var seenRepos: [String] {
        ((board?.mine ?? []) + (board?.reviews ?? [])).map(\.fullRepo) + branches.map(\.fullRepo)
    }

    /// In progress mixes drafts with PR-less branches, newest first.
    public func visible(in slot: Slot) -> [BoardItem] {
        var items = mine.filter { Status($0).slot == slot }.map(BoardItem.pullRequest)
        if slot == .inProgress {
            items = (items + branchesWithoutPRs.map(BoardItem.branch)).sorted { $0.updatedAt > $1.updatedAt }
        }
        return items.filter { filter.matches($0, viewer: viewer, tags: tags) }
    }

    public var visibleReviews: [PullRequest] {
        reviews.filter { filter.matches($0, viewer: viewer, tags: tags) }
    }

    /// Ignores the owner and tag filters, so the menu bar dot doesn't hide
    /// behind them.
    public var needsActionCount: Int {
        mine.filter { Status($0).slot == .needsAction }.count
    }

    public var reviewCount: Int { reviews.count }

    // MARK: - Keyboard

    /// The visible cards in keyboard order: one column per slot, or a
    /// single column for the review list.
    private var columns: [[BoardItem]] {
        tab == .mine ? Slot.allCases.map(visible(in:)) : [visibleReviews.map(BoardItem.pullRequest)]
    }

    public var selectedItem: BoardItem? {
        let columns = columns
        guard let cursor = cursor?.resolved(in: columns) else { return nil }
        return columns[cursor.column][cursor.row]
    }

    public func select(_ item: BoardItem) {
        cursor = BoardCursor.on(item.id, in: columns)
    }

    public func perform(_ command: BoardCommand) {
        switch command {
        case .move(let move):
            let columns = columns
            cursor = cursor?.resolved(in: columns)?.moved(move, in: columns)
                ?? BoardCursor.first(in: columns)
        case .open:
            selectedItem?.openCopyingBranch()
        case .copyBranch:
            guard let item = selectedItem else { return }
            item.copyBranch()
            flash("Copied \(item.branchName)")
        case .hide:
            guard let item = selectedItem else { return }
            hide(item)
            flash("Hid \(item.label). U brings it back")
        case .undoHide:
            guard let last = hidden.last else { return }
            unhide(last.id)
            cursor = BoardCursor.on(last.id, in: columns) ?? cursor
            flash("Brought back \(last.label)")
        case .switchTab:
            tab = tab == .mine ? .reviews : .mine
        case .showTab(let target):
            tab = target
        case .nextOwner:
            let owners: [OwnerFilter] = [.all, .personal] + otherOwners.map(OwnerFilter.owner)
            filter.owner = owners.after(filter.owner)
        case .nextTag:
            let tags: [TagFilter] = [.any] + self.tags.map { .tag($0.id) } + [.untagged]
            filter.tag = tags.after(filter.tag)
        case .clearFilters:
            filter = BoardFilter()
        case .refresh:
            Task { await refresh() }
        case .openSettings:
            palette = nil
            onOpenSettings?()
        case .showShortcuts:
            palette = palette == nil ? ShortcutPalette() : nil
        }
    }

    public func handle(_ key: PaletteKey) {
        guard var open = palette else { return }
        switch key {
        case .close:
            palette = nil
        case .up:
            open.move(by: -1)
            palette = open
        case .down:
            open.move(by: 1)
            palette = open
        case .run:
            if let shortcut = open.highlighted { run(shortcut) }
        case .erase:
            open.erase()
            palette = open
        case .type(let text):
            // The key that opened it closes it again, until you start typing.
            if open.query.isEmpty, text == "?" {
                palette = nil
            } else {
                open.type(text)
                palette = open
            }
        }
    }

    public func run(_ shortcut: Shortcut) {
        palette = nil
        perform(shortcut.command)
    }

    public func highlight(_ shortcut: Shortcut) {
        palette?.highlight(shortcut)
    }

    private func flash(_ text: String) {
        notice = text
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(AppConfig.Board.noticeSeconds))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    public func tags(for item: some RepoScoped) -> [Tag] {
        tags.filter { $0.holds(item.fullRepo) }
    }

    /// Every owner that isn't you, from either tab, so the menu doesn't
    /// reshuffle when you switch tabs.
    public var otherOwners: [String] {
        let owners = Set((mine + reviews).map(\.owner) + branchesWithoutPRs.map(\.owner))
        return owners.filter { $0.caseInsensitiveCompare(viewer) != .orderedSame }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    public func count(owner: OwnerFilter) -> Int {
        source.filter {
            BoardFilter.matches($0, owner: owner, viewer: viewer)
                && BoardFilter.matches($0, tag: filter.tag, tags: tags)
        }.count
    }

    public func count(tag: TagFilter) -> Int {
        source.filter {
            BoardFilter.matches($0, owner: filter.owner, viewer: viewer)
                && BoardFilter.matches($0, tag: tag, tags: tags)
        }.count
    }

    public var filterLabel: String {
        let owner: String? = switch filter.owner {
        case .all: nil
        case .personal: "Personal"
        case .owner(let name): name
        }
        let tag: String? = switch filter.tag {
        case .any: nil
        case .untagged: "Untagged"
        case .tag(let id): tags.first { $0.id == id }?.name
        }
        return [owner, tag].compactMap { $0 }.joined(separator: " · ").nonEmpty ?? "All"
    }

    public var activeFilterTag: Tag? {
        guard case .tag(let id) = filter.tag else { return nil }
        return tags.first { $0.id == id }
    }

    // MARK: - Hiding

    public func hide(_ item: BoardItem) {
        guard !isHidden(item.id) else { return }
        hidden.append(HiddenItem(id: item.id, label: item.label))
    }

    public func unhide(_ id: String) {
        hidden.removeAll { $0.id == id }
    }

    private func isHidden(_ id: String) -> Bool {
        hidden.contains { $0.id == id }
    }

    // MARK: - Tags

    @discardableResult
    public func addTag() -> UUID {
        let used = Set(tags.map(\.colorSlot))
        let slot = (0..<Theme.slotNames.count).first { !used.contains($0) } ?? tags.count % Theme.slotNames.count
        let tag = Tag(name: "New tag", colorSlot: slot)
        tags.append(tag)
        tagStore.save(tags)
        return tag.id
    }

    public func renameTag(_ id: UUID, to name: String) {
        updateTag(id) { $0.name = name }
    }

    public func setColor(_ id: UUID, slot: Int) {
        updateTag(id) { $0.colorSlot = slot }
    }

    public func toggleRepo(_ repo: String, in id: UUID) {
        updateTag(id) { tag in
            if let index = tag.repos.firstIndex(of: repo) {
                tag.repos.remove(at: index)
            } else {
                tag.repos.append(repo)
            }
        }
    }

    public func deleteTag(_ id: UUID) {
        tags.removeAll { $0.id == id }
        if filter.tag == .tag(id) { filter.tag = .any }
        tagStore.save(tags)
    }

    private func updateTag(_ id: UUID, _ change: (inout Tag) -> Void) {
        guard let index = tags.firstIndex(where: { $0.id == id }) else { return }
        change(&tags[index])
        tagStore.save(tags)
    }

    // MARK: - Login item

    public var opensAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    /// Throws when macOS refuses, which it does for a copy run from outside
    /// /Applications.
    public func setOpensAtLogin(_ on: Bool) throws {
        if on {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

private extension Array where Element: Equatable {
    /// The next element, wrapping, or the first when `current` isn't here.
    func after(_ current: Element) -> Element {
        guard let index = firstIndex(of: current) else { return self[0] }
        return self[(index + 1) % count]
    }
}
