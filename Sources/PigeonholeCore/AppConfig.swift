import CoreGraphics
import Foundation

/// Every tunable number in one place, so nothing gets hardcoded twice.
public enum AppConfig {
    public enum Window {
        public static let boardSize = CGSize(width: 780, height: 560)
        public static let settingsSize = CGSize(width: 460, height: 640)
        public static let cornerRadius = Radius.window
        /// The tag picker's scrolling repo list.
        public static let repoListHeight: CGFloat = 260
        /// Gap between the menu bar and the top of the board.
        public static let dropBelowMenuBar: CGFloat = 6
    }

    public enum Board {
        /// How long the footer shows "Copied …" after pressing c.
        public static let noticeSeconds = 2.0
        /// Gap between the window's edge and the slots or review rows.
        public static let padding: CGFloat = 12
        /// Inset of the cards inside their slot.
        public static let slotInset: CGFloat = 6
        public static let paletteWidth: CGFloat = 420
        public static let paletteListHeight: CGFloat = 336
        public static let paletteInset: CGFloat = 6
        public static let paletteRowHeight: CGFloat = 32
        public static let keyCapHeight: CGFloat = 18
    }

    /// Corner radii, each built from the shape inside it plus the gap
    /// between the two, so every nested pair of curves stays concentric.
    /// Change an inner one and everything around it follows.
    public enum Radius {
        public static let card: CGFloat = 10
        public static let halo = card + 3
        public static let slot = card + Board.slotInset
        public static let window = slot + Board.padding

        public static let keyCap: CGFloat = 5
        public static let paletteRow = keyCap + (Board.paletteRowHeight - Board.keyCapHeight) / 2
        public static let palette = paletteRow + Board.paletteInset

        public static let segment: CGFloat = 6
        public static let segmentTrack = segment + 2

        public static let field: CGFloat = 8
        public static let tagEditorPadding: CGFloat = 12
        public static let tagEditor = field + tagEditorPadding

        public static let themePreview: CGFloat = 6
        public static let themeCardPadding: CGFloat = 8
        public static let themeCard = themePreview + themeCardPadding

        /// Settings cards sit this far in from the window's own corners.
        public static let settingsPadding = window - card
    }

    public enum Motion {
        public static let quick = 0.14
        public static let settle = 0.28
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
        /// Pages of 100 per repo list in the tag picker, so a huge org can't
        /// stall Settings.
        public static let maxRepoPages = 10
    }

    public enum Branches {
        /// Folders under your home searched for repos on first run, listed
        /// first. Any other home folder holding a clone joins them.
        public static let defaultFolders = ["code", "Developer", "Projects", "src", "dev"]
        /// How many folders below each chosen folder to look for repos.
        public static let searchDepth = 3
        public static let skippedFolders: Set<String> = ["node_modules", "vendor", "Pods", "build", "dist"]
        /// Home folders never probed for clones on first run. Desktop,
        /// Documents and Downloads would each raise a macOS privacy prompt.
        public static let skippedHomeFolders: Set<String> = [
            "Applications", "Desktop", "Documents", "Downloads", "Library",
            "Movies", "Music", "Pictures", "Public",
        ]
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
