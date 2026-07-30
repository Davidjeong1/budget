package com.davidjeong.ledger.util

import java.text.NumberFormat
import java.time.format.DateTimeFormatter
import java.util.Locale

private val wonFormat: NumberFormat = NumberFormat.getIntegerInstance(Locale.KOREA)
private val dayFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("M월 d일 (E)", Locale.KOREA)
private val timeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.KOREA)

fun Long.toWon(): String = "${wonFormat.format(this)}원"

fun Long.toDayLabel(): String = toLocalDateTime().format(dayFormatter)

fun Long.toTimeLabel(): String = toLocalDateTime().format(timeFormatter)
