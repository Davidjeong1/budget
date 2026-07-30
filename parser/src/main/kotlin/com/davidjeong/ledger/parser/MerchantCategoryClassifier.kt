package com.davidjeong.ledger.parser

/**
 * Guesses a ledger category from a merchant name so auto-captured payments land in a
 * sensible bucket instead of always falling into 기타. Keyword matching only — the user
 * can always correct it, and a correction is what should ultimately drive the category.
 */
object MerchantCategoryClassifier {

    private val KEYWORDS: List<Pair<Category, List<String>>> = listOf(
        Category.CAFE to listOf(
            "스타벅스", "starbucks", "투썸", "이디야", "커피", "coffee", "카페", "cafe",
            "메가엠지씨", "빽다방", "공차", "베스킨", "던킨", "파리바게뜨", "뚜레쥬르",
        ),
        Category.FOOD to listOf(
            "배달의민족", "배민", "요기요", "쿠팡이츠", "맥도날드", "버거킹", "롯데리아",
            "김밥", "식당", "치킨", "피자", "분식", "국밥", "고깃", "마라",
        ),
        Category.TRANSPORT to listOf(
            "카카오티", "카카오 t", "택시", "지하철", "버스", "코레일", "ktx", "srt",
            "주유", "gs칼텍스", "sk에너지", "s-oil", "현대오일뱅크", "하이패스", "티머니",
        ),
        Category.SHOPPING to listOf(
            "쿠팡", "coupang", "11번가", "지마켓", "gmarket", "옥션", "네이버쇼핑", "무신사",
            "올리브영", "다이소", "이마트", "홈플러스", "롯데마트", "쓱", "ssg", "마켓컬리",
            "cu", "gs25", "세븐일레븐", "이마트24", "편의점",
        ),
        Category.HOUSING to listOf(
            "kt", "skt", "lg유플러스", "lgu+", "통신", "한국전력", "도시가스", "수도",
            "관리비", "월세", "임대료", "인터넷",
        ),
        Category.HEALTH to listOf(
            "병원", "의원", "약국", "치과", "한의원", "clinic", "헬스", "피트니스", "짐",
        ),
        Category.CULTURE to listOf(
            "cgv", "메가박스", "롯데시네마", "영화", "넷플릭스", "netflix", "왓챠", "웨이브",
            "유튜브", "youtube", "스포티파이", "spotify", "멜론", "티빙", "노래방", "pc방",
        ),
        Category.EDUCATION to listOf(
            "학원", "교보문고", "yes24", "알라딘", "인프런", "클래스101", "강의", "서점",
        ),
    )

    fun classify(merchant: String?): Category {
        if (merchant.isNullOrBlank()) return Category.ETC
        val needle = merchant.lowercase()
        for ((category, keywords) in KEYWORDS) {
            if (keywords.any { needle.contains(it.lowercase()) }) return category
        }
        return Category.ETC
    }
}
