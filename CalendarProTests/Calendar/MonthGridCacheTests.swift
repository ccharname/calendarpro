import XCTest
@testable import CalendarPro

@MainActor
final class MonthGridCacheTests: XCTestCase {
    private var calendar: Calendar { Calendar.gregorianMondayFirst }
    private var basePreferences: MenuBarPreferences { .default }

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year, month: month, day: day
        ).date!
    }

    // MARK: - Test 1: Same key twice → builder invoked only once

    func testSameKeyDoesNotRebuild() {
        var buildCount = 0
        let cache = MonthGridCache { month, prefs, selected in
            buildCount += 1
            return []
        }

        let month = makeDate(year: 2026, month: 5, day: 1)
        let today = makeDate(year: 2026, month: 5, day: 5)

        cache.update(displayedMonth: month, selectedDate: nil,
                     preferences: basePreferences, calendar: calendar, currentDate: today)
        cache.update(displayedMonth: month, selectedDate: nil,
                     preferences: basePreferences, calendar: calendar, currentDate: today)

        XCTAssertEqual(buildCount, 1)
    }

    // MARK: - Test 2: selectedDate change → builder invoked twice

    func testSelectedDateChangeTriggerRebuild() {
        var buildCount = 0
        let cache = MonthGridCache { _, _, _ in
            buildCount += 1
            return []
        }

        let month = makeDate(year: 2026, month: 5, day: 1)
        let today = makeDate(year: 2026, month: 5, day: 5)
        let selected1 = makeDate(year: 2026, month: 5, day: 10)
        let selected2 = makeDate(year: 2026, month: 5, day: 20)

        cache.update(displayedMonth: month, selectedDate: selected1,
                     preferences: basePreferences, calendar: calendar, currentDate: today)
        cache.update(displayedMonth: month, selectedDate: selected2,
                     preferences: basePreferences, calendar: calendar, currentDate: today)

        XCTAssertEqual(buildCount, 2)
    }

    // MARK: - Test 3: todayStartOfDay change (day rollover) → builder invoked twice

    func testDayRolloverTriggerRebuild() {
        var buildCount = 0
        let cache = MonthGridCache { _, _, _ in
            buildCount += 1
            return []
        }

        let month = makeDate(year: 2026, month: 5, day: 1)
        let today = makeDate(year: 2026, month: 5, day: 5)
        let tomorrow = makeDate(year: 2026, month: 5, day: 6)

        cache.update(displayedMonth: month, selectedDate: nil,
                     preferences: basePreferences, calendar: calendar, currentDate: today)
        cache.update(displayedMonth: month, selectedDate: nil,
                     preferences: basePreferences, calendar: calendar, currentDate: tomorrow)

        XCTAssertEqual(buildCount, 2)
    }

    // MARK: - Test 4: invalidate() then same key → builder invoked twice

    func testInvalidateForcesRebuildOnNextUpdate() {
        var buildCount = 0
        let cache = MonthGridCache { _, _, _ in
            buildCount += 1
            return []
        }

        let month = makeDate(year: 2026, month: 5, day: 1)
        let today = makeDate(year: 2026, month: 5, day: 5)

        cache.update(displayedMonth: month, selectedDate: nil,
                     preferences: basePreferences, calendar: calendar, currentDate: today)
        cache.invalidate()
        cache.update(displayedMonth: month, selectedDate: nil,
                     preferences: basePreferences, calendar: calendar, currentDate: today)

        XCTAssertEqual(buildCount, 2)
    }
}
