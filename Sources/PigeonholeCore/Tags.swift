import Foundation

/// A user-made label for a set of repos. Stores a palette slot rather than a
/// color, so each theme draws it from its own contrast-checked list.
public struct Tag: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var colorSlot: Int
    public var repos: [String]

    public init(id: UUID = UUID(), name: String, colorSlot: Int, repos: [String] = []) {
        self.id = id
        self.name = name
        self.colorSlot = colorSlot
        self.repos = repos
    }

    public func holds(_ fullRepo: String) -> Bool { repos.contains(fullRepo) }
}

/// The tags, in a JSON file of their own.
///
/// Losing tags is a nuisance, not a disaster, so a failed read or write is
/// quiet: the app carries on with whatever it has.
public struct TagStore {
    private let directory: URL
    private let url: URL

    public init(directory: URL) {
        self.directory = directory
        self.url = directory.appendingPathComponent("tags.json")
    }

    public func load() -> [Tag] {
        guard let data = try? Data(contentsOf: url),
              let tags = try? JSONDecoder().decode([Tag].self, from: data) else { return [] }
        return tags
    }

    public func save(_ tags: [Tag]) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(tags) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

public enum OwnerFilter: Hashable {
    case all, personal
    case owner(String)
}

public enum TagFilter: Hashable {
    case any, untagged
    case tag(UUID)
}

/// The board's two filters. Both apply at once, so "northwind · Client" is
/// one owner filter plus one tag filter.
public struct BoardFilter: Equatable {
    public var owner: OwnerFilter = .all
    public var tag: TagFilter = .any

    public init(owner: OwnerFilter = .all, tag: TagFilter = .any) {
        self.owner = owner
        self.tag = tag
    }

    public func matches(_ pr: PullRequest, viewer: String, tags: [Tag]) -> Bool {
        Self.matches(pr, owner: owner, viewer: viewer) && Self.matches(pr, tag: tag, tags: tags)
    }

    static func matches(_ pr: PullRequest, owner: OwnerFilter, viewer: String) -> Bool {
        switch owner {
        case .all: true
        case .personal: pr.owner.caseInsensitiveCompare(viewer) == .orderedSame
        case .owner(let name): pr.owner == name
        }
    }

    static func matches(_ pr: PullRequest, tag: TagFilter, tags: [Tag]) -> Bool {
        switch tag {
        case .any: true
        case .untagged: !tags.contains { $0.holds(pr.fullRepo) }
        case .tag(let id): tags.first { $0.id == id }?.holds(pr.fullRepo) ?? false
        }
    }
}
