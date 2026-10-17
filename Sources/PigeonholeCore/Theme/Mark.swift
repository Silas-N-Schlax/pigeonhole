import AppKit
import SwiftUI

/// The pigeonhole cabinet: a 3×2 grid of cubbies with two parcels in it.
/// Drawn on an 18×16 grid, the same one the mockup's SVG uses.
enum MarkGeometry {
    static let size = CGSize(width: 18, height: 16)
    static let frame = CGRect(x: 1, y: 1, width: 16, height: 14)
    static let frameRadius: CGFloat = 2.5
    static let dividers: [(CGPoint, CGPoint)] = [
        (CGPoint(x: 6.33, y: 1), CGPoint(x: 6.33, y: 15)),
        (CGPoint(x: 11.67, y: 1), CGPoint(x: 11.67, y: 15)),
        (CGPoint(x: 1, y: 8), CGPoint(x: 17, y: 8)),
    ]
    static let parcels = [
        CGRect(x: 2.6, y: 9.6, width: 2.2, height: 3.8),
        CGRect(x: 7.9, y: 3.4, width: 2.2, height: 3.2),
    ]
    static let parcelRadius: CGFloat = 0.6
}

public struct PigeonholeMark: View {
    let color: Color

    public init(color: Color) {
        self.color = color
    }

    public var body: some View {
        Canvas { context, size in
            let scale = min(size.width / MarkGeometry.size.width, size.height / MarkGeometry.size.height)
            context.translateBy(
                x: (size.width - MarkGeometry.size.width * scale) / 2,
                y: (size.height - MarkGeometry.size.height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            context.stroke(
                Path(roundedRect: MarkGeometry.frame, cornerRadius: MarkGeometry.frameRadius),
                with: .color(color), lineWidth: 1.5
            )
            var dividers = Path()
            for (from, to) in MarkGeometry.dividers {
                dividers.move(to: from)
                dividers.addLine(to: to)
            }
            context.stroke(dividers, with: .color(color), lineWidth: 1.5)
            for parcel in MarkGeometry.parcels {
                context.fill(
                    Path(roundedRect: parcel, cornerRadius: MarkGeometry.parcelRadius),
                    with: .color(color)
                )
            }
        }
        .accessibilityHidden(true)
    }
}

public enum MarkImage {
    /// The menu bar glyph. A template image, so macOS tints it for light and
    /// dark menu bars and the selected state; only its alpha matters. The
    /// dot is cut into the frame's corner so it still reads as a dot in one
    /// color.
    public static func menuBar(dot: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 19, height: 16), flipped: true) { _ in
            NSColor.black.set()
            drawGlyph(lineWidth: 1.5)
            if dot {
                NSGraphicsContext.current?.compositingOperation = .clear
                NSBezierPath(ovalIn: NSRect(x: 12.6, y: -0.6, width: 6.4, height: 6.4)).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                NSBezierPath(ovalIn: NSRect(x: 13.6, y: 0.4, width: 4.4, height: 4.4)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = dot ? "Pigeonhole, something needs action" : "Pigeonhole"
        return image
    }

    /// The colored mark for the About panel. There's no Dock icon to need a
    /// full icon set.
    public static func appIcon() -> NSImage {
        NSImage(size: NSSize(width: 256, height: 256), flipped: true) { rect in
            NSColor(hex: 0xF1F0EC).setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 16, dy: 16), xRadius: 52, yRadius: 52).fill()
            let transform = NSAffineTransform()
            transform.translateX(by: 44, yBy: 52)
            transform.scale(by: 9.4)
            transform.concat()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: MarkGeometry.frame, xRadius: 2.5, yRadius: 2.5).fill()
            NSColor(hex: 0x2F5BB7).set()
            drawGlyph(lineWidth: 1.1, parcels: false)
            let parcels: [(CGRect, UInt32)] = [
                (MarkGeometry.parcels[0], 0x2F5BB7),
                (MarkGeometry.parcels[1], 0x9DB3E0),
                (CGRect(x: 13.2, y: 10.4, width: 2.2, height: 3), 0xD9822B),
            ]
            for (parcel, color) in parcels {
                NSColor(hex: color).setFill()
                NSBezierPath(roundedRect: parcel, xRadius: 0.5, yRadius: 0.5).fill()
            }
            return true
        }
    }

    private static func drawGlyph(lineWidth: CGFloat, parcels: Bool = true) {
        let frame = NSBezierPath(
            roundedRect: MarkGeometry.frame,
            xRadius: MarkGeometry.frameRadius, yRadius: MarkGeometry.frameRadius
        )
        frame.lineWidth = lineWidth
        frame.stroke()
        let dividers = NSBezierPath()
        for (from, to) in MarkGeometry.dividers {
            dividers.move(to: from)
            dividers.line(to: to)
        }
        dividers.lineWidth = lineWidth
        dividers.stroke()
        guard parcels else { return }
        for parcel in MarkGeometry.parcels {
            NSBezierPath(
                roundedRect: parcel,
                xRadius: MarkGeometry.parcelRadius, yRadius: MarkGeometry.parcelRadius
            ).fill()
        }
    }
}
