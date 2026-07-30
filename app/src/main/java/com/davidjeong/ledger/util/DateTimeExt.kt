package com.davidjeong.ledger.util

import com.davidjeong.ledger.parser.PartialDateTime
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.YearMonth
import java.time.ZoneId

private val zone: ZoneId get() = ZoneId.systemDefault()

fun LocalDateTime.toEpochMillis(): Long = atZone(zone).toInstant().toEpochMilli()

fun Long.toLocalDateTime(): LocalDateTime =
    java.time.Instant.ofEpochMilli(this).atZone(zone).toLocalDateTime()

/**
 * Card messages carry only MM/dd HH:mm, so the year is inferred. A date more than a day in the
 * future means the message is really from last December being read in January, so roll the year
 * back rather than filing the payment eleven months ahead.
 */
fun PartialDateTime?.resolveTimestamp(now: LocalDateTime = LocalDateTime.now()): Long {
    if (this?.month == null || day == null) return now.toEpochMillis()

    val candidate = runCatching {
        LocalDate.of(now.year, month, day).atTime(hour ?: 0, minute ?: 0)
    }.getOrNull() ?: return now.toEpochMillis()

    val resolved = if (candidate.isAfter(now.plusDays(1))) candidate.minusYears(1) else candidate
    return resolved.toEpochMillis()
}

data class MonthRange(val yearMonth: YearMonth) {
    val startMillis: Long = yearMonth.atDay(1).atStartOfDay().toEpochMillis()
    val endMillis: Long = yearMonth.atEndOfMonth().atTime(23, 59, 59, 999_000_000).toEpochMillis()

    fun previous(): MonthRange = MonthRange(yearMonth.minusMonths(1))
    fun next(): MonthRange = MonthRange(yearMonth.plusMonths(1))

    companion object {
        fun current(): MonthRange = MonthRange(YearMonth.now())
    }
}
