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
    }

    public enum Defaults {
        public static let themeID = "themeID"
        public static let fontPresetID = "fontPresetID"
        public static let textSize = "textSize"
        public static let refreshMinutes = "refreshMinutes"
        public static let showActionDot = "showActionDot"
        public static let activityWindow = "activityWindow"
        public static let hotKey = "hotKey"
    }

    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Pigeonhole", isDirectory: true)
    }
}
