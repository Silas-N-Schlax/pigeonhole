import Foundation

enum BranchExclusions {
    /// Shell-style globs, case-insensitive, where `*` also crosses slashes so
    /// `backup/*` and `*-old` behave the way they read.
    static func matches(_ name: String, patterns: [String]) -> Bool {
        patterns.contains { fnmatch($0, name, FNM_CASEFOLD) == 0 }
    }
}
