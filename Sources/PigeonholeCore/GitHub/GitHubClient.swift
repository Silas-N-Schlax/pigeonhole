import Foundation

/// Every call the app makes to GitHub. All of them read; nothing writes.
/// `GitHubAPI` talks to api.github.com; the checks use a fake.
public protocol GitHubClient: Sendable {
    func fetchBoard() async throws -> Board
    func fetchRepos() async throws -> RepoCatalog
}

public enum GitHubError: Error, Equatable {
    case unauthorized
    case http(Int)
    case graphQL(String)
}

public enum GitHubCLIError: Error, Equatable {
    case notInstalled
    case notLoggedIn
}

/// Borrows the GitHub CLI's login rather than asking for a token of our own:
/// one login already covers every org you've authorized it for, and the app
/// keeps nothing in the Keychain, so rebuilds never prompt.
public enum GitHubCLI {
    /// GUI apps don't inherit your shell's PATH, so look where Homebrew and
    /// the installer put it.
    static let candidates = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"]

    public static func token() async throws -> String {
        try await Task.detached { try readToken() }.value
    }

    static func readToken() throws -> String {
        let environment = ProcessInfo.processInfo.environment
        for key in ["GH_TOKEN", "GITHUB_TOKEN"] {
            if let token = environment[key], !token.isEmpty { return token }
        }
        guard let path = candidates.first(where: FileManager.default.isExecutableFile) else {
            throw GitHubCLIError.notInstalled
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "token"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let token = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0, !token.isEmpty else {
            throw GitHubCLIError.notLoggedIn
        }
        return token
    }
}

public struct GitHubAPI: GitHubClient {
    let token: String
    let session: URLSession
    let endpoint: URL

    public init(
        token: String,
        session: URLSession = .shared,
        endpoint: URL = URL(string: "https://api.github.com/graphql")!
    ) {
        self.token = token
        self.session = session
        self.endpoint = endpoint
    }

    public func fetchBoard() async throws -> Board {
        let data: BoardData = try await post(Queries.board, variables: [
            "mine": AppConfig.Search.mine,
            "review": AppConfig.Search.reviews,
            "closed": AppConfig.Search.closed,
        ])
        return data.board
    }

    public func fetchRepos() async throws -> RepoCatalog {
        let data: ReposData = try await post(Queries.repos, variables: [:])
        return data.catalog
    }

    private func post<T: Decodable>(_ query: String, variables: [String: String]) async throws -> T {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Pigeonhole", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "query": query,
            "variables": variables,
        ])
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw GitHubError.unauthorized }
        guard (200..<300).contains(status) else { throw GitHubError.http(status) }
        return try GraphQL.decode(T.self, from: data)
    }
}
