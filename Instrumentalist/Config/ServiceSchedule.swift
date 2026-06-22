import Foundation

/// When the service begins. The prelude countdown targets this so the prelude
/// finishes right as the service starts. (Future: make this a setting.)
///
/// TESTING: the target is currently *daily* (the next 10:30 on any day) so the
/// countdown + auto-play can be exercised every day this week. To lock it back
/// to Sundays for production, re-add `comps.weekday = weekday` in `nextStart`.
enum ServiceSchedule {
    static let hour = 10
    static let minute = 30
    static let weekday = 1 // Gregorian: 1 = Sunday

    /// TEMPORARY test mode: target the next :00/:30 half-hour boundary (11:00,
    /// 11:30, 12:00 …) so the countdown + auto-play can be exercised every half
    /// hour today. Set back to `false` (and re-add `comps.weekday` below) for
    /// production.
    static let testMode = true

    /// The next service start strictly after `now`.
    static func nextStart(after now: Date, calendar: Calendar = .current) -> Date {
        if testMode {
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: now)
            let minute = comps.minute ?? 0
            let stepToNext = minute < 30 ? (30 - minute) : (60 - minute)
            let startOfMinute = calendar.date(from: comps) ?? now
            return calendar.date(byAdding: .minute, value: stepToNext, to: startOfMinute) ?? now
        }

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        // Daily for testing — omitting `comps.weekday` matches the next 10:30 on
        // any day. For production: `comps.weekday = weekday`.
        return calendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) ?? now
    }
}
