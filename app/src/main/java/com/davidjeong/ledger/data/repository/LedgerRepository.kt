package com.davidjeong.ledger.data.repository

import com.davidjeong.ledger.data.local.CategoryTotal
import com.davidjeong.ledger.data.local.TransactionDao
import com.davidjeong.ledger.data.local.TransactionEntity
import com.davidjeong.ledger.parser.MerchantCategoryClassifier
import com.davidjeong.ledger.parser.ParsedPayment
import com.davidjeong.ledger.util.MonthRange
import com.davidjeong.ledger.util.resolveTimestamp
import kotlinx.coroutines.flow.Flow

class LedgerRepository(private val dao: TransactionDao) {

    fun observeAll(): Flow<List<TransactionEntity>> = dao.observeAll()

    fun observeMonth(range: MonthRange): Flow<List<TransactionEntity>> =
        dao.observeBetween(range.startMillis, range.endMillis)

    fun observeExpenseTotal(range: MonthRange): Flow<Long> =
        dao.observeExpenseTotal(range.startMillis, range.endMillis)

    fun observeIncomeTotal(range: MonthRange): Flow<Long> =
        dao.observeIncomeTotal(range.startMillis, range.endMillis)

    fun observeCategoryTotals(range: MonthRange): Flow<List<CategoryTotal>> =
        dao.observeCategoryTotals(range.startMillis, range.endMillis)

    suspend fun getById(id: Long): TransactionEntity? = dao.getById(id)

    suspend fun upsert(transaction: TransactionEntity) {
        if (transaction.id == 0L) dao.insert(transaction) else dao.update(transaction)
    }

    suspend fun delete(transaction: TransactionEntity) = dao.delete(transaction)

    /**
     * Writes an auto-recognised approval. Returns false when the database rejected it as a
     * duplicate, which happens routinely because one payment can arrive as both an SMS and a
     * KakaoTalk notification.
     */
    suspend fun recordAutoCaptured(payment: ParsedPayment): Boolean {
        val occurredAt = payment.approvedAt.resolveTimestamp()
        val merchant = payment.merchant?.takeIf { it.isNotBlank() } ?: "미상 가맹점"
        // A cancellation is stored as a negative expense rather than as income, so that the
        // monthly expense total nets it against the original approval instead of the refund
        // showing up as earnings.
        val entity = TransactionEntity(
            amount = if (payment.isCancellation) -payment.amount else payment.amount,
            isExpense = true,
            merchant = merchant,
            category = MerchantCategoryClassifier.classify(payment.merchant),
            occurredAt = occurredAt,
            issuer = payment.issuer,
            cardLast4 = payment.cardLast4,
            installmentMonths = payment.installmentMonths,
            isAutoCaptured = true,
            rawMessage = payment.rawText,
            dedupeKey = buildDedupeKey(payment, occurredAt, merchant),
        )
        return dao.insert(entity) != -1L
    }

    /**
     * Deliberately excludes the source channel and the raw text so that the SMS copy and the
     * KakaoTalk copy of one approval collapse onto the same key. The timestamp is bucketed to
     * the minute because the two channels can disagree by a few seconds.
     */
    private fun buildDedupeKey(payment: ParsedPayment, occurredAt: Long, merchant: String): String {
        val minuteBucket = occurredAt / 60_000L
        return listOf(
            payment.amount.toString(),
            merchant,
            payment.cardLast4.orEmpty(),
            payment.isCancellation.toString(),
            minuteBucket.toString(),
        ).joinToString("|")
    }
}
