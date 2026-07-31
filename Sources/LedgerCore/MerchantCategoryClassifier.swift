import Foundation

/// Suggests a category from a merchant name while the user types it on the add screen, so a
/// familiar merchant does not have to be categorised by hand every time. Keyword matching only —
/// the suggestion is always overridable, and an explicit choice by the user wins.
public enum MerchantCategoryClassifier {

    private static let keywords: [(Category, [String])] = [
        (.cafe, [
            "스타벅스", "starbucks", "투썸", "이디야", "커피", "coffee", "카페", "cafe",
            "메가엠지씨", "빽다방", "공차", "베스킨", "던킨", "파리바게뜨", "뚜레쥬르",
        ]),
        (.food, [
            "배달의민족", "배민", "요기요", "쿠팡이츠", "맥도날드", "버거킹", "롯데리아",
            "김밥", "식당", "치킨", "피자", "분식", "국밥", "고깃", "마라",
        ]),
        (.transport, [
            "카카오티", "카카오 t", "택시", "지하철", "버스", "코레일", "ktx", "srt",
            "주유", "gs칼텍스", "sk에너지", "s-oil", "현대오일뱅크", "하이패스", "티머니",
            "서울메트로",
        ]),
        (.living, [
            "쿠팡", "coupang", "이마트", "홈플러스", "롯데마트", "마켓컬리", "다이소",
            "gs25", "세븐일레븐", "이마트24", "편의점",
        ]),
        (.shopping, [
            "11번가", "지마켓", "gmarket", "옥션", "네이버쇼핑", "무신사", "올리브영",
            "ssg", "지그재그", "에이블리",
        ]),
        (.housing, [
            "skt", "lg유플러스", "lgu+", "통신", "한국전력", "도시가스",
            "관리비", "월세", "임대료", "인터넷", "넷플릭스", "netflix", "유튜브", "youtube",
        ]),
        (.salary, [
            "급여", "월급", "상여", "성과급", "환급",
        ]),
    ]

    /// Matched against whole words instead of as substrings. These are short enough to collide
    /// with unrelated names — "CU" inside "CUCKOO", "KT" inside "KTX" — so a substring match would
    /// misfile them.
    private static let wordKeywords: [(Category, [String])] = [
        (.living, ["cu", "쓱"]),
        (.housing, ["kt", "수도"]),
    ]

    public static func classify(_ merchant: String?) -> Category {
        guard let merchant, !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .etc
        }
        let needle = merchant.lowercased()

        for (category, words) in keywords where words.contains(where: { needle.contains($0) }) {
            return category
        }

        let tokens = Set(
            needle
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
        )
        for (category, words) in wordKeywords where words.contains(where: { tokens.contains($0) }) {
            return category
        }
        return .etc
    }
}
