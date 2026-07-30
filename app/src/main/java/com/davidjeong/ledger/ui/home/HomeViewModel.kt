package com.davidjeong.ledger.ui.home

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.davidjeong.ledger.data.local.CategoryTotal
import com.davidjeong.ledger.data.local.LedgerDatabase
import com.davidjeong.ledger.data.local.TransactionEntity
import com.davidjeong.ledger.data.repository.LedgerRepository
import com.davidjeong.ledger.util.MonthRange
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.flatMapLatest
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class HomeUiState(
    val month: MonthRange = MonthRange.current(),
    val transactions: List<TransactionEntity> = emptyList(),
    val expenseTotal: Long = 0,
    val incomeTotal: Long = 0,
    val categoryTotals: List<CategoryTotal> = emptyList(),
)

@OptIn(ExperimentalCoroutinesApi::class)
class HomeViewModel(application: Application) : AndroidViewModel(application) {

    private val repository =
        LedgerRepository(LedgerDatabase.get(application).transactionDao())

    private val month = MutableStateFlow(MonthRange.current())

    val uiState = month
        .flatMapLatest { range ->
            combine(
                repository.observeMonth(range),
                repository.observeExpenseTotal(range),
                repository.observeIncomeTotal(range),
                repository.observeCategoryTotals(range),
            ) { transactions, expense, income, categories ->
                HomeUiState(range, transactions, expense, income, categories)
            }
        }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), HomeUiState())

    fun showPreviousMonth() {
        month.value = month.value.previous()
    }

    fun showNextMonth() {
        month.value = month.value.next()
    }

    fun delete(transaction: TransactionEntity) {
        viewModelScope.launch { repository.delete(transaction) }
    }
}
