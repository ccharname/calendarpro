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

    // MARK: - Test 3b: selectedDate change → rebuilt days reflect new isSelected cell
    // Regression for click-not-switching: when the user taps a new date the cache must
    // rebuild and the correct cell must carry isSelected = true.

    func testSelectedDateChangeReflectedInCellIsSelected() {
        let month = makeDate(year: 2026, month: 5, day: 1)
        let today = makeDate(year: 2026, month: 5, day: 5)
        let selected1 = makeDate(year: 2026, month: 5, day: 10)
        let selected2 = makeDate(year: 2026, month: 5, day: 20)

        // Real factory path (no buildOverride) so we can inspect CalendarDay.isSelected.
        let cache = MonthGridCache()

        cache.update(displayedMonth: month, selectedDate: selected1,
                     preferences: basePreferences, calendar: calendar, currentDate: today)
        let days1 = cache.days
        let cell1Selected = days1.first(where: { calendar.isDate($0.date, inSameDayAs: selected1) })
        XCTAssertNotNil(cell1Selected, "Grid must contain the selected date")
        XCTAssertTrue(cell1Selected!.isSelected, "Cell for selected1 must be marked isSelected")
        let otherNotSelected = days1.first(where: { calendar.isDate($0.date, inSameDayAs: selected2) })
        XCTAssertFalse(otherNotSelected?.isSelected ?? false, "Cell for selected2 must NOT be isSelected yet")

        cache.update(displayedMonth: month, selectedDate: selected2,
                     preferences: basePreferences, calendar: calendar, currentDate: today)
        let days2 = cache.days
        let cell2Selected = days2.first(where: { calendar.isDate($0.date, inSameDayAs: selected2) })
        XCTAssertNotNil(cell2Selected, "Grid must contain the newly selected date")
        XCTAssertTrue(cell2Selected!.isSelected, "Cell for selected2 must be marked isSelected after update")
        let oldNotSelected = days2.first(where: { calendar.isDate($0.date, inSameDayAs: selected1) })
        XCTAssertFalse(oldNotSelected?.isSelected ?? false, "Cell for selected1 must no longer be isSelected")
    }

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
