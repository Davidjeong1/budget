package com.davidjeong.ledger.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey
import com.davidjeong.ledger.parser.Category

/**
 * [dedupeKey] is what stops the same approval being written twice when a card company sends
 * both an SMS and a KakaoTalk 알림톡 for one payment. It is a unique index, so a duplicate
 * insert is dropped by the database rather than needing a read-then-write check.
 */
@Entity(
    tableName = "transactions",
    indices = [
        Index(value = ["dedupeKey"], unique = true),
        Index(value = ["occurredAt"]),
    ],
)
data class TransactionEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val amount: Long,
    val isExpense: Boolean,
    val merchant: String,
    val category: Category,
    val memo: String = "",
    val occurredAt: Long,
    val issuer: String? = null,
    val cardLast4: String? = null,
    val installmentMonths: Int? = null,
    val isAutoCaptured: Boolean = false,
    val rawMessage: String? = null,
    val dedupeKey: String? = null,
)
