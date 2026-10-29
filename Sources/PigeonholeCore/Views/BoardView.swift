import AppKit
import SwiftUI

/// The board window: header, the three slots or the review list, footer.
public struct BoardView: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let openSettings: () -> Void
    private let close: () -> Void

    public init(openSettings: @escaping () -> Void, close: @escaping () -> Void) {
        self.openSettings = openSettings
        self.close = close
    }

    public var body: some View {
        VStack(spacing: 0) {
            BoardHeader()
            theme.line.frame(height: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            theme.line.frame(height: 1)
            BoardFooter(openSettings: openSettings)
        }
        .overlay {
            if state.palette != nil {
                theme.scrim
                    .contentShape(Rectangle())
                    .onTapGesture { state.perform(.showShortcuts) }
                    .transition(.opacity)
            }
        }
        .overlay {
            if state.palette != nil {
                ShortcutPaletteView()
                    .transition(.lift(reduceMotion: reduceMotion))
            }
        }
        .animation(.smooth(duration: AppConfig.Motion.settle), value: state.palette != nil)
        .frame(width: AppConfig.Window.boardSize.width, height: AppConfig.Window.boardSize.height)
        .background(theme.window)
        .clipShape(RoundedRectangle(cornerRadius: AppConfig.Window.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppConfig.Window.cornerRadius, style: .continuous)
                .strokeBorder(theme.ringStrong, lineWidth: 1)
        )
        .onExitCommand(perform: close)
    }

    @ViewBuilder private var content: some View {
        if state.board == nil {
            BoardPlaceholder()
        } else {
            ZStack {
                if state.tab == .mine {
                    HStack(spacing: 10) {
                        ForEach(Slot.allCases) { slot in
                            SlotColumn(slot: slot, items: state.visible(in: slot))
                        }
                    }
                    .padding(AppConfig.Board.padding)
                    .transition(.opacity)
                } else {
                    ReviewList(prs: state.visibleReviews)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: AppConfig.Motion.quick), value: state.tab)
        }
    }
}

private struct BoardPlaceholder: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type

    var body: some View {
        VStack(spacing: 12) {
            if let error = state.errorMessage {
                Text("Couldn't load your PRs")
                    .font(type.ui(14, .semibold))
                    .foregroundStyle(theme.text)
                Text(error)
                    .font(type.ui(12.5))
                    .foregroundStyle(theme.dim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
                Button("Try again") { Task { await state.refresh() } }
                    .disabled(state.isRefreshing)
            } else {
                ProgressView().controlSize(.small)
                Text("Sorting your PRs…")
                    .font(type.ui(12.5))
                    .foregroundStyle(theme.faint)
            }
        }
        .padding(24)
    }
}

private struct BoardHeader: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var state = state
        HStack(spacing: 14) {
            HStack(spacing: 8) {
                PigeonholeMark(color: theme.accent)
                    .frame(width: 20, height: 18)
                Text("Pigeonhole")
                    .font(type.ui(14, .semibold))
                    .foregroundStyle(theme.text)
            }
            SegmentedControl(
                items: [
                    SegmentItem(id: BoardTab.mine, label: "My PRs"),
                    SegmentItem(id: BoardTab.reviews, label: "Reviews", badge: state.reviewCount),
                ],
                selection: $state.tab
            )
            Spacer(minLength: 0)
            FilterMenu()
            IconButton(help: "Refresh (R)") {
                Task { await state.refresh() }
            } label: {
                ZStack {
                    if state.isRefreshing {
                        ProgressView().controlSize(.mini)
                            .transition(.blurSwap(reduceMotion: reduceMotion))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                            .transition(.blurSwap(reduceMotion: reduceMotion))
                    }
                }
                .animation(.smooth(duration: AppConfig.Motion.quick), value: state.isRefreshing)
            }
            .disabled(state.isRefreshing)
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.vertical, 10)
    }
}

/// A native menu rather than a popover: a popover would take key status
/// from the board, and the board hides when it loses key.
private struct FilterMenu: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type

    var body: some View {
        Menu {
            Section("Owner") {
                option("All", count: state.count(owner: .all), on: state.filter.owner == .all) {
                    state.filter.owner = .all
                }
                option("Personal", count: state.count(owner: .personal), on: state.filter.owner == .personal) {
                    state.filter.owner = .personal
                }
                ForEach(state.otherOwners, id: \.self) { owner in
                    option(owner, count: state.count(owner: .owner(owner)), on: state.filter.owner == .owner(owner)) {
                        state.filter.owner = .owner(owner)
                    }
                }
            }
            Section("Tag") {
                option("Any tag", count: state.count(tag: .any), on: state.filter.tag == .any) {
                    state.filter.tag = .any
                }
                ForEach(state.tags) { tag in
                    option(tag.name, count: state.count(tag: .tag(tag.id)), on: state.filter.tag == .tag(tag.id)) {
                        state.filter.tag = .tag(tag.id)
                    }
                }
                option("Untagged", count: state.count(tag: .untagged), on: state.filter.tag == .untagged) {
                    state.filter.tag = .untagged
                }
            }
        } label: {
            Text(state.filterLabel)
                .font(type.ui(12.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .foregroundStyle(theme.text)
        .padding(.leading, state.activeFilterTag == nil ? 10 : 18)
        .padding(.trailing, 6)
        .frame(height: 28)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.control)
                .shadow(color: theme.lift, radius: 1, y: 1)
        )
        .overlay(alignment: .leading) {
            if let tag = state.activeFilterTag {
                Dot(color: theme.tag(tag.colorSlot).dot, size: 6).padding(.leading, 9)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(theme.ring))
        .help("Filter by owner (O) or tag (T). ⌫ clears.")
    }

    @ViewBuilder
    private func option(_ title: String, count: Int, on: Bool, _ pick: @escaping () -> Void) -> some View {
        Button(action: pick) {
            if on {
                Label("\(title)   \(count)", systemImage: "checkmark")
            } else {
                Text("\(title)   \(count)")
            }
        }
    }
}

private struct SlotColumn: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let slot: Slot
    let items: [BoardItem]

    var body: some View {
        let inset = AppConfig.Board.slotInset
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                Dot(color: theme.dot(slot), size: 7)
                Text(slot.title)
                    .font(type.ui(12.5, .semibold))
                    .foregroundStyle(theme.text)
                Spacer(minLength: 0)
                CountBadge(count: items.count)
            }
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .padding(.top, 10)
            .padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(items) { item in
                        switch item {
                        case .pullRequest(let pr): PRCard(pr: pr)
                        case .branch(let branch): BranchCard(branch: branch)
                        }
                    }
                    if items.isEmpty {
                        Text("Nothing here")
                            .font(type.ui(12))
                            .foregroundStyle(theme.faint)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                }
                // Room for the selection halo, which sits outside the card.
                .padding(.horizontal, inset)
                .padding(.top, 3)
                .padding(.bottom, inset)
            }
            .scrollIndicators(.never)
            .followsSelection(in: items.map(\.id))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: AppConfig.Radius.slot, style: .continuous)
                .fill(theme.slot)
        )
    }
}

private struct PRCard: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let pr: PullRequest

    var body: some View {
        let item = BoardItem.pullRequest(pr)
        Button {
            item.openCopyingBranch()
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                Text(pr.title)
                    .font(type.ui(13, .semibold))
                    .foregroundStyle(theme.text)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
                    RepoName(pr: pr, showOwner: state.filter.owner == .all)
                    Text("#\(pr.number)")
                    Text("·")
                    Text(Age.short(from: pr.updatedAt, to: state.now))
                }
                .font(type.ui(11.5))
                .monospacedDigit()
                .foregroundStyle(theme.faint)
                .lineLimit(1)
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 9.5, weight: .medium))
                    Text(pr.branch)
                        .font(type.mono(10.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 6)
                    ChecksBadge(checks: pr.checks)
                        .layoutPriority(1)
                }
                .foregroundStyle(theme.faint)
                CardChips(status: Status(pr), tags: state.tags(for: pr))
                    .padding(.top, 3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(highlighted: state.selectedItem?.id == item.id)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.985))
        .onHover { if $0 { state.select(item) } }
        .cardMenu(item)
        .help("Open \(pr.fullRepo)#\(pr.number) in your browser")
    }
}

private struct BranchCard: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let branch: Branch

    var body: some View {
        let item = BoardItem.branch(branch)
        Button {
            item.openCopyingBranch()
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(theme.faint)
                    Text(branch.name)
                        .font(type.mono(12.5))
                        .foregroundStyle(theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 4) {
                    RepoName(owner: branch.owner, repo: branch.repo, showOwner: state.filter.owner == .all)
                    Text("·")
                    Text(Age.short(from: branch.updatedAt, to: state.now))
                }
                .font(type.ui(11.5))
                .monospacedDigit()
                .foregroundStyle(theme.faint)
                .lineLimit(1)
                CardChips(status: Status(branch), tags: state.tags(for: branch))
                    .padding(.top, 3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card(highlighted: state.selectedItem?.id == item.id)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.985))
        .onHover { if $0 { state.select(item) } }
        .cardMenu(item)
        .help(branch.isPushed
            ? "Compare \(branch.name) on GitHub, where you can open its PR"
            : "Not pushed yet. Opens the clone in Finder")
    }
}

/// The status first, then the tags, wrapping onto a second row when a long
/// status like "Approved · ready to merge" leaves no room.
private struct CardChips: View {
    let status: Status
    let tags: [Tag]

    var body: some View {
        FlowLayout(spacing: 4) {
            StatusChip(status: status)
            ForEach(tags) { TagChip(name: $0.name, slot: $0.colorSlot) }
        }
    }
}

private struct RepoName: View {
    @Environment(\.theme) private var theme
    let owner: String
    let repo: String
    let showOwner: Bool

    init(pr: PullRequest, showOwner: Bool) {
        self.init(owner: pr.owner, repo: pr.repo, showOwner: showOwner)
    }

    init(owner: String, repo: String, showOwner: Bool) {
        self.owner = owner
        self.repo = repo
        self.showOwner = showOwner
    }

    var body: some View {
        (showOwner ? Text("\(owner)/").foregroundColor(theme.faint) : Text(""))
            + Text(repo).foregroundColor(theme.dim)
    }
}

private struct ChecksBadge: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let checks: CheckState

    var body: some View {
        HStack(spacing: 4) {
            Dot(color: theme.dot(checks), size: 6)
            Text(label)
        }
        .font(type.ui(10.5))
        .foregroundStyle(theme.faint)
        .lineLimit(1)
    }

    private var label: String {
        switch checks {
        case .passing: "CI passing"
        case .running: "CI running"
        case .failing: "CI failing"
        case .none: "No checks"
        }
    }
}

private struct ReviewList: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let prs: [PullRequest]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 6) {
                ForEach(prs) { ReviewRow(pr: $0) }
                if prs.isEmpty {
                    Text("No reviews waiting on you here")
                        .font(type.ui(12.5))
                        .foregroundStyle(theme.faint)
                        .padding(.vertical, 40)
                }
            }
            .padding(AppConfig.Board.padding)
        }
        .scrollIndicators(.never)
        .followsSelection(in: prs.map(\.id))
    }
}

private struct ReviewRow: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let pr: PullRequest

    var body: some View {
        let item = BoardItem.pullRequest(pr)
        Button {
            item.openCopyingBranch()
        } label: {
            HStack(spacing: 12) {
                Text(pr.author.prefix(2).uppercased())
                    .font(type.ui(11, .semibold))
                    .foregroundStyle(theme.accentSoftText)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(theme.accentSoft))
                    .overlay(Circle().strokeBorder(theme.ring))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(pr.title)
                            .font(type.ui(13, .semibold))
                            .foregroundStyle(theme.text)
                            .lineLimit(1)
                        ForEach(state.tags(for: pr)) { TagChip(name: $0.name, slot: $0.colorSlot) }
                    }
                    HStack(spacing: 5) {
                        RepoName(pr: pr, showOwner: true)
                        Text("#\(pr.number)").font(type.mono(11))
                        Text("·")
                        Text("by \(pr.author)")
                        Text("·")
                        Text("updated \(Age.short(from: pr.updatedAt, to: state.now))")
                    }
                    .font(type.ui(11.5))
                    .monospacedDigit()
                    .foregroundStyle(theme.faint)
                    .lineLimit(1)
                }
                Spacer(minLength: 8)
                (Text("+\(pr.additions)").foregroundColor(theme.added)
                    + Text(" −\(pr.deletions)").foregroundColor(theme.removed))
                    .font(type.mono(11))
                    .monospacedDigit()
                HStack(spacing: 3) {
                    Text("Open")
                    Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .semibold))
                }
                .font(type.ui(11, .medium))
                .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            // Full width against the window, so they take the slot's radius.
            .card(radius: AppConfig.Radius.slot, highlighted: state.selectedItem?.id == item.id)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.99))
        .onHover { if $0 { state.select(item) } }
        .cardMenu(item)
    }
}

private struct BoardFooter: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let openSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .leading) {
                if let notice = state.notice {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.good)
                        Text(notice)
                            .foregroundStyle(theme.dim)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .id(notice)
                    .transition(.blurSwap(reduceMotion: reduceMotion))
                } else if let error = state.errorMessage, state.board != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error).lineLimit(1)
                    }
                    .foregroundStyle(theme.danger)
                    .help(error)
                    .transition(.blurSwap(reduceMotion: reduceMotion))
                } else if let updated = state.lastUpdated {
                    let age = Age.short(from: updated, to: state.now)
                    HStack(spacing: 6) {
                        Text(age == "now" ? "Updated just now" : "Updated \(age) ago")
                        Text("·")
                        if state.activityWindow == .all {
                            Text("Merged and closed PRs leave on their own")
                        } else {
                            Text("Active in the last \(state.activityWindow.label)")
                        }
                    }
                    .monospacedDigit()
                    .lineLimit(1)
                    .transition(.blurSwap(reduceMotion: reduceMotion))
                }
            }
            .animation(.smooth(duration: AppConfig.Motion.settle), value: state.notice)
            Spacer(minLength: 8)
            Button {
                state.perform(.showShortcuts)
            } label: {
                HStack(spacing: 6) {
                    KeyCap("?")
                    Text("Shortcuts")
                }
                .padding(.horizontal, 4)
                .frame(height: 24)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .help("Every keyboard shortcut, searchable")
            IconButton(help: "Settings (,)", action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 12.5))
            }
        }
        .font(type.ui(11.5))
        .foregroundStyle(theme.faint)
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 5)
    }
}

private struct FollowsSelection: ViewModifier {
    @Environment(AppState.self) private var state
    let ids: [String]

    func body(content: Content) -> some View {
        ScrollViewReader { proxy in
            content.onChange(of: state.selectedItem?.id) { _, id in
                guard let id, ids.contains(id) else { return }
                proxy.scrollTo(id)
            }
        }
    }
}

private struct CardMenu: ViewModifier {
    @Environment(AppState.self) private var state
    let item: BoardItem

    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Copy branch name") { item.copyBranch() }
            Divider()
            Button("Hide from board") { state.hide(item) }
        }
    }
}

private extension View {
    /// Keeps the keyboard selection on screen in a long column.
    func followsSelection(in ids: [String]) -> some View {
        modifier(FollowsSelection(ids: ids))
    }

    /// Right click. Hidden cards come back from Settings.
    func cardMenu(_ item: BoardItem) -> some View {
        modifier(CardMenu(item: item))
    }
}
