package com.davidjeong.ledger.ui.home

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.davidjeong.ledger.data.local.TransactionEntity
import com.davidjeong.ledger.util.toDayLabel
import com.davidjeong.ledger.util.toTimeLabel
import com.davidjeong.ledger.util.toWon

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    onAddTransaction: () -> Unit,
    onEditTransaction: (Long) -> Unit,
    onOpenSettings: () -> Unit,
    viewModel: HomeViewModel = viewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("다비드 가계부", fontWeight = FontWeight.Bold) },
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "설정")
                    }
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddTransaction) {
                Icon(Icons.Default.Add, contentDescription = "직접 입력")
            }
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier.fillMaxSize().padding(padding),
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            item {
                MonthSummaryCard(
                    state = state,
                    onPrevious = viewModel::showPreviousMonth,
                    onNext = viewModel::showNextMonth,
                )
            }

            if (state.transactions.isEmpty()) {
                item { EmptyLedgerMessage() }
            } else {
                items(state.transactions, key = { it.id }) { transaction ->
                    TransactionRow(
                        transaction = transaction,
                        onClick = { onEditTransaction(transaction.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun MonthSummaryCard(
    state: HomeUiState,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(20.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = onPrevious) {
                    Icon(Icons.Default.KeyboardArrowLeft, contentDescription = "이전 달")
                }
                Text(
                    text = "${state.month.yearMonth.year}년 ${state.month.yearMonth.monthValue}월",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                IconButton(onClick = onNext) {
                    Icon(Icons.Default.KeyboardArrowRight, contentDescription = "다음 달")
                }
            }

            Spacer(Modifier.height(8.dp))

            Text(
                text = state.expenseTotal.toWon(),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                text = "이번 달 지출",
                style = MaterialTheme.typography.bodyMedium,
            )

            if (state.incomeTotal > 0) {
                Spacer(Modifier.height(8.dp))
                Text(
                    text = "수입 ${state.incomeTotal.toWon()}",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }

            if (state.categoryTotals.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                CategoryBreakdown(state)
            }
        }
    }
}

@Composable
private fun CategoryBreakdown(state: HomeUiState) {
    val max = state.categoryTotals.maxOf { it.total }.coerceAtLeast(1L)

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        state.categoryTotals.take(5).forEach { entry ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = entry.category.label,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.width(72.dp),
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(8.dp)
                        .background(
                            MaterialTheme.colorScheme.surfaceVariant,
                            RoundedCornerShape(4.dp),
                        ),
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(entry.total.toFloat() / max)
                            .height(8.dp)
                            .background(
                                MaterialTheme.colorScheme.primary,
                                RoundedCornerShape(4.dp),
                            ),
                    )
                }
                Spacer(Modifier.width(8.dp))
                Text(
                    text = entry.total.toWon(),
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}

@Composable
private fun TransactionRow(transaction: TransactionEntity, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = transaction.merchant,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold,
                    )
                    if (transaction.isAutoCaptured) {
                        Spacer(Modifier.width(6.dp))
                        AutoCaptureBadge()
                    }
                }
                Spacer(Modifier.height(2.dp))
                Text(
                    text = buildString {
                        append(transaction.category.label)
                        append(" · ")
                        append(transaction.occurredAt.toDayLabel())
                        append(" ")
                        append(transaction.occurredAt.toTimeLabel())
                        transaction.installmentMonths?.let { append(" · ${it}개월 할부") }
                    },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }

            // A cancellation is a negative expense, so the sign has to come from the value
            // rather than from isExpense alone.
            val signed =
                if (transaction.isExpense) -transaction.amount else transaction.amount

            Text(
                text = if (signed >= 0) "+${signed.toWon()}" else signed.toWon(),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = if (signed < 0) {
                    MaterialTheme.colorScheme.onSurface
                } else {
                    MaterialTheme.colorScheme.tertiary
                },
            )
        }
    }
}

@Composable
private fun AutoCaptureBadge() {
    Surface(
        color = MaterialTheme.colorScheme.tertiaryContainer,
        shape = RoundedCornerShape(4.dp),
    ) {
        Text(
            text = "자동",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onTertiaryContainer,
            modifier = Modifier.padding(horizontal = 5.dp, vertical = 1.dp),
        )
    }
}

@Composable
private fun EmptyLedgerMessage() {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(24.dp)) {
            Text(
                text = "아직 내역이 없습니다",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                text = "설정에서 문자·카카오톡 권한을 허용하면 승인 결제 금액이 자동으로 기록됩니다.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}
