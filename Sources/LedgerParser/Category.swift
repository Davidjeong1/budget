import Foundation

public enum Category: String, CaseIterable, Codable, Sendable {
    case food
    case cafe
    case transport
    case shopping
    case housing
    case health
    case culture
    case education
    case income
    case etc

    public var label: String {
        switch self {
        case .food: "식비"
        case .cafe: "카페/간식"
        case .transport: "교통"
        case .shopping: "쇼핑"
        case .housing: "주거/통신"
        case .health: "의료/건강"
        case .culture: "문화/여가"
        case .education: "교육"
        case .income: "수입"
        case .etc: "기타"
        }
    }
}
