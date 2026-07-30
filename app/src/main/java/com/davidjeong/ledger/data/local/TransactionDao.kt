package com.davidjeong.ledger.data.local

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import com.davidjeong.ledger.parser.Category
import kotlinx.coroutines.flow.Flow

@Dao
interface TransactionDao {

    @Query("SELECT * FROM transactions ORDER BY occurredAt DESC")
    fun observeAll(): Flow<List<TransactionEntity>>

    @Query("SELECT * FROM transactions WHERE occurredAt BETWEEN :from AND :to ORDER BY occurredAt DESC")
    fun observeBetween(from: Long, to: Long): Flow<List<TransactionEntity>>

    @Query("SELECT * FROM transactions WHERE id = :id")
    suspend fun getById(id: Long): TransactionEntity?

    /** Returns -1 when the row was dropped as a duplicate of an already-captured approval. */
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insert(transaction: TransactionEntity): Long

    @Update
    suspend fun update(transaction: TransactionEntity)

    @Delete
    suspend fun delete(transaction: TransactionEntity)

    @Query("SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE isExpense = 1 AND occurredAt BETWEEN :from AND :to")
    fun observeExpenseTotal(from: Long, to: Long): Flow<Long>

    @Query("SELECT COALESCE(SUM(amount), 0) FROM transactions WHERE isExpense = 0 AND occurredAt BETWEEN :from AND :to")
    fun observeIncomeTotal(from: Long, to: Long): Flow<Long>

    @Query(
        "SELECT category, COALESCE(SUM(amount), 0) AS total FROM transactions " +
            "WHERE isExpense = 1 AND occurredAt BETWEEN :from AND :to " +
            "GROUP BY category ORDER BY total DESC",
    )
    fun observeCategoryTotals(from: Long, to: Long): Flow<List<CategoryTotal>>
}

data class CategoryTotal(
    val category: Category,
    val total: Long,
)
