import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.mailroom
}

private struct TypographyKey: EnvironmentKey {
    static let defaultValue = Typography(preset: .standard, size: .regular)
}

public extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }

    var typography: Typography {
        get { self[TypographyKey.self] }
        set { self[TypographyKey.self] = newValue }
    }
}

/// Hands the current theme and fonts to everything below it. Each window's
/// root view sits inside one.
public struct ThemedRoot<Content: View>: View {
    @Environment(AppState.self) private var state
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .environment(\.theme, state.theme)
            .environment(\.typography, state.typography)
            .tint(state.theme.accent)
    }
}

struct SegmentItem<ID: Hashable> {
    let id: ID
    let label: String
    var badge: Int?
}

struct SegmentedControl<ID: Hashable>: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var thumb
    let items: [SegmentItem<ID>]
    @Binding var selection: ID
    /// Binds ⌘1, ⌘2… to the segments in order.
    var numberShortcuts = false

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let on = item.id == selection
                Button {
                    selection = item.id
                } label: {
                    HStack(spacing: 6) {
                        Text(item.label)
                            .font(type.ui(12.5, .medium))
                        if let badge = item.badge {
                            Text("\(badge)")
                                .font(type.ui(10.5, .semibold))
                                .monospacedDigit()
                                .foregroundStyle(theme.accentText)
                                .padding(.horizontal, 4)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Capsule().fill(theme.accent))
                        }
                    }
                    .foregroundStyle(on ? theme.text : theme.dim)
                    .padding(.horizontal, 11)
                    .frame(height: 24)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: AppConfig.Radius.segment, style: .continuous)
                                .fill(theme.segOn)
                                .shadow(color: theme.lift, radius: 1, y: 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppConfig.Radius.segment, style: .continuous)
                                        .strokeBorder(theme.ring)
                                )
                                .matchedGeometryEffect(id: "thumb", in: thumb)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressable)
                .modifier(NumberShortcut(number: numberShortcuts && index < 9 ? index + 1 : nil))
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: AppConfig.Radius.segmentTrack, style: .continuous).fill(theme.seg))
        .animation(reduceMotion ? nil : .smooth(duration: AppConfig.Motion.settle), value: selection)
    }
}

private struct NumberShortcut: ViewModifier {
    let number: Int?

    func body(content: Content) -> some View {
        if let number {
            content.keyboardShortcut(KeyEquivalent(Character("\(number)")), modifiers: .command)
        } else {
            content
        }
    }
}

/// A tag as its color dot and name. The status chip beside it is the only
/// filled chip on a card, so the eye lands on what needs doing first.
struct TagChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let name: String
    let slot: Int

    var body: some View {
        HStack(spacing: 5) {
            Dot(color: theme.tag(slot).dot, size: 6)
            Text(name.isEmpty ? "Untitled" : name)
                .font(type.ui(11, .medium))
                .foregroundStyle(theme.dim)
                .lineLimit(1)
        }
        .padding(.leading, 7)
        .padding(.trailing, 8)
        .frame(height: 20)
        .overlay(Capsule().strokeBorder(theme.ring))
    }
}

struct StatusChip: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let status: Status

    var body: some View {
        let colors = theme.chip(status.tone)
        Text(status.label)
            .font(type.ui(11, .medium))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(colors.text)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(Capsule().fill(colors.fill))
    }
}

struct Dot: View {
    let color: Color
    var size: CGFloat = 7

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

struct SectionLabel: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(type.ui(12, .semibold))
            .foregroundStyle(theme.dim)
    }
}

struct KeyCap: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    private let label: String

    init(_ label: String) {
        self.label = label
    }

    var body: some View {
        Text(label)
            .font(type.ui(10.5, .medium))
            .monospacedDigit()
            .foregroundStyle(theme.dim)
            .padding(.horizontal, 5)
            .frame(minWidth: AppConfig.Board.keyCapHeight, minHeight: AppConfig.Board.keyCapHeight)
            .background(
                RoundedRectangle(cornerRadius: AppConfig.Radius.keyCap, style: .continuous)
                    .fill(theme.control)
                    .shadow(color: theme.lift, radius: 0, y: 1)
            )
            .overlay(RoundedRectangle(cornerRadius: AppConfig.Radius.keyCap, style: .continuous).strokeBorder(theme.ring))
    }
}

/// A count beside a heading, in a quiet pill.
struct CountBadge: View {
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(type.ui(11, .medium))
            .monospacedDigit()
            .foregroundStyle(theme.faint)
            .contentTransition(.numericText())
            .padding(.horizontal, 6)
            .frame(minWidth: 20, minHeight: 18)
            .background(Capsule().fill(theme.seg))
    }
}

/// A borderless icon button that shows its edge only on hover. Round,
/// because both sit in a corner of the window, where the concentric radius
/// would be more than half their size anyway.
struct IconButton<Label: View>: View {
    @Environment(\.theme) private var theme
    @State private var hovering = false
    let help: String
    let action: () -> Void
    @ViewBuilder let label: Label

    var body: some View {
        Button(action: action) {
            label
                .foregroundStyle(hovering ? theme.text : theme.dim)
                .frame(width: 28, height: 28)
                .background(Circle().fill(hovering ? theme.control : .clear))
                .overlay(Circle().strokeBorder(hovering ? theme.ring : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: AppConfig.Motion.quick), value: hovering)
        .help(help)
        .accessibilityLabel(help)
    }
}

struct CardBackground: ViewModifier {
    @Environment(\.theme) private var theme
    var radius: CGFloat = AppConfig.Radius.card
    var highlighted = false
    var fill: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let halo = AppConfig.Radius.halo - AppConfig.Radius.card
        content
            .background(
                shape.fill(fill ?? theme.card)
                    .shadow(color: theme.lift, radius: 1, y: 1)
                    .shadow(color: theme.lift, radius: 4, y: 2)
            )
            .overlay(shape.strokeBorder(highlighted ? theme.accent : theme.ring, lineWidth: highlighted ? 1.25 : 1))
            .background(
                RoundedRectangle(cornerRadius: radius + halo, style: .continuous)
                    .fill(highlighted ? theme.focusHalo : .clear)
                    .padding(-halo)
            )
            .animation(.easeOut(duration: AppConfig.Motion.quick), value: highlighted)
    }
}

extension View {
    func card(radius: CGFloat = AppConfig.Radius.card, highlighted: Bool = false, fill: Color? = nil) -> some View {
        modifier(CardBackground(radius: radius, highlighted: highlighted, fill: fill))
    }
}

/// Buttons give a little under the pointer, so a click feels taken.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var scale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .animation(.easeOut(duration: AppConfig.Motion.quick), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
    static func pressable(scale: CGFloat) -> PressableStyle { PressableStyle(scale: scale) }
}

private struct Blur: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content.blur(radius: radius)
    }
}

extension AnyTransition {
    /// Rises in from a soft blur, and leaves more quietly than it came:
    /// a fade and a lighter blur, no movement.
    static func lift(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .opacity
                .combined(with: .scale(scale: 0.97))
                .combined(with: .offset(y: 6))
                .combined(with: .modifier(active: Blur(radius: 6), identity: Blur(radius: 0))),
            removal: .opacity
                .combined(with: .modifier(active: Blur(radius: 2), identity: Blur(radius: 0)))
        )
    }

    /// For one icon or line of text giving way to another in place.
    static func blurSwap(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .opacity
            .combined(with: .scale(scale: 0.9))
            .combined(with: .modifier(active: Blur(radius: 3), identity: Blur(radius: 0)))
    }
}

/// Lays children out in rows, wrapping when a row runs out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            widest = max(widest, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
