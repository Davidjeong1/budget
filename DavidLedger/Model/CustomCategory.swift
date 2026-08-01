import Foundation
import SwiftData

/// A category the user added themselves. The built-in eight stay in `LedgerCore.Category`; these
/// sit alongside them and are persisted by `raw` everywhere a category is stored.
@Model
final class CustomCategory {
    /// Not named `id`: `PersistentModel` already supplies one, and shadowing it makes the
    /// `Identifiable` conformance ambiguous.
    @Attribute(.unique) var uuid: UUID
    var name: String
    var symbolName: String
    /// The accent as 0xRRGGBB. Held as `Int` because SwiftData has no `UInt32` attribute type.
    var colorValue: Int
    var isIncome: Bool
    /// Deleting archives rather than erases, so a transaction filed under this category keeps
    /// showing the name, icon and colour it was recorded with. Archived categories are simply not
    /// offered when adding a new entry.
    var isArchived: Bool
    var createdAt: Date

    init(
        uuid: UUID = UUID(),
        name: String,
        symbolName: String,
        colorValue: Int,
        isIncome: Bool = false,
        isArchived: Bool = false,
        createdAt: Date = .now
    ) {
        self.uuid = uuid
        self.name = name
        self.symbolName = symbolName
        self.colorValue = colorValue
        self.isIncome = isIncome
        self.isArchived = isArchived
        self.createdAt = createdAt
    }

    static let rawPrefix = "custom:"

    /// The key written to `Transaction.categoryRaw` and the keys of `Budget.categoryTargets`.
    /// Prefixed so it can never collide with a `LedgerCore.Category` raw value.
    var raw: String { Self.rawPrefix + uuid.uuidString }
}
