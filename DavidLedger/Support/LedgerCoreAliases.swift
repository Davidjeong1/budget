import LedgerCore

/// `Category` is declared both by `LedgerCore` and by a framework this target imports, so an
/// unqualified `Category` here is ambiguous for type lookup. A declaration in this module takes
/// precedence over any imported one, so this alias resolves every use site at once and keeps the
/// call sites reading as `Category` instead of `LedgerCore.Category`.
///
/// The alias is deliberately not `public` — it only needs to cover this target.
typealias Category = LedgerCore.Category
