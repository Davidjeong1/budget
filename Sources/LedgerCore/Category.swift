import Foundation

/// The ledger categories, matching the six expense chips on the add-transaction screen plus an
/// income category and a catch-all.
public enum Category: String, CaseIterable, Codable, Sendable, Identifiable {
    case food
    case transport
    case cafe
    case shopping
    case living
    case housing
    case salary
    case etc

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .food: "식비"
        case .transport: "교통"
        case .cafe: "카페/간식"
        case .shopping: "쇼핑"
        case .living: "생활/마트"
        case .housing: "주거/통신"
        case .salary: "급여"
        case .etc: "기타"
        }
    }

    /// SF Symbol name. The design's own icon set is not bundled, so these are the closest system
    /// equivalents to the glyphs used on the category chips and list rows.
    public var symbolName: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "bus.fill"
        case .cafe: "cup.and.saucer.fill"
        case .shopping: "tag.fill"
        case .living: "cart.fill"
        case .housing: "house.fill"
        case .salary: "wonsign.circle.fill"
        case .etc: "square.grid.2x2.fill"
        }
    }

    /// Category accent as the hex used in the design. Kept here rather than in the view layer so
    /// the dot on the dashboard, the donut slice and the budget bar cannot drift apart.
    public var colorHex: UInt32 {
        switch self {
        case .food: 0x4F46E5
        case .transport: 0x3B82F6
        case .cafe: 0xF59E0B
        case .shopping: 0xEC4899
        case .living: 0xF97316
        case .housing: 0x14B8A6
        case .salary: 0x10B981
        case .etc: 0x9CA3AF
        }
    }

    public var isIncome: Bool { self == .salary }

    /// The category chips the add screen offers, per mode.
    public static var expenseCases: [Category] { allCases.filter { !$0.isIncome } }
    public static var incomeCases: [Category] { [.salary, .etc] }
}
