import SwiftUI

/// The `?` palette: every board shortcut, filtered as you type, and each
/// one runnable from here. Keys arrive through the app delegate's monitor,
/// not a text field, so the filter shows as plain text with a caret.
struct ShortcutPaletteView: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    /// The keycaps in the palette's top and bottom corners sit this far in,
    /// so their corners and the palette's stay concentric.
    private let cornerGap = AppConfig.Radius.palette - AppConfig.Radius.keyCap

    var body: some View {
        let palette = state.palette ?? ShortcutPalette()
        let matches = palette.matches
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.faint)
                HStack(spacing: 1) {
                    if !palette.query.isEmpty {
                        Text(palette.query).foregroundStyle(theme.text)
                    }
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.accent)
                        .frame(width: 1.5, height: 15)
                    if palette.query.isEmpty {
                        Text("Search shortcuts").foregroundStyle(theme.faint)
                            .padding(.leading, 2)
                    }
                }
                .font(type.ui(13.5))
                Spacer(minLength: 8)
                KeyCap("esc")
            }
            .padding(.horizontal, cornerGap)
            .frame(height: AppConfig.Board.keyCapHeight + cornerGap * 2)
            theme.line.frame(height: 1)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(ShortcutGroup.allCases, id: \.self) { group in
                            let rows = matches.filter { $0.group == group }
                            if !rows.isEmpty {
                                Text(group.rawValue)
                                    .font(type.ui(11, .semibold))
                                    .foregroundStyle(theme.faint)
                                    .padding(.horizontal, 8)
                                    .padding(.top, 8)
                                    .padding(.bottom, 3)
                                ForEach(rows) { shortcut in
                                    PaletteRow(shortcut: shortcut, lit: shortcut == palette.highlighted)
                                        .id(shortcut.id)
                                }
                            }
                        }
                        if matches.isEmpty {
                            Text("No shortcut matches \u{201C}\(palette.query)\u{201D}")
                                .font(type.ui(12.5))
                                .foregroundStyle(theme.faint)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                        }
                    }
                    .padding(AppConfig.Board.paletteInset)
                }
                .scrollIndicators(.never)
                .frame(height: AppConfig.Board.paletteListHeight)
                .onChange(of: palette.highlighted?.id) { _, id in
                    if let id { proxy.scrollTo(id) }
                }
            }
            theme.line.frame(height: 1)
            HStack(spacing: 14) {
                hint(["↑", "↓"], "choose")
                hint(["↩"], "run")
                Spacer(minLength: 0)
                hint(["H", "J", "K", "L"], "move cards")
            }
            .padding(.horizontal, cornerGap)
            .frame(height: AppConfig.Board.keyCapHeight + cornerGap * 2)
        }
        .frame(width: AppConfig.Board.paletteWidth)
        .background(
            RoundedRectangle(cornerRadius: AppConfig.Radius.palette, style: .continuous)
                .fill(theme.window)
                .shadow(color: .black.opacity(theme.isDark ? 0.5 : 0.16), radius: 24, y: 12)
                .shadow(color: theme.lift, radius: 2, y: 1)
        )
        .overlay(RoundedRectangle(cornerRadius: AppConfig.Radius.palette, style: .continuous).strokeBorder(theme.ringStrong))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keyboard shortcuts")
    }

    private func hint(_ keys: [String], _ label: String) -> some View {
        HStack(spacing: 4) {
            ForEach(keys, id: \.self) { KeyCap($0) }
            Text(label)
                .font(type.ui(11))
                .foregroundStyle(theme.faint)
                .lineLimit(1)
                .fixedSize()
                .padding(.leading, 2)
        }
    }
}

private struct PaletteRow: View {
    @Environment(AppState.self) private var state
    @Environment(\.theme) private var theme
    @Environment(\.typography) private var type
    let shortcut: Shortcut
    let lit: Bool

    var body: some View {
        let idle = shortcut.command.needsCard && state.selectedItem == nil
        Button {
            state.run(shortcut)
        } label: {
            HStack(spacing: 10) {
                Text(shortcut.title)
                    .font(type.ui(13, lit ? .medium : .regular))
                    .foregroundStyle(idle ? theme.faint : (lit ? theme.accentSoftText : theme.text))
                if idle {
                    Text("Pick a card first")
                        .font(type.ui(11))
                        .foregroundStyle(theme.faint)
                }
                Spacer(minLength: 8)
                HStack(spacing: 3) {
                    ForEach(shortcut.keys, id: \.self) { KeyCap($0) }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, (AppConfig.Board.paletteRowHeight - AppConfig.Board.keyCapHeight) / 2)
            .frame(height: AppConfig.Board.paletteRowHeight)
            .background(
                RoundedRectangle(cornerRadius: AppConfig.Radius.paletteRow, style: .continuous)
                    .fill(lit ? theme.accentSoft : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.99))
        .onHover { if $0 { state.highlight(shortcut) } }
        .accessibilityAddTraits(lit ? .isSelected : [])
    }
}
