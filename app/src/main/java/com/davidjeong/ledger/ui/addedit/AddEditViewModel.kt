package com.davidjeong.ledger.ui.addedit

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.davidjeong.ledger.data.local.LedgerDatabase
import com.davidjeong.ledger.data.local.TransactionEntity
import com.davidjeong.ledger.data.repository.LedgerRepository
import com.davidjeong.ledger.parser.Category
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AddEditUiState(
    val id: Long = 0,
    val amountText: String = "",
    val merchant: String = "",
    val memo: String = "",
    val category: Category = Category.ETC,
    val isExpense: Boolean = true,
    val occurredAt: Long = System.currentTimeMillis(),
    val isAutoCaptured: Boolean = false,
    val rawMessage: String? = null,
    val loaded: Boolean = false,
) {
    // Cancellations are stored as negative amounts, so editing one must not silently flip its sign.
    val amount: Long?
        get() {
            val magnitude = amountText.filter { it.isDigit() }.toLongOrNull() ?: return null
            return if (amountText.trimStart().startsWith("-")) -magnitude else magnitude
        }

    val canSave: Boolean get() = (amount ?: 0L) != 0L && merchant.isNotBlank()
}

class AddEditViewModel(application: Application) : AndroidViewModel(application) {

    private val repository =
        LedgerRepository(LedgerDatabase.get(application).transactionDao())

    private val _uiState = MutableStateFlow(AddEditUiState())
    val uiState = _uiState.asStateFlow()

    private var editing: TransactionEntity? = null

    fun load(id: Long) {
        if (_uiState.value.loaded) return
        if (id <= 0L) {
            _uiState.update { it.copy(loaded = true) }
            return
        }
        viewModelScope.launch {
            val entity = repository.getById(id)
            if (entity == null) {
                _uiState.update { it.copy(loaded = true) }
                return@launch
            }
            editing = entity
            _uiState.value = AddEditUiState(
                id = entity.id,
                amountText = entity.amount.toString(),
                merchant = entity.merchant,
                memo = entity.memo,
                category = entity.category,
                isExpense = entity.isExpense,
                occurredAt = entity.occurredAt,
                isAutoCaptured = entity.isAutoCaptured,
                rawMessage = entity.rawMessage,
                loaded = true,
            )
        }
    }

    fun onAmountChange(value: String) = _uiState.update { it.copy(amountText = value) }
    fun onMerchantChange(value: String) = _uiState.update { it.copy(merchant = value) }
    fun onMemoChange(value: String) = _uiState.update { it.copy(memo = value) }
    fun onCategoryChange(value: Category) = _uiState.update { it.copy(category = value) }
    fun onIsExpenseChange(value: Boolean) = _uiState.update { it.copy(isExpense = value) }

    fun save(onDone: () -> Unit) {
        val state = _uiState.value
        val amount = state.amount ?: return
        viewModelScope.launch {
            val base = editing
            repository.upsert(
                base?.copy(
                    amount = amount,
                    isExpense = state.isExpense,
                    merchant = state.merchant.trim(),
                    category = state.category,
                    memo = state.memo.trim(),
                ) ?: TransactionEntity(
                    amount = amount,
                    isExpense = state.isExpense,
                    merchant = state.merchant.trim(),
                    category = state.category,
                    memo = state.memo.trim(),
                    occurredAt = state.occurredAt,
                ),
            )
            onDone()
        }
    }

    fun delete(onDone: () -> Unit) {
        val target = editing ?: return onDone()
        viewModelScope.launch {
            repository.delete(target)
            onDone()
        }
    }
}
