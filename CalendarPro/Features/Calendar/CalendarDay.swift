import Foundation

enum BadgeKind: String, Equatable {
    case festival
    case publicHoliday
    case statutoryHoliday
    case workingAdjustmentDay
}

struct DayBadge: Equatable, Identifiable {
    let kind: BadgeKind
    let text: String
    let priority: Int

    var id: String {
        "\(kind.rawValue)-\(text)-\(priority)"
    }
}

struct CalendarDay: Equatable, Identifiable {
    let date: Date
    /// Gregorian date as yyyyMMdd integer (e.g. 20260505). Computed once at construction time
    /// using POSIX/GMT so it never requires a DateFormatter at the call site.
    let solarDateKey: Int
    let isInDisplayedMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let isWeekend: Bool
    let solarText: String
    let lunarText: String?
    let lunarTextSemantic: LunarTextSemantic
    let badges: [DayBadge]
    /// Event count for the day event dots feature (nil = not fetched / feature off).
    let eventCount: Int?

    var id: Date { date }
}

private let _posixGMTCalendar: Calendar = {
    var c = Calendar(identifier: .gregorian)
    c.locale = Locale(identifier: "en_US_POSIX")
    c.timeZone = TimeZone(secondsFromGMT: 0)!
    return c
}()

extension CalendarDay {
    /// Constructs a `solarDateKey` (yyyyMMdd) from `date` using a POSIX/GMT Gregorian calendar.
    static func makeSolarDateKey(from date: Date) -> Int {
        let comps = _posixGMTCalendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return y * 10000 + m * 100 + d
    }
}
