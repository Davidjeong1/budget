package com.davidjeong.ledger.data.local

import androidx.room.TypeConverter
import com.davidjeong.ledger.parser.Category

class Converters {
    @TypeConverter
    fun categoryToName(category: Category): String = category.name

    @TypeConverter
    fun nameToCategory(name: String): Category =
        runCatching { Category.valueOf(name) }.getOrDefault(Category.ETC)
}
