import Foundation

@MainActor
final class MonthGridCache: ObservableObject {
    @Published private(set) var days: [CalendarDay] = []

    private struct Key: Equatable {
        let displayedMonthStart: Date
        let selectedDayStart: Date?
        let weekStart: WeekStart
        let activeRegionIDs: [String]
        let enabledHolidayIDs: [String]
        let lunarDisplayStyle: LunarDisplayStyle
        let todayStartOfDay: Date
    }

    private var lastKey: Key?
    private var hasBuiltOnce: Bool = false
    private var storedCalendar: Calendar?
    private var factory: CalendarDayFactory?
    private var fallbackService: MonthCalendarService?

    // Test seam: when set, replaces the real factory build.
    private let buildOverride: ((Date, MenuBarPreferences, Date?) -> [CalendarDay])?

    init(buildOverride: ((Date, MenuBarPreferences, Date?) -> [CalendarDay])? = nil) {
        self.buildOverride = buildOverride
    }

    func update(
        displayedMonth: Date,
        selectedDate: Date?,
        preferences: MenuBarPreferences,
        calendar: Calendar,
        currentDate: Date
    ) {
        let todayStart = calendar.startOfDay(for: currentDate)
        let monthStart = Self.normalizeToMonthStart(displayedMonth, calendar: calendar)
        let selectedDayStart = selectedDate.map { calendar.startOfDay(for: $0) }

        let key = Key(
            displayedMonthStart: monthStart,
            selectedDayStart: selectedDayStart,
            weekStart: preferences.weekStart,
            activeRegionIDs: preferences.activeRegionIDs.sorted(),
            enabledHolidayIDs: preferences.enabledHolidayIDs.sorted(),
            lunarDisplayStyle: Self.lunarDisplayStyle(from: preferences),
            todayStartOfDay: todayStart
        )

        if key == lastKey, hasBuiltOnce {
            return
        }

        // Re-init factory when day rolls over or on first run.
        if factory == nil
            || storedCalendar == nil
            || key.todayStartOfDay != lastKey?.todayStartOfDay
        {
            factory = CalendarDayFactory(calendar: calendar, registry: .live, now: { currentDate })
            fallbackService = MonthCalendarService(calendar: calendar)
            storedCalendar = calendar
        }

        if let override = buildOverride {
            days = override(displayedMonth, preferences, selectedDate)
        } else {
            let resolved = (try? factory!.makeMonthGrid(
                for: displayedMonth,
                preferences: preferences,
                selectedDate: selectedDate
            )) ?? fallbackService!.makeMonthGrid(for: displayedMonth)
            days = resolved
        }

        lastKey = key
        hasBuiltOnce = true
    }

    func invalidate() {
        lastKey = nil
        // days intentionally preserved — next update() recomputes without flicker.
    }

    /// Force rebuild from scratch (e.g., calendar identifier changed).
    func reset() {
        lastKey = nil
        hasBuiltOnce = false
        factory = nil
        fallbackService = nil
        storedCalendar = nil
        days = []
    }

    // MARK: - Private helpers

    private static func normalizeToMonthStart(_ date: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    /// Mirrors CalendarDayFactory.lunarDisplayStyle(from:) exactly.
    static func lunarDisplayStyle(from preferences: MenuBarPreferences) -> LunarDisplayStyle {
        let tokenStyle = preferences.tokens.first(where: { $0.token == .lunar })?.style ?? .short
        switch tokenStyle {
        case .short:
            return .day
        case .chineseMonthDay:
            return .monthDay
        case .full:
            return .yearMonthDay
        default:
            return .day
        }
    }
}
