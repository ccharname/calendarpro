import XCTest
import EventKit
@testable import CalendarPro

/// Regression lock for B10: recurring reminders must appear exactly on each
/// occurrence date and not be duplicated or suppressed.
@MainActor
final class RecurringReminderOccurrenceTests: XCTestCase {

    // MARK: - Helpers

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }()

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year, month: month, day: day
        ))!
    }

    private func makeRecurringReminder(
        startYear: Int, startMonth: Int, startDay: Int,
        frequency: EKRecurrenceFrequency,
        interval: Int = 1,
        end: EKRecurrenceEnd? = nil
    ) -> EKReminder {
        let store = EKEventStore()
        let reminder = EKReminder(eventStore: store)
        reminder.title = "Recurring reminder"
        reminder.dueDateComponents = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: startYear,
            month: startMonth,
            day: startDay,
            hour: 9,
            minute: 0
        )
        reminder.recurrenceRules = [
            EKRecurrenceRule(recurrenceWith: frequency, interval: interval, end: end)
        ]
        return reminder
    }

    // MARK: - B10 Regression: occurrence appears on the correct date

    /// A daily recurring reminder starting Apr 1 2026 must appear on Apr 15 2026.
    func testDailyReminderAppearsOnOccurrenceDate() {
        let reminder = makeRecurringReminder(
            startYear: 2026, startMonth: 4, startDay: 1,
            frequency: .daily
        )
        let targetDate = makeDate(year: 2026, month: 4, day: 15)

        XCTAssertTrue(
            EventService.reminder(reminder, isDueOn: targetDate, calendar: calendar),
            "Daily reminder should appear on occurrence date"
        )
    }

    /// The same reminder must NOT appear the day BEFORE its original start date.
    func testDailyReminderDoesNotAppearBeforeStartDate() {
        let reminder = makeRecurringReminder(
            startYear: 2026, startMonth: 4, startDay: 10,
            frequency: .daily
        )
        let beforeStart = makeDate(year: 2026, month: 4, day: 9)

        XCTAssertFalse(
            EventService.reminder(reminder, isDueOn: beforeStart, calendar: calendar),
            "Daily reminder must not appear before its original start date"
        )
    }

    /// A daily reminder with occurrenceCount=3 must not appear on the 4th day.
    func testDailyReminderDoesNotExceedOccurrenceCount() {
        let reminder = makeRecurringReminder(
            startYear: 2026, startMonth: 4, startDay: 1,
            frequency: .daily,
            end: EKRecurrenceEnd(occurrenceCount: 3)
        )
        let withinBound = makeDate(year: 2026, month: 4, day: 3)
        let beyondBound = makeDate(year: 2026, month: 4, day: 4)

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: withinBound, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: beyondBound, calendar: calendar))
    }

    /// A weekly reminder starting Wednesday Apr 22 2026 appears on Wednesday Apr 29 2026
    /// but NOT on Thursday Apr 30 2026 (wrong weekday).
    func testWeeklyReminderAppearsOnCorrectWeekday() {
        let reminder = makeRecurringReminder(
            startYear: 2026, startMonth: 4, startDay: 22,
            frequency: .weekly
        )
        let correctDay = makeDate(year: 2026, month: 4, day: 29)
        let wrongDay   = makeDate(year: 2026, month: 4, day: 30)

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: correctDay, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: wrongDay, calendar: calendar))
    }

    /// A monthly reminder on the 15th appears on May 15 2026 but not May 16 2026.
    func testMonthlyReminderAppearsOnCorrectDayOfMonth() {
        let reminder = makeRecurringReminder(
            startYear: 2026, startMonth: 1, startDay: 15,
            frequency: .monthly
        )
        let onDay  = makeDate(year: 2026, month: 5, day: 15)
        let offDay = makeDate(year: 2026, month: 5, day: 16)

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: onDay, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: offDay, calendar: calendar))
    }

    /// A daily reminder with an end date must not appear after the end date.
    func testDailyReminderDoesNotAppearAfterEndDate() {
        let endDate = makeDate(year: 2026, month: 4, day: 10)
        let reminder = makeRecurringReminder(
            startYear: 2026, startMonth: 4, startDay: 1,
            frequency: .daily,
            end: EKRecurrenceEnd(end: endDate)
        )
        let onEndDate    = makeDate(year: 2026, month: 4, day: 10)
        let afterEndDate = makeDate(year: 2026, month: 4, day: 11)

        XCTAssertTrue(EventService.reminder(reminder, isDueOn: onEndDate, calendar: calendar))
        XCTAssertFalse(EventService.reminder(reminder, isDueOn: afterEndDate, calendar: calendar))
    }
}
