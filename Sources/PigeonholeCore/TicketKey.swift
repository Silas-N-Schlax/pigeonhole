import Foundation

extension BoardItem {
    /// A tracker key like KATT-1234, from the front of the PR title or else
    /// the start of a branch segment. Any project's prefix counts, so it
    /// works across trackers without being told which one.
    public var ticketKey: String? {
        if case .pullRequest(let pr) = self, let key = TicketKey.leading(pr.title) {
            return key
        }
        return TicketKey.inBranch(branchName)
    }
}

enum TicketKey {
    /// Uppercase only in titles, so a word like "Fix-2" doesn't pass.
    private static let titlePattern = #/^\W*([A-Z][A-Z0-9]+-[0-9]+)(?![A-Za-z0-9.])/#

    /// Branches are usually lowercase, so case is ignored, but the key has to
    /// start a segment and end one, which keeps `release-1.1.0` out.
    private static let branchPattern = #/(?i)(?:^|\/)([a-z][a-z0-9]+-[0-9]+)(?=$|[-_\/])/#

    static func leading(_ title: String) -> String? {
        title.firstMatch(of: titlePattern).map { String($0.1) }
    }

    static func inBranch(_ name: String) -> String? {
        name.firstMatch(of: branchPattern).map { String($0.1).uppercased() }
    }
}
