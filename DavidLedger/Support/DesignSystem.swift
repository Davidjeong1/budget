import SwiftUI
import UIKit

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// A colour that resolves against the current trait collection, so one name serves both
    /// appearances and no view has to read the colour scheme to pick a shade.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Appearance {
    /// nil hands the choice back to iOS, which is what `system` means.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The design's raw hex values, named once here. The Figma file exposes no token variables, so
/// these are lifted from the light and dark frames directly and everything else refers to them by
/// name — which is why re-skinning the app to the new design is mostly this one type.
enum Palette {
    /// The one colour the user picks. Computed rather than stored so that reading it inside a
    /// view's body registers with Observation and the screen redraws when the choice changes.
    ///
    /// The redesign draws the same mint (#34D399) on both surfaces, so unlike the gold it replaces
    /// there is no light/dark pair here to collapse into one value.
    static var accent: Color {
        Color(hex: UInt32(truncatingIfNeeded: AppSettings.shared.accentColorValue))
    }

    /// The accents offered in 설정 → 화면. The design's mint leads; the rest hold up against both
    /// surfaces at the same weight.
    ///
    /// The gold this replaced is gone from the grid. Anyone who had picked it keeps it — the stored
    /// value is untouched and still paints the app — but no swatch will read as selected until they
    /// choose again.
    static let accentOptions: [UInt32] = [
        0x34D399, 0xB4863A, 0x8C7A4B, 0x4F46E5, 0x2563EB,
        0x0D9488, 0x059669, 0xEA580C, 0xDC2626, 0x7C3AED,
    ]

    static let textPrimary = Color(light: 0x1A1A1A, dark: 0xF5F5F5)
    static let textSecondary = Color(light: 0x666666, dark: 0x888888)
    static let textTertiary = Color(light: 0x999999, dark: 0x888888)
    static let border = Color(light: 0xEEEEEE, dark: 0x2A2A2A)
    static let background = Color(light: 0xFFFFFF, dark: 0x121212)

    /// Cards and rows sitting on the background.
    static let surface = Color(light: 0xF8F9FA, dark: 0x1E1E1E)
    /// Blocks sitting on a card — the 수입/지출 pair inside the summary. On light these go back to
    /// white, so the nesting reads as raised rather than as another shade of grey.
    static let surfaceRaised = Color(light: 0xFFFFFF, dark: 0x262626)
    /// The unfilled part of a progress bar or chart bar. Distinct from `border`, which is a hairline.
    static let track = Color(light: 0xE2E8F0, dark: 0x2A2A2A)
    /// The tab bar, which stays white on light while the cards around it do not.
    static let barBackground = Color(light: 0xFFFFFF, dark: 0x1E1E1E)

    /// Ranked shades of the accent, for charts. The redesign colours a breakdown by rank rather
    /// than by category — one hue stepped lighter and darker — so a donut and its legend stay
    /// readable however many slices there are.
    static func accentShade(_ rank: Int) -> Color {
        // Ratios, not fixed hues: they reproduced the old design's three gold steps (#C59B27,
        // #E0B354, #9E7B26) and step the mint the same way.
        let steps: [Double] = [0, 0.28, -0.2, 0.52, -0.38, 0.14]
        return Color(
            hex: blend(
                UInt32(truncatingIfNeeded: AppSettings.shared.accentColorValue),
                towards: steps[rank % steps.count]
            )
        )
    }

    /// Positive mixes towards white, negative towards black.
    private static func blend(_ hex: UInt32, towards amount: Double) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            let value = Double((hex >> shift) & 0xFF)
            let mixed = amount >= 0 ? value + (255 - value) * amount : value * (1 + amount)
            return UInt32(min(max(mixed.rounded(), 0), 255))
        }
        return channel(16) << 16 | channel(8) << 8 | channel(0)
    }

    static let income = Color(light: 0x4CAF50, dark: 0x4CAF50)
    /// Only the over-budget warnings are red now. Spending itself is not: an expense row prints
    /// in `textPrimary` and the month's total in the accent.
    static let expense = Color(light: 0xEF5350, dark: 0xEF5350)
}

/// What the colour swatches are called out loud, for 설정 → 강조 색 and the category editor's 색상.
///
/// A circle filled with a colour has no text in it, so VoiceOver reads whatever the button's label
/// says — and a hex triplet describes the value rather than the colour. "#34D399" tells a user who
/// cannot see the swatch nothing about what they are about to pick.
///
/// The two palettes share this table. Their names overlap by design: 파랑 appears in both, but the
/// grids never appear on the same screen, and inventing 파랑2 to keep the keys distinct would make
/// the reading worse to solve a problem nobody has. An unlisted value falls back to the hex, so
/// adding a swatch degrades the label rather than losing it.
enum ColorNames {
    static func of(_ hex: UInt32) -> String {
        names[hex] ?? String(format: "#%06X", hex)
    }

    private static let names: [UInt32: String] = [
        // Palette.accentOptions
        0x34D399: "민트", 0xB4863A: "브론즈", 0x8C7A4B: "카키", 0x2563EB: "파랑",
        0x0D9488: "청록", 0x059669: "초록", 0xEA580C: "주황", 0xDC2626: "빨강",
        0x7C3AED: "보라",
        // CategoryStyle.colors
        0x4F46E5: "남보라", 0x3B82F6: "파랑", 0x0EA5E9: "하늘", 0x14B8A6: "청록",
        0x10B981: "초록", 0x84CC16: "연두", 0xF59E0B: "노랑", 0xF97316: "주황",
        0xEF4444: "빨강", 0xEC4899: "분홍", 0xA855F7: "보라", 0x6B7280: "회색",
    ]
}

enum Metrics {
    /// Every screen body is inset by this much; the design uses it on all six frames.
    static let screenPadding: CGFloat = 20
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    /// Sections carry 12pt of their own padding top and bottom, so this is the gap between them.
    static let sectionSpacing: CGFloat = 24
    static let rowSpacing: CGFloat = 12
    /// Rows and the blocks inside a card, which are rounded less than the cards themselves.
    static let rowRadius: CGFloat = 12
}

extension Font {
    // The design specifies Pretendard, which is not bundled here, so these map onto the system
    // face at the same sizes and weights. Dropping in Pretendard later means changing only this.
    /// The wordmark on the home screen.
    static let appTitle = Font.system(size: 24, weight: .black)
    static let screenTitle = Font.system(size: 18, weight: .bold)
    static let cardAmount = Font.system(size: 32, weight: .heavy)
    static let sectionTitle = Font.system(size: 15, weight: .bold)
    static let rowTitle = Font.system(size: 14, weight: .semibold)
    static let rowAmount = Font.system(size: 14, weight: .bold)
    static let bodyValue = Font.system(size: 16, weight: .semibold)
    // Not named `caption`: that would shadow SwiftUI's own `Font.caption`, and every `.font(.caption)`
    // in the app would silently become a fixed 13pt.
    static let captionRegular = Font.system(size: 13)
    static let captionSmall = Font.system(size: 12)
    static let tabLabel = Font.system(size: 11, weight: .medium)
}
