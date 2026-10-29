import AppKit
@testable import PigeonholeCore
import SwiftUI

// `swift run PigeonholeSnapshots <dir>` writes the README screenshots there.
// Everything shown is made up; nothing reaches GitHub.

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/screenshots")
let viewer = "you"

func sample(
    _ title: String, _ owner: String, _ repo: String, number: Int, branch: String,
    hoursAgo: Double, draft: Bool = false, decision: ReviewDecision? = .reviewRequired,
    pending: Int = 0, approvals: Int = 0, unresolved: Int = 0,
    checks: CheckState = .passing, author: String = viewer,
    additions: Int = 40, deletions: Int = 12
) -> PullRequest {
    PullRequest(
        id: "\(owner)/\(repo)#\(number)", number: number, title: title,
        url: URL(string: "https://github.com/\(owner)/\(repo)/pull/\(number)")!,
        owner: owner, repo: repo, branch: branch, author: author, isDraft: draft,
        updatedAt: Date().addingTimeInterval(-hoursAgo * 3_600), reviewDecision: decision,
        pendingReviewers: pending, approvals: approvals, unresolvedThreads: unresolved,
        checks: checks, additions: additions, deletions: deletions
    )
}

let board = Board(
    viewer: viewer,
    mine: [
        sample("Menu bar scaffold", viewer, "pigeonhole", number: 3, branch: "first-mockup", hoursAgo: 1, draft: true, checks: .none),
        sample("Stop contact button spam", "fieldkit", "site", number: 51, branch: "contact-throttle", hoursAgo: 50, draft: true),
        sample("Appearance presets for the dropdown", viewer, "keystats", number: 11, branch: "menubar-presets", hoursAgo: 96, draft: true, checks: .failing),
        sample("Add export button to reports", "northwind", "web", number: 142, branch: "reports-export", hoursAgo: 48, pending: 2),
        sample("Cache tax rates per county", viewer, "abacus", number: 27, branch: "county-rate-cache", hoursAgo: 5, approvals: 1, checks: .running),
        sample("Copy link from the tab menu", viewer, "switchboard", number: 9, branch: "copy-tab-link", hoursAgo: 26, pending: 1),
        sample("Event menus", "northwind", "web", number: 138, branch: "event-menus", hoursAgo: 72, unresolved: 3),
        sample("Add fundraiser link to navbar", "fieldkit", "site", number: 49, branch: "fundraiser-link", hoursAgo: 24, decision: .approved, approvals: 1),
        sample("Move webhook to an env var", "northwind", "api", number: 88, branch: "webhook-env", hoursAgo: 6, checks: .failing),
    ],
    reviews: [
        sample("Swap to the new color tokens", "fieldkit", "site", number: 53, branch: "tokens", hoursAgo: 0.4, author: "morgan", additions: 240, deletions: 198),
        sample("Bulk import for vendors", "northwind", "api", number: 91, branch: "bulk-import", hoursAgo: 3, author: "reese", additions: 412, deletions: 37),
        sample("Fix timezone on weekly report", "northwind", "web", number: 145, branch: "tz-fix", hoursAgo: 26, author: "kai", additions: 18, deletions: 6),
    ]
)

let branches = [
    Branch(owner: viewer, repo: "abacus", name: "rate-limit-retries", directory: URL(fileURLWithPath: "/tmp"),
           updatedAt: Date().addingTimeInterval(-3 * 3_600), isPushed: false),
    Branch(owner: "northwind", repo: "web", name: "invoice-pdf-footer", directory: URL(fileURLWithPath: "/tmp"),
           updatedAt: Date().addingTimeInterval(-30 * 3_600), isPushed: true),
]

struct SampleGitHub: GitHubClient {
    func fetchBoard() async throws -> Board { board }

    func fetchRepos() async throws -> RepoCatalog {
        RepoCatalog(repos: [
            "\(viewer)/pigeonhole", "\(viewer)/abacus", "\(viewer)/keystats", "\(viewer)/switchboard",
            "northwind/web", "northwind/api", "northwind/billing", "northwind/infra", "fieldkit/site",
        ])
    }
}

@MainActor
func makeState(theme: Theme) async -> AppState {
    let scratch = FileManager.default.temporaryDirectory
        .appendingPathComponent("pigeonhole-snapshots-\(UUID().uuidString)")
    let state = AppState(
        connect: { SampleGitHub() },
        defaults: UserDefaults(suiteName: "pigeonhole-snapshots-\(UUID().uuidString)")!,
        tagStore: TagStore(directory: scratch),
        scanBranches: { _ in branches }
    )
    state.themeID = theme.id
    let client = state.addTag()
    state.renameTag(client, to: "Client")
    state.setColor(client, slot: 1)
    state.toggleRepo("northwind/web", in: client)
    state.toggleRepo("northwind/api", in: client)
    let side = state.addTag()
    state.renameTag(side, to: "Side projects")
    state.setColor(side, slot: 3)
    for repo in ["pigeonhole", "abacus", "keystats"] { state.toggleRepo("\(viewer)/\(repo)", in: side) }
    let volunteer = state.addTag()
    state.renameTag(volunteer, to: "Volunteer")
    state.setColor(volunteer, slot: 5)
    state.toggleRepo("fieldkit/site", in: volunteer)
    await state.refresh()
    await state.loadReposIfNeeded()
    return state
}

/// Draws through a real window so native controls (switches, menus, text
/// fields) render as they do in the app, at 2x for Retina.
@MainActor
func snapshot<V: View>(_ view: V, size: CGSize, dark: Bool, padding: CGFloat, to name: String) {
    let backdrop = dark ? NSColor(white: 0.08, alpha: 1) : NSColor(white: 0.9, alpha: 1)
    let framed = view
        .frame(width: size.width, height: size.height)
        .shadow(color: .black.opacity(dark ? 0.5 : 0.18), radius: 18, y: 8)
        .padding(padding)
        .background(Color(nsColor: backdrop))
    let hosting = NSHostingView(rootView: framed)
    let total = NSSize(width: size.width + padding * 2, height: size.height + padding * 2)
    hosting.frame = NSRect(origin: .zero, size: total)
    let window = NSWindow(
        contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false
    )
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.contentView = hosting
    window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
    window.orderFrontRegardless()
    RunLoop.main.run(until: Date().addingTimeInterval(0.6))
    hosting.layoutSubtreeIfNeeded()

    let scale: CGFloat = 2
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(total.width * scale), pixelsHigh: Int(total.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else { return }
    rep.size = total
    hosting.cacheDisplay(in: hosting.bounds, to: rep)
    window.orderOut(nil)
    let url = outputDirectory.appendingPathComponent(name)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
    print("wrote \(url.path)")
}

@MainActor
func run() async {
    _ = NSApplication.shared
    NSApp.setActivationPolicy(.prohibited)
    try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    let light = await makeState(theme: .mailroom)
    let boardView = ThemedRoot { BoardView(openSettings: {}, close: {}) }.environment(light)
    snapshot(boardView, size: AppConfig.Window.boardSize, dark: false, padding: 40, to: "board-mailroom.png")

    let dark = await makeState(theme: .walnut)
    snapshot(
        ThemedRoot { BoardView(openSettings: {}, close: {}) }.environment(dark),
        size: AppConfig.Window.boardSize, dark: true, padding: 40, to: "board-walnut.png"
    )

    light.tab = .reviews
    snapshot(boardView, size: AppConfig.Window.boardSize, dark: false, padding: 40, to: "reviews.png")
    light.tab = .mine

    light.perform(.move(.right))
    light.perform(.move(.right))
    light.perform(.showShortcuts)
    snapshot(boardView, size: AppConfig.Window.boardSize, dark: false, padding: 40, to: "shortcuts.png")
    light.perform(.showShortcuts)

    let settingsSize = AppConfig.Window.settingsSize
    let rounded = { (tab: SettingsTab) in
        ThemedRoot { SettingsView(tab: tab) }
            .environment(light)
            .clipShape(RoundedRectangle(cornerRadius: AppConfig.Window.cornerRadius, style: .continuous))
    }
    snapshot(rounded(.appearance), size: settingsSize, dark: false, padding: 40, to: "settings-appearance.png")
    snapshot(rounded(.tags), size: settingsSize, dark: false, padding: 40, to: "settings-tags.png")
}

await run()
