import CoreGraphics
import Foundation

/// Every tunable number in one place, so nothing gets hardcoded twice.
public enum AppConfig {
    public enum Window {
        public static let boardSize = CGSize(width: 780, height: 560)
        public static let settingsSize = CGSize(width: 460, height: 640)
        public static let cornerRadius: CGFloat = 12
        /// Gap between the menu bar and the top of the board.
        public static let dropBelowMenuBar: CGFloat = 6
    }

    public enum Board {
        /// How long the footer shows "Copied …" after pressing c.
        public static let noticeSeconds = 2.0
    }

    public enum Refresh {
        public static let minuteOptions = [2, 5, 10]
        public static let defaultMinutes = 5
        /// Opening the board only refreshes when the last fetch is older
        /// than this, so flicking it open and shut costs no rate limit.
        public static let staleAfter: TimeInterval = 60
    }

    public enum Search {
        public static let pageSize = 100
        public static let mine = "is:pr is:open author:@me archived:false sort:updated-desc"
        public static let reviews = "is:pr is:open review-requested:@me archived:false sort:updated-desc"
        /// Closed and merged PRs, so a branch that already had its PR
        /// doesn't come back as one that still needs one.
        public static let closed = "is:pr is:closed author:@me archived:false sort:updated-desc"
    }

    public enum Branches {
        /// Folders under your home searched for repos on first run.
        public static let defaultFolders = ["code", "Developer", "Projects", "src", "dev"]
        /// How many folders below each chosen folder to look for repos.
        public static let searchDepth = 3
        public static let skippedFolders: Set<String> = ["node_modules", "vendor", "Pods", "build", "dist"]
    }

    public enum Defaults {
        public static let themeID = "themeID"
        public static let fontPresetID = "fontPresetID"
        public static let textSize = "textSize"
        public static let refreshMinutes = "refreshMinutes"
        public static let showActionDot = "showActionDot"
        public static let activityWindow = "activityWindow"
        public static let hotKey = "hotKey"
        public static let branchFolders = "branchFolders"
        public static let hidden = "hidden"
    }

    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pigeonhole", isDirectory: true)
    }
}
