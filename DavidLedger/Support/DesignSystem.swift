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

/// The design's raw hex values, named once here. The Figma file exposes no token variables, so the
/// light values are lifted from the frames directly and everything else refers to them by name.
///
/// The design has no dark frames, so the dark values are derived: the greys are inverted about the
/// same steps, and the two semantic colours are lightened enough to hold contrast on a dark surface.
enum Palette {
    /// The one colour the user picks. Computed rather than stored so that reading it inside a
    /// view's body registers with Observation and the screen redraws when the choice changes.
    static var accent: Color {
        Color(hex: UInt32(truncatingIfNeeded: AppSettings.shared.accentColorValue))
    }

    /// The accents offered in 설정 → 화면, saturated enough to stay legible on both surfaces.
    static let accentOptions: [UInt32] = [
        0x4F46E5, 0x2563EB, 0x0891B2, 0x0D9488, 0x059669,
        0xD97706, 0xEA580C, 0xDC2626, 0xDB2777, 0x7C3AED,
    ]

    static let textPrimary = Color(light: 0x111827, dark: 0xF3F4F6)
    static let textSecondary = Color(light: 0x4B5563, dark: 0xB4BAC4)
    static let textTertiary = Color(light: 0x9CA3AF, dark: 0x868D99)
    static let border = Color(light: 0xE5E7EB, dark: 0x2A2F38)
    static let surface = Color(light: 0xF9FAFB, dark: 0x1A1D23)
    static let income = Color(light: 0x10B981, dark: 0x34D399)
    static let expense = Color(light: 0xEF4444, dark: 0xF87171)
    static let background = Color(light: 0xFFFFFF, dark: 0x0F1115)
}

enum Metrics {
    /// Every screen body is inset by this much; the design uses it on all six frames.
    static let screenPadding: CGFloat = 24
    static let cardRadius: CGFloat = 16
    static let cardPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let rowSpacing: CGFloat = 12
}

extension Font {
    // The design specifies Pretendard, which is not bundled here, so these map onto the system
    // face at the same sizes and weights. Dropping in Pretendard later means changing only this.
    static let screenTitle = Font.system(size: 18, weight: .bold)
    static let cardAmount = Font.system(size: 32, weight: .bold)
    static let sectionTitle = Font.system(size: 16, weight: .bold)
    static let rowTitle = Font.system(size: 14, weight: .semibold)
    static let rowAmount = Font.system(size: 14, weight: .semibold)
    static let bodyValue = Font.system(size: 16, weight: .semibold)
    // Not named `caption`: that would shadow SwiftUI's own `Font.caption`, and every `.font(.caption)`
    // in the app would silently become a fixed 13pt.
    static let captionRegular = Font.system(size: 13)
    static let captionSmall = Font.system(size: 12)
    static let tabLabel = Font.system(size: 11, weight: .medium)
}
