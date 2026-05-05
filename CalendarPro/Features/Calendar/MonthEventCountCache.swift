import Foundation

/// Lightweight cache that maps startOfDay → event count for the displayed month.
/// Only active when `MenuBarPreferences.showDayEventDots` is true.
/// When the toggle is off this class is never updated; `counts` stays empty.
@MainActor
final class MonthEventCountCache: ObservableObject {
    @Published var counts: [Date: Int] = [:]

    /// Refresh event counts for every visible day in `displayedMonth`.
    /// No-op when `showDayEventDots` is false — avoids unnecessary EventKit fetches.
    func update(
        for displayedMonth: Date,
        showDayEventDots: Bool,
        showCalendarEvents: Bool,
        showReminders: Bool,
        enabledCalendarIDs: [String],
        enabledReminderCalendarIDs: [String],
        eventService: EventService,
        calendar: Calendar
    ) async {
        guard showDayEventDots else { return }

        // Build the full 42-day grid range visible on screen.
        let service = MonthCalendarService(calendar: calendar)
        let gridDays = service.makeMonthGrid(for: displayedMonth)

        var updated: [Date: Int] = [:]
        for day in gridDays {
            let dayStart = calendar.startOfDay(for: day.date)
            let items = await eventService.fetchCalendarItems(
                for: dayStart,
                enabledCalendarIDs: enabledCalendarIDs,
                enabledReminderCalendarIDs: enabledReminderCalendarIDs,
                showCalendarEvents: showCalendarEvents,
                showReminders: showReminders
            )
            updated[dayStart] = items.count
        }

        counts = updated
    }
}
