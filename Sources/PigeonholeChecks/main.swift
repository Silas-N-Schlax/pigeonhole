import AppKit
import Carbon.HIToolbox
import Foundation
@testable import PigeonholeCore

// Run with `swift run PigeonholeChecks`. Exits non-zero if anything fails.

var failures = 0
var currentCase = "<no case>"

func check(_ name: String, _ body: () throws -> Void) {
    currentCase = name
    do { try body() } catch { fail("threw \(error)") }
}

@MainActor
func check(_ name: String, _ body: () async throws -> Void) async {
    currentCase = name
    do { try await body() } catch { fail("threw \(error)") }
}

func expect(_ condition: Bool, _ message: String, line: Int = #line) {
    if !condition { fail("\(message) (line \(line))") }
}

func fail(_ message: String) {
    failures += 1
    print("✗ \(currentCase): \(message)")
}

let base = Date(timeIntervalSince1970: 1_790_000_000)

func pr(
    _ title: String = "Something",
    owner: String = "silasns",
    repo: String = "pigeonhole",
    draft: Bool = false,
    decision: ReviewDecision? = .reviewRequired,
    pending: Int = 0,
    approvals: Int = 0,
    unresolved: Int = 0,
    checks: CheckState = .passing
) -> PullRequest {
    PullRequest(
        id: UUID().uuidString, number: 1, title: title,
        url: URL(string: "https://github.com/\(owner)/\(repo)/pull/1")!,
        owner: owner, repo: repo, branch: "branch", author: "someone",
        isDraft: draft, updatedAt: base, reviewDecision: decision,
        pendingReviewers: pending, approvals: approvals, unresolvedThreads: unresolved,
        checks: checks, additions: 1, deletions: 1
    )
}

// MARK: - Status

check("drafts are in progress whatever else is going on") {
    let status = Status(pr(draft: true, decision: .changesRequested, checks: .failing))
    expect(status.slot == .inProgress, "slot \(status.slot)")
    expect(status.label == "Draft", status.label)
}

check("changes requested outranks failing CI") {
    let status = Status(pr(decision: .changesRequested, checks: .failing))
    expect(status.slot == .needsAction && status.label == "Changes requested", status.label)
}

check("failing CI needs action") {
    expect(Status(pr(checks: .failing)).label == "CI failing", "label")
}

check("unresolved comments need action, and say so when approved") {
    expect(Status(pr(unresolved: 1)).label == "1 unresolved comment", Status(pr(unresolved: 1)).label)
    let approved = Status(pr(decision: .approved, approvals: 1, unresolved: 3))
    expect(approved.label == "Approved · 3 unresolved comments", approved.label)
    expect(approved.slot == .needsAction, "slot")
}

check("approved and green is ready to merge") {
    let status = Status(pr(decision: .approved, approvals: 1))
    expect(status.slot == .needsAction && status.label == "Approved · ready to merge", status.label)
}

check("approved with checks still running waits in review") {
    let status = Status(pr(decision: .approved, checks: .running))
    expect(status.slot == .inReview, "slot \(status.slot)")
}

check("no required reviews but an approval counts as approved") {
    let status = Status(pr(decision: nil, approvals: 1))
    expect(status.label == "Approved · ready to merge", status.label)
}

check("waiting labels") {
    expect(Status(pr(pending: 2)).label == "Waiting on 2 reviewers", Status(pr(pending: 2)).label)
    expect(Status(pr(pending: 1)).label == "Waiting on 1 reviewer", "one reviewer")
    expect(Status(pr()).label == "Waiting for review", "nobody requested")
    expect(Status(pr(approvals: 1)).label == "1 approved", "partial approval")
    expect(Status(pr(approvals: 1)).slot == .inReview, "partial approval slot")
}

// MARK: - Age

check("ages") {
    let cases: [(TimeInterval, String)] = [
        (10, "now"), (120, "2m"), (3 * 3_600, "3h"), (2 * 86_400, "2d"),
        (15 * 86_400, "2w"), (65 * 86_400, "2mo"), (400 * 86_400, "1y"), (-50, "now"),
    ]
    for (offset, expected) in cases {
        let got = Age.short(from: base, to: base.addingTimeInterval(offset))
        expect(got == expected, "\(offset)s gave \(got), wanted \(expected)")
    }
}

check("activity window") {
    let old = pr()
    let now = base.addingTimeInterval(45 * 86_400)
    expect(!ActivityWindow.days30.includes(old, now: now), "45 days is outside 30")
    expect(ActivityWindow.days60.includes(old, now: now), "45 days is inside 60")
    expect(ActivityWindow.all.includes(old, now: base.addingTimeInterval(5_000 * 86_400)), "all")
    expect(ActivityWindow.days14.includes(old, now: base.addingTimeInterval(14 * 86_400)), "edge counts")
    expect(ActivityWindow.standard == .days30, "default is 30 days")
}

// MARK: - Filters

let client = Tag(name: "Client", colorSlot: 1, repos: ["northwind/web"])
let side = Tag(name: "Side", colorSlot: 3, repos: ["silasns/pigeonhole", "northwind/web"])

check("owner filter") {
    let mine = pr(owner: "Silas-N-Schlax")
    let org = pr(owner: "northwind", repo: "web")
    expect(BoardFilter(owner: .personal).matches(mine, viewer: "silas-n-schlax", tags: []), "personal ignores case")
    expect(!BoardFilter(owner: .personal).matches(org, viewer: "Silas-N-Schlax", tags: []), "org isn't personal")
    expect(BoardFilter(owner: .owner("northwind")).matches(org, viewer: "x", tags: []), "named owner")
    expect(BoardFilter().matches(org, viewer: "x", tags: []), "all")
}

check("tag filter, including untagged and repos in two tags") {
    let web = pr(owner: "northwind", repo: "web")
    let api = pr(owner: "northwind", repo: "api")
    let tags = [client, side]
    expect(BoardFilter(tag: .tag(client.id)).matches(web, viewer: "x", tags: tags), "client")
    expect(BoardFilter(tag: .tag(side.id)).matches(web, viewer: "x", tags: tags), "same repo in side")
    expect(!BoardFilter(tag: .tag(client.id)).matches(api, viewer: "x", tags: tags), "api isn't client")
    expect(BoardFilter(tag: .untagged).matches(api, viewer: "x", tags: tags), "api is untagged")
    expect(!BoardFilter(tag: .untagged).matches(web, viewer: "x", tags: tags), "web is tagged")
    expect(!BoardFilter(tag: .tag(UUID())).matches(web, viewer: "x", tags: tags), "deleted tag matches nothing")
}

check("both filters at once") {
    let filter = BoardFilter(owner: .owner("northwind"), tag: .tag(client.id))
    expect(filter.matches(pr(owner: "northwind", repo: "web"), viewer: "x", tags: [client]), "both hold")
    expect(!filter.matches(pr(owner: "fieldkit", repo: "web"), viewer: "x", tags: [client]), "wrong owner")
}

// MARK: - Decoding

let sample = """
{"data":{"viewer":{"login":"Silas-N-Schlax"},
 "mine":{"nodes":[
  {"id":"PR_1","number":7,"title":"Event Menus","url":"https://github.com/northwind/web/pull/7",
   "isDraft":false,"updatedAt":"2026-10-17T14:00:00Z","headRefName":"event-menus",
   "additions":12,"deletions":3,"author":{"login":"Silas-N-Schlax"},
   "repository":{"name":"web","owner":{"login":"northwind"}},
   "reviewDecision":"APPROVED","reviewRequests":{"totalCount":0},
   "latestOpinionatedReviews":{"nodes":[{"state":"APPROVED"},{"state":"COMMENTED"}]},
   "reviewThreads":{"nodes":[{"isResolved":true},{"isResolved":false}]},
   "commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}},
  null,
  {}
 ]},
 "review":{"nodes":[
  {"id":"PR_2","number":9,"title":"Bulk import","url":"https://github.com/fieldkit/site/pull/9",
   "isDraft":true,"updatedAt":"2026-10-16T09:30:00Z","headRefName":"bulk",
   "additions":1,"deletions":0,"author":null,
   "repository":{"name":"site","owner":{"login":"fieldkit"}},
   "reviewDecision":null,"reviewRequests":{"totalCount":2},
   "latestOpinionatedReviews":{"nodes":[]},"reviewThreads":{"nodes":[]},
   "commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}}
 ]}},
 "errors":[{"message":"Resource protected by organization SAML enforcement."}]}
"""

check("board decodes, skipping nulls and non-PR nodes, keeping data past errors") {
    let data = try GraphQL.decode(BoardData.self, from: Data(sample.utf8))
    let board = data.board
    expect(board.viewer == "Silas-N-Schlax", "viewer")
    expect(board.mine.count == 1, "mine count \(board.mine.count)")
    expect(board.reviews.count == 1, "review count")
    let first = board.mine[0]
    expect(first.fullRepo == "northwind/web", first.fullRepo)
    expect(first.approvals == 1, "approvals \(first.approvals)")
    expect(first.unresolvedThreads == 1, "unresolved")
    expect(first.checks == .passing, "checks")
    expect(first.reviewDecision == .approved, "decision")
    let review = board.reviews[0]
    expect(review.author == "ghost", "null author")
    expect(review.checks == .none, "no checks")
    expect(review.pendingReviewers == 2, "pending")
    expect(review.isDraft, "draft")
}

check("errors with no data throw the first message") {
    let body = #"{"data":null,"errors":[{"message":"Bad credentials"}]}"#
    do {
        _ = try GraphQL.decode(BoardData.self, from: Data(body.utf8))
        fail("didn't throw")
    } catch let error as GitHubError {
        expect(error == .graphQL("Bad credentials"), "\(error)")
    }
}

check("repo catalog splits own from contributed without repeats") {
    let body = """
    {"data":{"viewer":{"login":"me",
     "owned":{"nodes":[{"nameWithOwner":"me/a"},{"nameWithOwner":"me/b"}]},
     "member":{"nodes":[{"nameWithOwner":"org/x"},{"nameWithOwner":"me/a"}]},
     "contributed":{"nodes":[{"nameWithOwner":"org/x"},{"nameWithOwner":"other/y"}]}}}}
    """
    let catalog = try GraphQL.decode(ReposData.self, from: Data(body.utf8)).catalog
    expect(catalog.own == ["me/a", "me/b"], "\(catalog.own)")
    expect(catalog.contributed == ["org/x", "other/y"], "\(catalog.contributed)")
    let widened = catalog.adding(["me/c", "org/x", "new/z"], viewer: "me")
    expect(widened.own == ["me/a", "me/b", "me/c"], "\(widened.own)")
    expect(widened.contributed == ["org/x", "other/y", "new/z"], "\(widened.contributed)")
}

// MARK: - Tags on disk

check("tag store round trip, and a missing file is no tags") {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("pigeonhole-checks-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = TagStore(directory: directory)
    expect(store.load().isEmpty, "missing file")
    store.save([client, side])
    expect(store.load() == [client, side], "round trip")
}

// MARK: - Themes and keys

check("themes: two light, four dark, eight tag colors each") {
    expect(Theme.all.filter { !$0.isDark }.count == 2, "light")
    expect(Theme.all.filter(\.isDark).count == 4, "dark")
    expect(Theme.all.allSatisfy { $0.tags.count == Theme.slotNames.count }, "tag slots")
    expect(Set(Theme.all.map(\.id)).count == Theme.all.count, "unique ids")
    expect(Theme.named("nope") == .mailroom, "unknown falls back")
}

check("hot key display order") {
    let key = HotKey(keyCode: UInt32(kVK_ANSI_K), modifiers: UInt32(cmdKey | shiftKey | controlKey), key: "K")
    expect(key.display == "⌃⇧⌘K", key.display)
    expect(HotKey.standard.display == "⌥⌘P", HotKey.standard.display)
}

// MARK: - Keyboard

check("cursor starts on the first card of the first filled column") {
    let a = pr("a")
    expect(BoardCursor.first(in: [[], [a], []])?.id == a.id, "first")
    expect(BoardCursor.first(in: [[], []]) == nil, "nothing to select")
}

check("cursor moves sideways past empty columns, keeping its row when it can") {
    let left = [pr("l0"), pr("l1"), pr("l2")]
    let right = [pr("r0"), pr("r1")]
    let columns = [left, [], right]
    let start = BoardCursor.on(left[2].id, in: columns)!
    let over = start.moved(.right, in: columns)
    expect(over.id == right[1].id, "clamped to the last card of the next filled column")
    expect(over.moved(.right, in: columns) == over, "stops at the right edge")
    expect(over.moved(.left, in: columns).id == left[1].id, "back keeps the row it landed on")
}

check("cursor stops at the top and bottom of a column") {
    let column = [pr("a"), pr("b")]
    let top = BoardCursor.first(in: [column])!
    expect(top.moved(.up, in: [column]) == top, "top")
    let bottom = top.moved(.down, in: [column])
    expect(bottom.id == column[1].id, "down")
    expect(bottom.moved(.down, in: [column]) == bottom, "bottom")
}

check("cursor follows its PR across columns, and lands nearby when it's gone") {
    let a = pr("a"), b = pr("b"), c = pr("c")
    let cursor = BoardCursor.on(b.id, in: [[a, b], [c]])!
    expect(cursor.resolved(in: [[a], [c, b]])?.id == b.id, "moved column")
    expect(cursor.resolved(in: [[a], [c]])?.id == a.id, "gone: same column, row clamped")
    expect(cursor.resolved(in: [[], [c]])?.id == c.id, "gone: nearest filled column")
    expect(cursor.resolved(in: [[], []]) == nil, "board emptied")
}

check("keys map to commands, and ⌘ chords are left alone") {
    expect(BoardCommand(keyCode: kVK_LeftArrow, modifiers: [.numericPad, .function], characters: nil)
        == .move(.left), "arrow")
    expect(BoardCommand(keyCode: kVK_Return, modifiers: [], characters: "\r") == .open, "return")
    expect(BoardCommand(keyCode: kVK_ANSI_C, modifiers: [], characters: "c") == .copyBranch, "c")
    expect(BoardCommand(keyCode: kVK_ANSI_C, modifiers: [.shift], characters: "C") == .copyBranch, "C")
    expect(BoardCommand(keyCode: kVK_ANSI_C, modifiers: [.command], characters: "c") == nil, "⌘C")
    expect(BoardCommand(keyCode: kVK_Tab, modifiers: [], characters: "\t") == .switchTab, "tab")
    expect(BoardCommand(keyCode: kVK_ANSI_2, modifiers: [], characters: "2") == .showTab(.reviews), "2")
    expect(BoardCommand(keyCode: kVK_Escape, modifiers: [], characters: "\u{1b}") == nil, "escape")
}

// MARK: - AppState against a fake GitHub

struct FakeGitHub: GitHubClient {
    let board: Board

    func fetchBoard() async throws -> Board { board }
    func fetchRepos() async throws -> RepoCatalog { RepoCatalog(own: ["me/a"], contributed: []) }
}

await check("refresh fills the slots, and tags follow their repos") {
    let defaults = UserDefaults(suiteName: "pigeonhole-checks-\(UUID().uuidString)")!
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("pigeonhole-checks-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let fake = FakeGitHub(board: Board(
        viewer: "me",
        mine: [
            pr("draft", owner: "me", repo: "a", draft: true),
            pr("ready", owner: "org", repo: "x", decision: .approved, approvals: 1),
            pr("waiting", owner: "me", repo: "a", pending: 1),
        ],
        reviews: [pr("theirs", owner: "org", repo: "x")]
    ))
    let state = AppState(connect: { fake }, defaults: defaults, tagStore: TagStore(directory: directory))
    await MainActor.run { state.activityWindow = .all }
    await state.refresh()
    await MainActor.run {
        expect(state.visible(in: .inProgress).map(\.title) == ["draft"], "in progress")
        expect(state.visible(in: .needsAction).map(\.title) == ["ready"], "needs action")
        expect(state.needsActionCount == 1, "dot count")
        expect(state.otherOwners == ["org"], "\(state.otherOwners)")

        // The fixtures date from `base`, more than two weeks before any run of
        // these checks, so a 14 day window hides them all, dot included.
        state.activityWindow = .days14
        expect(state.visible(in: .inProgress).isEmpty, "old draft hidden")
        expect(state.needsActionCount == 0, "dot ignores hidden PRs")
        expect(state.reviewCount == 0, "review badge too")
        state.activityWindow = .all

        let id = state.addTag()
        state.renameTag(id, to: "Work")
        state.toggleRepo("org/x", in: id)
        state.filter.tag = .tag(id)
        expect(state.visible(in: .needsAction).count == 1, "tagged one shows")
        expect(state.visible(in: .inReview).isEmpty, "untagged one hides")
        expect(state.filterLabel == "Work", state.filterLabel)
        state.filter.owner = .personal
        expect(state.filterLabel == "Personal · Work", state.filterLabel)
        state.deleteTag(id)
        expect(state.filter.tag == .any, "deleting the filtered tag clears the filter")
        expect(TagStore(directory: directory).load().isEmpty, "delete saved")
    }
}

await check("keyboard selection walks the visible board and resets on tab and open") {
    let defaults = UserDefaults(suiteName: "pigeonhole-checks-\(UUID().uuidString)")!
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("pigeonhole-checks-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    let fake = FakeGitHub(board: Board(
        viewer: "me",
        mine: [
            pr("draft", owner: "me", repo: "a", draft: true),
            pr("ready", owner: "org", repo: "x", decision: .approved, approvals: 1),
        ],
        reviews: [pr("theirs", owner: "org", repo: "x")]
    ))
    let state = AppState(connect: { fake }, defaults: defaults, tagStore: TagStore(directory: directory))
    await MainActor.run { state.activityWindow = .all }
    await state.refresh()
    await MainActor.run {
        expect(state.selectedPR == nil, "nothing selected until a key")
        state.perform(.move(.down))
        expect(state.selectedPR?.title == "draft", "first press picks the first card")
        state.perform(.move(.right))
        expect(state.selectedPR?.title == "ready", "skips the empty In review column")
        state.filter.owner = .personal
        expect(state.selectedPR?.title == "draft", "filtered away, lands on the neighbour")
        state.filter.owner = .all

        state.perform(.switchTab)
        expect(state.tab == .reviews && state.selectedPR == nil, "tab switch clears")
        state.perform(.move(.down))
        expect(state.selectedPR?.title == "theirs", "review list")
        state.boardDidOpen()
        expect(state.selectedPR == nil, "opening clears")
    }
}

print(failures == 0 ? "✓ all checks passed" : "\(failures) check(s) failed")
exit(failures == 0 ? 0 : 1)
