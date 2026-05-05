import XCTest
@testable import CalendarPro

/// Regression lock for B11: after a cross-day wake the view-model must sync
/// `selectedDate` (and `displayedMonth`) to the new today when the selection
/// was previously following the current day.
@MainActor
final class TimeRefreshCoordinatorDayChangeTests: XCTestCase {

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: .gregorianMondayFirst,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year, month: month, day: day
        ).date!
    }

    // MARK: - B11 Regression

    /// Scenario: user had today (June 15) selected with followsCurrentDay=true.
    /// After a cross-day wake, now() returns June 16.
    /// syncCurrentDaySelectionIfNeeded must update selectedDate to June 16
    /// and displayedMonth to June 2030.
    func testSyncAfterCrossDayWakeMovesSelectedDateToNewToday() {
        let yesterday = makeDate(year: 2030, month: 6, day: 15)
        let today     = makeDate(year: 2030, month: 6, day: 16)
        let currentDate = MutableBox(yesterday)

        let viewModel = CalendarPopoverViewModel(
            displayedMonth: yesterday,
            now: { currentDate.value }
        )
        // Simulate the user having "today" selected via the current-day follow flag.
        viewModel.selectCurrentDate()

        // Advance clock to simulate cross-day wake.
        currentDate.value = today

        viewModel.syncCurrentDaySelectionIfNeeded(calendar: .gregorianMondayFirst)

        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(
            Calendar.gregorianMondayFirst.isDate(viewModel.selectedDate!, inSameDayAs: today),
            "selectedDate should advance to the new today after cross-day wake"
        )
        XCTAssertTrue(
            Calendar.gregorianMondayFirst.isDate(viewModel.displayedMonth, equalTo: today, toGranularity: .month),
            "displayedMonth should reflect the new today's month"
        )
    }

    /// A user-chosen historical date (not following current day) must NOT be
    /// overwritten when the day changes.
    func testSyncAfterCrossDayWakeKeepsManuallySelectedHistoricalDate() {
        let historicalDate = makeDate(year: 2030, month: 6, day: 10)
        let yesterday      = makeDate(year: 2030, month: 6, day: 15)
        let today          = makeDate(year: 2030, month: 6, day: 16)
        let currentDate    = MutableBox(yesterday)

        let viewModel = CalendarPopoverViewModel(
            displayedMonth: yesterday,
            now: { currentDate.value }
        )
        // User manually tapped a historical date — no follow flag.
        viewModel.selectDate(historicalDate)

        currentDate.value = today
        viewModel.syncCurrentDaySelectionIfNeeded(calendar: .gregorianMondayFirst)

        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(
            Calendar.gregorianMondayFirst.isDate(viewModel.selectedDate!, inSameDayAs: historicalDate),
            "Manually selected historical date must not be overwritten on day change"
        )
    }

    /// When selectedDate is nil, syncCurrentDaySelectionIfNeeded must pick today.
    func testSyncWithNoSelectionPicksToday() {
        let today = makeDate(year: 2030, month: 6, day: 16)
        let currentDate = MutableBox(today)

        let viewModel = CalendarPopoverViewModel(
            displayedMonth: makeDate(year: 2030, month: 5, day: 1),
            now: { currentDate.value }
        )
        // No date selected yet.
        XCTAssertNil(viewModel.selectedDate)

        viewModel.syncCurrentDaySelectionIfNeeded(calendar: .gregorianMondayFirst)

        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(
            Calendar.gregorianMondayFirst.isDate(viewModel.selectedDate!, inSameDayAs: today),
            "selectedDate must be set to today when previously nil"
        )
        XCTAssertTrue(
            Calendar.gregorianMondayFirst.isDate(viewModel.displayedMonth, equalTo: today, toGranularity: .month),
            "displayedMonth must reflect today's month when no prior selection"
        )
    }

    /// Cross-month day change: June 30 → July 1.
    /// selectedDate and displayedMonth must both move to July.
    func testSyncAfterCrossDayWakeAcrossMonthBoundary() {
        let lastDayOfJune  = makeDate(year: 2030, month: 6, day: 30)
        let firstDayOfJuly = makeDate(year: 2030, month: 7, day: 1)
        let currentDate    = MutableBox(lastDayOfJune)

        let viewModel = CalendarPopoverViewModel(
            displayedMonth: lastDayOfJune,
            now: { currentDate.value }
        )
        viewModel.selectCurrentDate()

        currentDate.value = firstDayOfJuly
        viewModel.syncCurrentDaySelectionIfNeeded(calendar: .gregorianMondayFirst)

        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertTrue(
            Calendar.gregorianMondayFirst.isDate(viewModel.selectedDate!, inSameDayAs: firstDayOfJuly),
            "selectedDate must cross to July 1 on month-boundary day change"
        )
        XCTAssertEqual(
            Calendar.gregorianMondayFirst.component(.month, from: viewModel.displayedMonth),
            7,
            "displayedMonth must advance to July after cross-month day change"
        )
    }
}

// MARK: - Helpers

private final class MutableBox<Value> {
    var value: Value
    init(_ value: Value) { self.value = value }
}
