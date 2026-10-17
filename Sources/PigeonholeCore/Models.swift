import Foundation

public enum CheckState: Equatable, Sendable {
    case passing, running, failing, none

    /// GitHub's `statusCheckRollup.state`, or nil when a commit has no checks.
    init(rollup: String?) {
        switch rollup {
        case "SUCCESS": self = .passing
        case "PENDING", "EXPECTED": self = .running
        case "FAILURE", "ERROR": self = .failing
        default: self = .none
        }
    }
}

public enum ReviewDecision: String, Equatable, Sendable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
}

public struct PullRequest: Identifiable, Equatable, Sendable {
    public let id: String
    public let number: Int
    public let title: String
    public let url: URL
    public let owner: String
    public let repo: String
    public let branch: String
    public let author: String
    public let isDraft: Bool
    public let updatedAt: Date
    public let reviewDecision: ReviewDecision?
    public let pendingReviewers: Int
    public let approvals: Int
    public let unresolvedThreads: Int
    public let checks: CheckState
    public let additions: Int
    public let deletions: Int

    public var fullRepo: String { "\(owner)/\(repo)" }
}

/// One fetch's worth of PRs. `viewer` is the signed-in login, which is how
/// "Personal" tells your own repos from everyone else's.
public struct Board: Equatable, Sendable {
    public let viewer: String
    public let mine: [PullRequest]
    public let reviews: [PullRequest]
}

/// Repos offered in the tag picker, as `owner/name`.
public struct RepoCatalog: Equatable, Sendable {
    public var own: [String]
    public var contributed: [String]

    public static let empty = RepoCatalog(own: [], contributed: [])

    public var isEmpty: Bool { own.isEmpty && contributed.isEmpty }

    /// Folds in repos seen on PRs, so a repo you only have open PRs in can
    /// still be tagged even when GitHub's contribution list leaves it out.
    func adding(_ repos: [String], viewer: String) -> RepoCatalog {
        var own = self.own
        var contributed = self.contributed
        for repo in repos where !own.contains(repo) && !contributed.contains(repo) {
            if repo.hasPrefix("\(viewer)/") { own.append(repo) } else { contributed.append(repo) }
        }
        return RepoCatalog(own: own, contributed: contributed)
    }
}

func plural(_ count: Int, _ word: String) -> String {
    "\(count) \(word)\(count == 1 ? "" : "s")"
}
