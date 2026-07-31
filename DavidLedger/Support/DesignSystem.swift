import SwiftUI
import LedgerCore

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
}

/// The design's raw hex values, named once here. The Figma file exposes no token variables, so
/// these are lifted from the frames directly and everything else refers to them by name.
enum Palette {
    static let accent = Color(hex: 0x4F46E5)
    static let textPrimary = Color(hex: 0x111827)
    static let textSecondary = Color(hex: 0x4B5563)
    static let textTertiary = Color(hex: 0x9CA3AF)
    static let border = Color(hex: 0xE5E7EB)
    static let surface = Color(hex: 0xF9FAFB)
    static let income = Color(hex: 0x10B981)
    static let expense = Color(hex: 0xEF4444)
    static let background = Color.white
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
    static let caption = Font.system(size: 13)
    static let captionSmall = Font.system(size: 12)
    static let tabLabel = Font.system(size: 11, weight: .medium)
}

extension Category {
    var color: Color { Color(hex: colorHex) }
}
