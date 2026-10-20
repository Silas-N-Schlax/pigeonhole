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

/// Anything the owner and tag filters can sort: it lives in one repo.
public protocol RepoScoped {
    var owner: String { get }
    var fullRepo: String { get }
}

public struct PullRequest: Identifiable, Equatable, Sendable, RepoScoped {
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

    public var head: String { Branch.key(owner: owner, repo: repo, name: branch) }
}

/// A branch of yours in a local clone that has no PR yet: still on your
/// machine, or pushed but never opened.
public struct Branch: Identifiable, Equatable, Sendable, RepoScoped {
    public let owner: String
    public let repo: String
    public let name: String
    public let directory: URL
    public let updatedAt: Date
    public let isPushed: Bool

    public init(owner: String, repo: String, name: String, directory: URL, updatedAt: Date, isPushed: Bool) {
        self.owner = owner
        self.repo = repo
        self.name = name
        self.directory = directory
        self.updatedAt = updatedAt
        self.isPushed = isPushed
    }

    public var id: String { Branch.key(owner: owner, repo: repo, name: name) }
    public var fullRepo: String { "\(owner)/\(repo)" }

    /// GitHub's compare page, which offers to open the PR. Nil until pushed.
    public var url: URL? {
        guard isPushed,
              let path = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "https://github.com/\(owner)/\(repo)/compare/\(path)")
    }

    /// Lowercased because a clone's remote URL needn't match GitHub's case.
    public static func key(owner: String, repo: String, name: String) -> String {
        "\(owner)/\(repo)".lowercased() + ":" + name
    }
}

/// One card on the board, whichever kind it is.
public enum BoardItem: Identifiable, Equatable, Sendable, RepoScoped {
    case pullRequest(PullRequest)
    case branch(Branch)

    public var id: String {
        switch self {
        case .pullRequest(let pr): pr.id
        case .branch(let branch): branch.id
        }
    }

    public var title: String {
        switch self {
        case .pullRequest(let pr): pr.title
        case .branch(let branch): branch.name
        }
    }

    public var branchName: String {
        switch self {
        case .pullRequest(let pr): pr.branch
        case .branch(let branch): branch.name
        }
    }

    public var owner: String {
        switch self {
        case .pullRequest(let pr): pr.owner
        case .branch(let branch): branch.owner
        }
    }

    public var fullRepo: String {
        switch self {
        case .pullRequest(let pr): pr.fullRepo
        case .branch(let branch): branch.fullRepo
        }
    }

    public var updatedAt: Date {
        switch self {
        case .pullRequest(let pr): pr.updatedAt
        case .branch(let branch): branch.updatedAt
        }
    }

    /// What Settings lists it as once hidden.
    var label: String {
        switch self {
        case .pullRequest(let pr): "\(pr.fullRepo)#\(pr.number) \(pr.title)"
        case .branch(let branch): "\(branch.fullRepo) · \(branch.name)"
        }
    }
}

/// One fetch's worth of PRs. `viewer` is the signed-in login, which is how
/// "Personal" tells your own repos from everyone else's.
public struct Board: Equatable, Sendable {
    public let viewer: String
    public let mine: [PullRequest]
    public let reviews: [PullRequest]
    /// `Branch.key`s of your closed and merged PRs.
    public let closedHeads: Set<String>

    public init(viewer: String, mine: [PullRequest], reviews: [PullRequest], closedHeads: Set<String> = []) {
        self.viewer = viewer
        self.mine = mine
        self.reviews = reviews
        self.closedHeads = closedHeads
    }

    /// Every branch that has had a PR of yours, open or not.
    var heads: Set<String> { closedHeads.union(mine.map(\.head)) }
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
