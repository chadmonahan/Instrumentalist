import Foundation

/// When the Sunday service begins. The prelude countdown targets this so the
/// prelude finishes right as the service starts. (Future: make this a setting.)
enum ServiceSchedule {
    static let hour = 10
    static let minute = 30
    static let weekday = 1 // Gregorian: 1 = Sunday

    /// The next service start strictly after `now`.
    static func nextStart(after now: Date, calendar: Calendar = .current) -> Date {
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        comps.weekday = weekday
        return calendar.nextDate(after: now, matching: comps, matchingPolicy: .nextTime) ?? now
    }
}
