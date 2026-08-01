import Foundation

/// Where a month's spending lands if it carries on at the rate it has managed so far.
///
/// The budget alert already tells the user they crossed 90%, which is news that arrives too late to
/// act on. This says the same thing early: at this pace the money runs out on the 24th.
public enum BudgetPace: Equatable, Sendable {
    /// Already past the target — there is nothing left to project.
    case exceeded
    /// The target runs out on this day of the month at the current rate.
    case runsOut(day: Int, projectedTotal: Int)
    /// The month ends before the target does.
    case withinBudget(projectedTotal: Int)

    /// - Parameters:
    ///   - spent: expenses so far this month.
    ///   - target: the month's total budget.
    ///   - elapsedDays: days counted so far, today included.
    ///   - totalDays: days in the month.
    /// - Returns: nil when there is nothing to say — no target set, or nothing spent yet, in which
    ///   case any projection would be a straight line drawn through a single point at the origin.
    public static func projected(
        spent: Int,
        target: Int,
        elapsedDays: Int,
        totalDays: Int
    ) -> BudgetPace? {
        guard target > 0, totalDays > 0, elapsedDays > 0, spent > 0 else { return nil }
        guard spent < target else { return .exceeded }

        // Capped so a stray future-dated transaction cannot divide by more days than the month has
        // and flatten the rate to nothing.
        let rate = Double(spent) / Double(min(elapsedDays, totalDays))
        let projectedTotal = Int((rate * Double(totalDays)).rounded())

        // rate > 0 because spent > 0, and target - spent > 0 from the guard above, so this is a
        // positive number of days and always rounds up to at least one.
        let daysToExhaust = Int((Double(target - spent) / rate).rounded(.up))
        let day = elapsedDays + daysToExhaust

        return day <= totalDays
            ? .runsOut(day: day, projectedTotal: projectedTotal)
            : .withinBudget(projectedTotal: projectedTotal)
    }
}
