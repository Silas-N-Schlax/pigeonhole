import AppKit
import SwiftUI

public struct TagColor {
    public let text: Color
    public let fill: Color
    public let dot: Color
}

/// Every color the app draws with, named by the job it does. A theme is just
/// a different set of answers; views never branch on which theme is active.
/// Source of truth for the values is the mockup (znotes/design.md §3).
public struct Theme: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isDark: Bool
    public let blurb: String

    let windowHex: UInt32
    public let window: Color
    public let line: Color
    public let slot: Color
    public let slotLine: Color
    public let card: Color
    public let cardLine: Color
    public let control: Color
    public let controlLine: Color
    public let seg: Color
    public let segOn: Color
    public let text: Color
    public let dim: Color
    public let faint: Color
    public let accent: Color
    public let accentText: Color
    public let accentSoft: Color
    public let accentSoftText: Color
    public let shadow: Color
    /// Eight slots: Red, Orange, Amber, Green, Teal, Blue, Violet, Pink.
    /// Every theme fills all eight, each checked for 4.5:1 on its own card.
    public let tags: [TagColor]

    public static func == (lhs: Theme, rhs: Theme) -> Bool { lhs.id == rhs.id }

    public var windowColor: NSColor { NSColor(hex: windowHex) }

    public func tag(_ slot: Int) -> TagColor { tags[((slot % tags.count) + tags.count) % tags.count] }

    public func chip(_ tone: StatusTone) -> (text: Color, fill: Color) {
        switch tone {
        case .draft: (dim, seg)
        case .review: (tag(5).text, tag(5).fill)
        case .comments: (tag(1).text, tag(1).fill)
        case .approved: (tag(3).text, tag(3).fill)
        case .failing: (tag(0).text, tag(0).fill)
        }
    }

    public func dot(_ slot: Slot) -> Color {
        switch slot {
        case .inProgress: faint
        case .inReview: tag(5).dot
        case .needsAction: tag(1).dot
        }
    }

    public func dot(_ checks: CheckState) -> Color {
        switch checks {
        case .passing: tag(3).dot
        case .running: tag(2).dot
        case .failing: tag(0).dot
        case .none: faint
        }
    }

    /// Edges are drawn as a translucent ring rather than a solid border, so
    /// they read the same over a card, a slot or the window behind them.
    public var ring: Color { isDark ? .white.opacity(0.08) : .black.opacity(0.07) }
    public var ringStrong: Color { isDark ? .white.opacity(0.14) : .black.opacity(0.12) }
    public var lift: Color { .black.opacity(isDark ? 0.3 : 0.05) }
    public var scrim: Color { .black.opacity(isDark ? 0.45 : 0.16) }
    public var focusHalo: Color { accent.opacity(isDark ? 0.28 : 0.2) }

    public var good: Color { tag(3).dot }
    public var danger: Color { tag(0).text }
    public var added: Color { tag(3).text }
    public var removed: Color { tag(0).text }

    public static let slotNames = ["Red", "Orange", "Amber", "Green", "Teal", "Blue", "Violet", "Pink"]

    private init(
        _ id: String, _ name: String, dark: Bool, _ blurb: String,
        window: UInt32, line: UInt32, slot: UInt32, slotLine: UInt32,
        card: UInt32, cardLine: UInt32, control: UInt32, controlLine: UInt32,
        seg: UInt32, segOn: UInt32, text: UInt32, dim: UInt32, faint: UInt32,
        accent: UInt32, accentText: UInt32, accentSoft: UInt32, accentSoftText: UInt32
    ) {
        self.id = id
        self.name = name
        self.isDark = dark
        self.blurb = blurb
        self.windowHex = window
        self.window = Color(hex: window)
        self.line = Color(hex: line)
        self.slot = Color(hex: slot)
        self.slotLine = Color(hex: slotLine)
        self.card = Color(hex: card)
        self.cardLine = Color(hex: cardLine)
        self.control = Color(hex: control)
        self.controlLine = Color(hex: controlLine)
        self.seg = Color(hex: seg)
        self.segOn = Color(hex: segOn)
        self.text = Color(hex: text)
        self.dim = Color(hex: dim)
        self.faint = Color(hex: faint)
        self.accent = Color(hex: accent)
        self.accentText = Color(hex: accentText)
        self.accentSoft = Color(hex: accentSoft)
        self.accentSoftText = Color(hex: accentSoftText)
        self.shadow = Color.black.opacity(dark ? 0.5 : 0.16)
        self.tags = dark ? Self.darkTags : Self.lightTags
    }

    // Light and dark themes each share one list for now. A theme that needs
    // its own just passes it instead.
    static let lightTags: [TagColor] = zip3(
        text: [0xA3302A, 0x9A4A12, 0x765700, 0x23663F, 0x0F6261, 0x2A4F9E, 0x5B3DA8, 0xA02A6B],
        fill: [0xFBE7E5, 0xFBEEE2, 0xF6EECD, 0xE3F1E8, 0xDCF0EF, 0xE8EEF9, 0xEEE9FA, 0xFAE6F1],
        dot: [0xD2463E, 0xD9822B, 0xC99A06, 0x3E9A64, 0x1E9A97, 0x4A74C9, 0x7D5BD0, 0xD04A92]
    )

    static let darkTags: [TagColor] = {
        let dots: [UInt32] = [0xE5645C, 0xE8954A, 0xD9B23A, 0x55B67D, 0x3DB6B2, 0x6A92E0, 0x9A7BE6, 0xE26AA8]
        let text: [UInt32] = [0xF4A5A0, 0xF2B98A, 0xE9CF7A, 0x9ED9B1, 0x8FD8D4, 0xA9C1F5, 0xC6B4F5, 0xF2A9CF]
        return zip(text, dots).map { text, dot in
            TagColor(text: Color(hex: text), fill: Color(hex: dot).opacity(0.2), dot: Color(hex: dot))
        }
    }()

    private static func zip3(text: [UInt32], fill: [UInt32], dot: [UInt32]) -> [TagColor] {
        text.indices.map {
            TagColor(text: Color(hex: text[$0]), fill: Color(hex: fill[$0]), dot: Color(hex: dot[$0]))
        }
    }

    public static let mailroom = Theme(
        "mailroom", "Mailroom", dark: false, "Paper and pencil on a tidy sorting desk.",
        window: 0xFAFAF8, line: 0xECEBE7, slot: 0xF1F0EC, slotLine: 0xE8E7E2,
        card: 0xFFFFFF, cardLine: 0xE4E3DF, control: 0xFFFFFF, controlLine: 0xE1E0DB,
        seg: 0xEDECE8, segOn: 0xFFFFFF, text: 0x1F1F1C, dim: 0x5B5A55, faint: 0x6E6C66,
        accent: 0x2F5BB7, accentText: 0xFFFFFF, accentSoft: 0xE8EEF9, accentSoftText: 0x2A4F9E
    )

    public static let carbonCopy = Theme(
        "carbon", "Carbon Copy", dark: false, "Cool white page, violet carbon ink.",
        window: 0xF7F9FB, line: 0xE5E9EE, slot: 0xEEF1F5, slotLine: 0xE1E6EC,
        card: 0xFFFFFF, cardLine: 0xDBE1E8, control: 0xFFFFFF, controlLine: 0xD5DCE4,
        seg: 0xE6EAEF, segOn: 0xFFFFFF, text: 0x17202B, dim: 0x4C5866, faint: 0x5F6B79,
        accent: 0x4B3FB5, accentText: 0xFFFFFF, accentSoft: 0xECEAFB, accentSoftText: 0x3F33A0
    )

    public static let nightPost = Theme(
        "nightpost", "Night Post", dark: true, "The late shift. Plain charcoal, one blue lamp.",
        window: 0x18181B, line: 0x2A2A2F, slot: 0x1E1E22, slotLine: 0x2A2A30,
        card: 0x26262B, cardLine: 0x34343B, control: 0x26262B, controlLine: 0x38383F,
        seg: 0x222226, segOn: 0x3A3A42, text: 0xECECEF, dim: 0xB4B4BC, faint: 0x9A9AA4,
        accent: 0x7FA7F5, accentText: 0x0F1420, accentSoft: 0x23304B, accentSoftText: 0xB9CDF8
    )

    public static let ledger = Theme(
        "ledger", "Ledger", dark: true, "Banker green with a brass rule.",
        window: 0x102019, line: 0x1F3529, slot: 0x14271E, slotLine: 0x213A2D,
        card: 0x1A3126, cardLine: 0x2A4535, control: 0x1A3126, controlLine: 0x2E4A3A,
        seg: 0x152A20, segOn: 0x2D4A3A, text: 0xE8F0EA, dim: 0xB1C6B8, faint: 0x97AE9F,
        accent: 0xD9B45A, accentText: 0x1A1405, accentSoft: 0x3A3420, accentSoftText: 0xEBD394
    )

    public static let walnut = Theme(
        "walnut", "Walnut", dark: true, "The cabinet itself. Warm wood, amber light.",
        window: 0x1E1612, line: 0x33261F, slot: 0x261C17, slotLine: 0x3A2B23,
        card: 0x2E221C, cardLine: 0x443329, control: 0x2E221C, controlLine: 0x4A382D,
        seg: 0x291E19, segOn: 0x4A382D, text: 0xF3E9E1, dim: 0xC9B6A7, faint: 0xAE9886,
        accent: 0xE39B4E, accentText: 0x1E1206, accentSoft: 0x43301F, accentSoftText: 0xF4C796
    )

    public static let inkwell = Theme(
        "inkwell", "Inkwell", dark: true, "Deep navy ink and a cyan nib.",
        window: 0x0F1428, line: 0x1E2643, slot: 0x131A33, slotLine: 0x222B4C,
        card: 0x19213E, cardLine: 0x2A3458, control: 0x19213E, controlLine: 0x2E3960,
        seg: 0x151C36, segOn: 0x2E3960, text: 0xE6EAF8, dim: 0xAFB8DA, faint: 0x949EC5,
        accent: 0x6CD3E6, accentText: 0x061418, accentSoft: 0x183447, accentSoftText: 0xA5E6F1
    )

    public static let all = [mailroom, carbonCopy, nightPost, ledger, walnut, inkwell]

    public static func named(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .mailroom
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
