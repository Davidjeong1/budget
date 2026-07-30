package com.davidjeong.ledger.parser

import kotlin.test.Test
import kotlin.test.assertEquals

class MerchantCategoryClassifierTest {

    @Test
    fun `cafe merchants are classified as cafe`() {
        assertEquals(Category.CAFE, MerchantCategoryClassifier.classify("스타벅스코리아"))
        assertEquals(Category.CAFE, MerchantCategoryClassifier.classify("STARBUCKS 강남점"))
        assertEquals(Category.CAFE, MerchantCategoryClassifier.classify("투썸플레이스"))
    }

    @Test
    fun `delivery and restaurant merchants are classified as food`() {
        assertEquals(Category.FOOD, MerchantCategoryClassifier.classify("배달의민족"))
        assertEquals(Category.FOOD, MerchantCategoryClassifier.classify("교촌치킨 역삼점"))
    }

    @Test
    fun `transport merchants are classified as transport`() {
        assertEquals(Category.TRANSPORT, MerchantCategoryClassifier.classify("카카오티 택시"))
        assertEquals(Category.TRANSPORT, MerchantCategoryClassifier.classify("GS칼텍스 셀프주유소"))
    }

    @Test
    fun `commerce and convenience merchants are classified as shopping`() {
        assertEquals(Category.SHOPPING, MerchantCategoryClassifier.classify("쿠팡"))
        assertEquals(Category.SHOPPING, MerchantCategoryClassifier.classify("GS25 삼성점"))
    }

    @Test
    fun `streaming merchants are classified as culture`() {
        assertEquals(Category.CULTURE, MerchantCategoryClassifier.classify("NETFLIX.COM"))
        assertEquals(Category.CULTURE, MerchantCategoryClassifier.classify("CGV 왕십리"))
    }

    @Test
    fun `unknown and blank merchants fall back to etc`() {
        assertEquals(Category.ETC, MerchantCategoryClassifier.classify("무슨무슨상사"))
        assertEquals(Category.ETC, MerchantCategoryClassifier.classify(null))
        assertEquals(Category.ETC, MerchantCategoryClassifier.classify("   "))
    }
}
