import SwiftUI
import LedgerCore

/// A category as the screens need it: one value covering both the built-in `Category` cases and the
/// user's own, so no screen has to branch on which kind it is holding.
struct LedgerCategory: Identifiable, Hashable {
    /// The value persisted in `Transaction.categoryRaw` and in the keys of `Budget.categoryTargets`.
    let raw: String
    let label: String
    let symbolName: String
    let colorHex: UInt32
    let isIncome: Bool
    let isCustom: Bool
    /// True for a user category that has been deleted. Still resolvable so old rows render, but
    /// never offered when filing a new one.
    let isArchived: Bool

    var id: String { raw }
    var color: Color { Color(hex: colorHex) }

    init(builtin: Category) {
        raw = builtin.rawValue
        label = builtin.label
        symbolName = builtin.symbolName
        colorHex = builtin.colorHex
        isIncome = builtin.isIncome
        isCustom = false
        isArchived = false
    }

    init(custom: CustomCategory) {
        raw = custom.raw
        label = custom.name
        symbolName = custom.symbolName
        colorHex = UInt32(truncatingIfNeeded: custom.colorValue)
        isIncome = custom.isIncome
        isCustom = true
        isArchived = custom.isArchived
    }

    /// A category that does not exist yet — the one being drafted in the category editor. Built
    /// directly rather than from a throwaway `CustomCategory`, which would mean creating a model
    /// object on every keystroke just to render a preview.
    init(draft label: String, symbolName: String, colorHex: UInt32, isIncome: Bool) {
        raw = ""
        self.label = label
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.isIncome = isIncome
        isCustom = true
        isArchived = false
    }

    /// Identity is the persisted key alone. Renaming a category must not make the rows already
    /// grouped under it look like they belong to a different one.
    static func == (lhs: LedgerCategory, rhs: LedgerCategory) -> Bool { lhs.raw == rhs.raw }

    func hash(into hasher: inout Hasher) { hasher.combine(raw) }
}

/// Resolves a stored category key to something displayable and lists what the user may pick.
/// Built from the `CustomCategory` rows a view already holds through `@Query`, so there is no
/// second source of truth to keep in sync.
struct CategoryCatalog {
    private let customs: [LedgerCategory]
    private let byRaw: [String: LedgerCategory]

    init(customs: [CustomCategory]) {
        let ordered = customs
            .sorted { $0.createdAt < $1.createdAt }
            .map { LedgerCategory(custom: $0) }
        self.customs = ordered

        var index: [String: LedgerCategory] = [:]
        for builtin in Category.allCases {
            index[builtin.rawValue] = LedgerCategory(builtin: builtin)
        }
        for custom in ordered {
            index[custom.raw] = custom
        }
        byRaw = index
    }

    /// Falls back to 기타 rather than returning nil: a key whose record is missing should still
    /// render a row instead of dropping the transaction off the screen entirely.
    func category(forRaw raw: String) -> LedgerCategory {
        byRaw[raw] ?? LedgerCategory(builtin: .etc)
    }

    /// The chips offered on the add screen, built-ins first so the familiar ones keep their place.
    var expenseChoices: [LedgerCategory] {
        Category.expenseCases.map { LedgerCategory(builtin: $0) }
            + customs.filter { !$0.isIncome && !$0.isArchived }
    }

    var incomeChoices: [LedgerCategory] {
        Category.incomeCases.map { LedgerCategory(builtin: $0) }
            + customs.filter { $0.isIncome && !$0.isArchived }
    }

    var activeCustoms: [LedgerCategory] { customs.filter { !$0.isArchived } }

    var archivedCustoms: [LedgerCategory] { customs.filter(\.isArchived) }

    /// Built-ins in declaration order, then the user's by age. Keeps lists from reshuffling when a
    /// total or a target changes.
    func orderIndex(ofRaw raw: String) -> Int {
        if let index = Category.allCases.firstIndex(where: { $0.rawValue == raw }) {
            return index
        }
        if let index = customs.firstIndex(where: { $0.raw == raw }) {
            return Category.allCases.count + index
        }
        return Int.max
    }

    /// Case- and whitespace-insensitive, because two categories that read the same on a chip are
    /// indistinguishable to the user however they were typed.
    func nameIsTaken(_ name: String, excluding raw: String? = nil) -> Bool {
        let candidate = name.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty else { return false }
        let existing = Category.allCases.map { LedgerCategory(builtin: $0) } + customs.filter { !$0.isArchived }
        return existing.contains { $0.raw != raw && $0.label.lowercased() == candidate }
    }
}
