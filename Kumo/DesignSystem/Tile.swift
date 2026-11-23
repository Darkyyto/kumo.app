import SwiftUI

/// The look of the Kumo website: a pale page, white and black tiles with big corners, bold titles with a grey second line, quiet grey rows, black and white pills.
enum Site {
    static let page = Palette.canvas
    static let row = Color(light: 0xF5F5F5, dark: 0x252528)
    static let dim = Color(light: 0xB9B9B4, dark: 0x6A6A70)
    static let darkTile = Color(light: 0x121214, dark: 0x050506)
    static let onDark = Color.white
    static let onDarkDim = Color(hex: 0x8E8E93)
}

struct Tile<Content: View>: View {
    var dark = false
    var padding: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        content
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(dark ? Site.darkTile : Palette.surface, in: shape)
            .overlay { shape.strokeBorder(dark ? Color.white.opacity(0.08) : Palette.hairline, lineWidth: 1) }
            .clipShape(shape)
    }
}

struct TileTitle: View {
    let title: String
    var subtitle: String?
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 24, weight: .semibold))
                .tracking(-0.6)
                .foregroundStyle(dark ? Site.onDark : Palette.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundStyle(dark ? Site.onDarkDim : Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SitePill: View {
    enum Style {
        case ink
        case white
        case soft
    }

    let title: String
    var style: Style = .ink
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .tracking(-0.1)
                .foregroundStyle(foreground)
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(background, in: .capsule)
                .overlay { if style == .soft { Capsule().strokeBorder(Palette.hairline, lineWidth: 1) } }
                .contentShape(.capsule)
        }
        .buttonStyle(PressableStyle(scale: 0.96))
        .brightness(isHovering ? (style == .white ? -0.03 : 0.04) : 0)
        .onHover { isHovering = $0 }
        .animation(Motion.quick, value: isHovering)
    }

    private var foreground: Color {
        switch style {
        case .ink: Palette.canvas
        case .white: Color(hex: 0x111111)
        case .soft: Palette.ink
        }
    }

    private var background: Color {
        switch style {
        case .ink: Palette.ink
        case .white: .white
        case .soft: Palette.surface
        }
    }
}

/// A grey row with a colour dot, a title, a line under it and a value on the right. The only place colour shows up.
struct SiteRow: View {
    let tint: Color
    let title: String
    let detail: String
    var value: String?
    var progress: Double?
    var done = false
    var action: (() -> Void)?
    @State private var isHovering = false

    var body: some View {
        let row = VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 11) {
                Circle().fill(tint).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(done ? Palette.inkTertiary : Palette.ink)
                        .strikethrough(done)
                        .lineLimit(1)
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.inkSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(.system(size: 13.5, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                }
            }
            if let progress {
                Capsule()
                    .fill(Palette.ink.opacity(0.08))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule().fill(tint).frame(width: max(4, proxy.size.width * min(1, progress)))
                        }
                    }
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(Site.row, in: .rect(cornerRadius: 18, style: .continuous))
        .contentShape(.rect(cornerRadius: 18, style: .continuous))

        if let action {
            Button(action: action) { row }
                .buttonStyle(PressableStyle(scale: 0.988))
                .brightness(isHovering ? -0.015 : 0)
                .onHover { isHovering = $0 }
                .animation(Motion.quick, value: isHovering)
        } else {
            row
        }
    }
}


/// The page title: bold, with the second line in grey, like the website's headlines.
struct PageHeader<Trailing: View>: View {
    let title: String
    var dim: String?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 40, weight: .semibold))
                    .tracking(-1.3)
                    .foregroundStyle(Palette.ink)
                if let dim {
                    Text(dim)
                        .font(.system(size: 40, weight: .semibold))
                        .tracking(-1.3)
                        .foregroundStyle(Site.dim)
                }
            }
            Spacer(minLength: 0)
            trailing
                .padding(.top, 8)
        }
    }
}

extension PageHeader where Trailing == EmptyView {
    init(title: String, dim: String? = nil) {
        self.init(title: title, dim: dim) { EmptyView() }
    }
}
