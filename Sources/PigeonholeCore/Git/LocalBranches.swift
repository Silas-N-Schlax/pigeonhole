import Foundation

/// Finds your branches in the clones under the folders you pick. Only reads:
/// it runs `git config` and `git for-each-ref`, never fetch, so it costs no
/// network and leaves every repo as it was.
public enum LocalBranches {
    public static func scan(_ folders: [URL]) async -> [Branch] {
        await Task.detached {
            repositories(in: folders).flatMap(branches(in:))
        }.value
    }

    /// Stops at the first `.git` folder down each path, so a repo's own
    /// subfolders and worktrees, whose `.git` is a file, aren't scanned twice.
    static func repositories(in folders: [URL]) -> [URL] {
        let files = FileManager.default
        var found: [URL] = []
        func visit(_ folder: URL, depth: Int) {
            var isFolder: ObjCBool = false
            let git = folder.appendingPathComponent(".git").path
            if files.fileExists(atPath: git, isDirectory: &isFolder), isFolder.boolValue {
                found.append(folder)
                return
            }
            guard depth < AppConfig.Branches.searchDepth,
                  let children = try? files.contentsOfDirectory(
                      at: folder,
                      includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
                      options: [.skipsHiddenFiles, .skipsPackageDescendants]
                  ) else { return }
            for child in children where !AppConfig.Branches.skippedFolders.contains(child.lastPathComponent) {
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                guard values?.isDirectory == true, values?.isSymbolicLink != true else { continue }
                visit(child, depth: depth + 1)
            }
        }
        for folder in folders { visit(folder, depth: 0) }
        return found
    }

    static func branches(in repository: URL) -> [Branch] {
        guard let config = git(["config", "--get-regexp", #"^(remote\.origin\.url|user\.email)$"#], in: repository) else {
            return []
        }
        let settings = Dictionary(
            config.split(separator: "\n").compactMap { line -> (String, String)? in
                let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
                return parts.count == 2 ? (parts[0], parts[1]) : nil
            },
            // Listed system, global, then repo, so the last one wins.
            uniquingKeysWith: { _, last in last }
        )
        guard let remote = settings["remote.origin.url"], let origin = gitHubRepo(fromRemote: remote),
              let refs = git(["for-each-ref", "--format=\(refFormat)", "refs/heads", "refs/remotes/origin"], in: repository)
        else { return [] }
        return parse(refs: refs, owner: origin.owner, repo: origin.repo, directory: repository, email: settings["user.email"])
    }

    static let refFormat = "%(refname)%09%(committerdate:unix)%09%(authoremail)%09%(symref)%09%(upstream:track)"

    /// Keeps branches whose newest commit is yours, minus the default branch
    /// and any whose upstream is gone, which is what a merged PR leaves
    /// behind once GitHub deletes its branch. Without a `user.email` only
    /// local branches count, since there's no telling whose pushes are whose.
    static func parse(refs: String, owner: String, repo: String, directory: URL, email: String?) -> [Branch] {
        struct Seen {
            var date = Date.distantPast
            var author = ""
            var isLocal = false
            var isPushed = false
            var isGone = false
        }
        var seen: [String: Seen] = [:]
        var defaultBranch: String?
        let remotePrefix = "refs/remotes/origin/"

        for line in refs.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 5 else { continue }
            let (ref, symref) = (fields[0], fields[3])
            let name: String
            let isRemote: Bool
            if ref.hasPrefix("refs/heads/") {
                name = String(ref.dropFirst("refs/heads/".count))
                isRemote = false
            } else if ref.hasPrefix(remotePrefix) {
                name = String(ref.dropFirst(remotePrefix.count))
                isRemote = true
            } else {
                continue
            }
            if isRemote, name == "HEAD" {
                if symref.hasPrefix(remotePrefix) { defaultBranch = String(symref.dropFirst(remotePrefix.count)) }
                continue
            }
            let date = Date(timeIntervalSince1970: TimeInterval(fields[1]) ?? 0)
            var entry = seen[name] ?? Seen()
            if date > entry.date {
                entry.date = date
                entry.author = fields[2].trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            }
            if isRemote { entry.isPushed = true } else { entry.isLocal = true }
            if !isRemote, fields[4] == "[gone]" { entry.isGone = true }
            seen[name] = entry
        }

        let defaults: Set<String> = defaultBranch.map { [$0] } ?? ["main", "master"]
        let me = email?.lowercased().nilIfEmpty
        return seen.compactMap { name, entry in
            guard !defaults.contains(name), !entry.isGone else { return nil }
            if let me {
                guard entry.author.lowercased() == me else { return nil }
            } else {
                guard entry.isLocal else { return nil }
            }
            return Branch(
                owner: owner, repo: repo, name: name, directory: directory,
                updatedAt: entry.date, isPushed: entry.isPushed
            )
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Takes the last two path parts after a GitHub host, so SSH host
    /// aliases like `github.com-work` work as well as plain URLs.
    static func gitHubRepo(fromRemote remote: String) -> (owner: String, repo: String)? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let host = trimmed.range(of: "github", options: .caseInsensitive) else { return nil }
        var path = String(trimmed[host.upperBound...])
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix(".git") { path.removeLast(4) }
        let parts = path.split(whereSeparator: { $0 == "/" || $0 == ":" }).map(String.init)
        guard parts.count >= 3 else { return nil }
        return (parts[parts.count - 2], parts[parts.count - 1])
    }

    /// The Command Line Tools' git. GUI apps don't get your shell's PATH,
    /// and /usr/bin/git is there whenever Swift is.
    static func git(_ arguments: [String], in directory: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory.path] + arguments
        let output = Pipe()
        process.standardOutput = output
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
