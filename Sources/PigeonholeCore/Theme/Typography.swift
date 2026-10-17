import AppKit
import SwiftUI

public enum FontFace {
    case system(Font.Design)
    /// A family name. Resolved to a real face at draw time, falling back to
    /// the system design when the family isn't installed.
    case named(String)
}

/// A UI face plus a mono face. The same six pairs as KeyStats.
public struct FontPreset: Identifiable {
    public let id: String
    public let name: String
    public let blurb: String
    public let ui: FontFace
    public let mono: FontFace

    public static let standard = FontPreset(
        id: "default", name: "Default", blurb: "SF Pro and SF Mono",
        ui: .system(.default), mono: .system(.monospaced)
    )

    public static let all: [FontPreset] = [
        standard,
        FontPreset(
            id: "modern-dev", name: "Modern Dev", blurb: "SF Pro with JetBrains Mono, bundled",
            ui: .system(.default), mono: .named("JetBrains Mono")
        ),
        FontPreset(
            id: "classic-mac", name: "Classic Mac", blurb: "Helvetica Neue and Monaco",
            ui: .named("Helvetica Neue"), mono: .named("Monaco")
        ),
        FontPreset(
            id: "editorial", name: "Editorial", blurb: "New York serif and PT Mono",
            ui: .system(.serif), mono: .named("PT Mono")
        ),
        FontPreset(
            id: "geometric", name: "Geometric", blurb: "Futura and Andale Mono",
            ui: .named("Futura"), mono: .named("Andale Mono")
        ),
        FontPreset(
            id: "manuscript", name: "Manuscript", blurb: "Iowan Old Style and Courier New",
            ui: .named("Iowan Old Style"), mono: .named("Courier New")
        ),
    ]

    public static func named(_ id: String) -> FontPreset {
        all.first { $0.id == id } ?? .standard
    }
}

public enum TextSize: String, CaseIterable, Identifiable {
    case small, regular, large

    public var id: String { rawValue }
    public var label: String { rawValue.capitalized }

    var scale: CGFloat {
        switch self {
        case .small: 0.92
        case .regular: 1
        case .large: 1.1
        }
    }
}

/// Fonts by size and weight, with the preset and text size already applied,
/// so call sites read `type.ui(13, .semibold)` and never pick a face.
public struct Typography {
    public let preset: FontPreset
    public let size: TextSize

    public init(preset: FontPreset, size: TextSize) {
        self.preset = preset
        self.size = size
    }

    public func ui(_ points: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Self.font(preset.ui, points * size.scale, weight, fallback: .default)
    }

    public func mono(_ points: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        Self.font(preset.mono, points * size.scale, weight, fallback: .monospaced)
    }

    /// Unscaled, for showing a preset in its own face in Settings.
    public static func font(
        _ face: FontFace, _ size: CGFloat, _ weight: Font.Weight, fallback: Font.Design
    ) -> Font {
        switch face {
        case .system(let design):
            return .system(size: size, weight: weight, design: design)
        case .named(let family):
            // Font.custom wants a face name, not a family, and silently
            // draws Helvetica when it can't match one.
            guard let face = NSFontManager.shared.font(
                withFamily: family, traits: [], weight: 5, size: size
            ) else {
                return .system(size: size, weight: weight, design: fallback)
            }
            return .custom(face.fontName, fixedSize: size).weight(weight)
        }
    }
}
