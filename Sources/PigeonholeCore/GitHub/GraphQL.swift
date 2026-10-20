import Foundation

enum Queries {
    static let board = """
    query($mine: String!, $review: String!, $closed: String!) {
      viewer { login }
      mine: search(query: $mine, type: ISSUE, first: \(AppConfig.Search.pageSize)) { nodes { ...pr } }
      review: search(query: $review, type: ISSUE, first: \(AppConfig.Search.pageSize)) { nodes { ...pr } }
      closed: search(query: $closed, type: ISSUE, first: \(AppConfig.Search.pageSize)) {
        nodes { ... on PullRequest { headRefName repository { name owner { login } } } }
      }
    }
    fragment pr on PullRequest {
      id number title url isDraft updatedAt headRefName additions deletions
      author { login }
      repository { name owner { login } }
      reviewDecision
      reviewRequests(first: 1) { totalCount }
      latestOpinionatedReviews(first: 20) { nodes { state } }
      reviewThreads(first: 100) { nodes { isResolved } }
      commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }
    }
    """

    /// Your own and collaborator repos page through here. Org repos come
    /// from `orgRepos`, since the ORGANIZATION_MEMBER affiliation leaves out
    /// most of what membership lets you see.
    static let repos = """
    query($after: String) {
      viewer {
        login
        repositories(first: 100, after: $after, ownerAffiliations: [OWNER, COLLABORATOR], orderBy: {field: PUSHED_AT, direction: DESC}) { ...page }
        organizations(first: 100) { nodes { login } }
        repositoriesContributedTo(first: 100, includeUserRepositories: false, contributionTypes: [COMMIT, PULL_REQUEST, PULL_REQUEST_REVIEW, REPOSITORY], orderBy: {field: PUSHED_AT, direction: DESC}) { ...page }
      }
    }
    \(repoPage)
    """

    static let orgRepos = """
    query($login: String!, $after: String) {
      organization(login: $login) {
        repositories(first: 100, after: $after, orderBy: {field: PUSHED_AT, direction: DESC}) { ...page }
      }
    }
    \(repoPage)
    """

    private static let repoPage = """
    fragment page on RepositoryConnection {
      pageInfo { hasNextPage endCursor }
      nodes { nameWithOwner }
    }
    """
}

enum GraphQL {
    struct Envelope<T: Decodable>: Decodable {
        let data: T?
        let errors: [Message]?
    }

    struct Message: Decodable {
        let message: String
    }

    /// Keeps whatever data came back even when `errors` is set too. An org
    /// that hasn't authorized the token reports an error but still lets the
    /// rest of the search through, and one org shouldn't blank the board.
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(Envelope<T>.self, from: data)
        if let value = envelope.data { return value }
        throw GitHubError.graphQL(envelope.errors?.first?.message ?? "Empty response")
    }
}

/// Decodes to nil instead of failing the whole list. Search results can hold
/// a null for a repo the token can't see.
struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct Nodes<T: Decodable>: Decodable {
    let nodes: [Lossy<T>]

    var items: [T] { nodes.compactMap(\.value) }
}

struct Login: Decodable {
    let login: String
}

struct BoardData: Decodable {
    let viewer: Login
    let mine: Nodes<PRNode>
    let review: Nodes<PRNode>
    let closed: Nodes<HeadNode>

    var board: Board {
        Board(
            viewer: viewer.login,
            mine: mine.items.map(\.pullRequest),
            reviews: review.items.map(\.pullRequest),
            closedHeads: Set(closed.items.map(\.key))
        )
    }
}

struct HeadNode: Decodable {
    let headRefName: String
    let repository: PRNode.Repository

    var key: String { Branch.key(owner: repository.owner.login, repo: repository.name, name: headRefName) }
}

struct PRNode: Decodable {
    struct Repository: Decodable {
        let name: String
        let owner: Login
    }

    struct Count: Decodable {
        let totalCount: Int
    }

    struct Review: Decodable {
        let state: String
    }

    struct Thread: Decodable {
        let isResolved: Bool
    }

    struct CommitNode: Decodable {
        struct Commit: Decodable {
            struct Rollup: Decodable {
                let state: String
            }

            let statusCheckRollup: Rollup?
        }

        let commit: Commit
    }

    let id: String
    let number: Int
    let title: String
    let url: URL
    let isDraft: Bool
    let updatedAt: Date
    let headRefName: String
    let additions: Int
    let deletions: Int
    let author: Login?
    let repository: Repository
    let reviewDecision: String?
    let reviewRequests: Count
    let latestOpinionatedReviews: Nodes<Review>
    let reviewThreads: Nodes<Thread>
    let commits: Nodes<CommitNode>

    var pullRequest: PullRequest {
        PullRequest(
            id: id,
            number: number,
            title: title,
            url: url,
            owner: repository.owner.login,
            repo: repository.name,
            branch: headRefName,
            // A deleted account comes back as a null author.
            author: author?.login ?? "ghost",
            isDraft: isDraft,
            updatedAt: updatedAt,
            reviewDecision: reviewDecision.flatMap(ReviewDecision.init(rawValue:)),
            pendingReviewers: reviewRequests.totalCount,
            approvals: latestOpinionatedReviews.items.filter { $0.state == "APPROVED" }.count,
            unresolvedThreads: reviewThreads.items.filter { !$0.isResolved }.count,
            checks: CheckState(rollup: commits.items.last?.commit.statusCheckRollup?.state),
            additions: additions,
            deletions: deletions
        )
    }
}

struct RepoPage: Decodable {
    struct PageInfo: Decodable {
        let hasNextPage: Bool
        let endCursor: String?
    }

    struct NameWithOwner: Decodable {
        let nameWithOwner: String
    }

    let pageInfo: PageInfo
    let nodes: [Lossy<NameWithOwner>]

    var repos: [String] { nodes.compactMap(\.value?.nameWithOwner) }
    var next: String? { pageInfo.hasNextPage ? pageInfo.endCursor : nil }
}

struct ReposData: Decodable {
    struct Viewer: Decodable {
        let login: String
        let repositories: RepoPage
        let organizations: Nodes<Login>
        let repositoriesContributedTo: RepoPage
    }

    let viewer: Viewer
}

struct OrgReposData: Decodable {
    struct Organization: Decodable {
        let repositories: RepoPage
    }

    let organization: Organization?
}
