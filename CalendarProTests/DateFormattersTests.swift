import XCTest
@testable import CalendarPro

final class DateFormattersTests: XCTestCase {

    // MARK: - Fixed reference date (2026-05-05 UTC)

    private var referenceDate: Date {
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = 2026
        comps.month = 5
        comps.day = 5
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return comps.date!
    }

    // MARK: - 1. Same locale + same factory → same instance (identity)

    func testSameLocaleReturnsSameInstance() {
        let locale = Locale(identifier: "en_US")
        let a = DateFormatters.selectedDateHeader(for: locale)
        let b = DateFormatters.selectedDateHeader(for: locale)
        XCTAssertTrue(a === b, "Same key should return the same DateFormatter instance")
    }

    func testSameLocaleMonthYearReturnsSameInstance() {
        let locale = Locale(identifier: "zh-Hans")
        let a = DateFormatters.monthYearTitle(for: locale)
        let b = DateFormatters.monthYearTitle(for: locale)
        XCTAssertTrue(a === b)
    }

    // MARK: - 2. Different locale → different instance

    func testDifferentLocaleReturnsDifferentInstance() {
        let en = DateFormatters.selectedDateHeader(for: Locale(identifier: "en_US"))
        let zh = DateFormatters.selectedDateHeader(for: Locale(identifier: "zh-Hans"))
        XCTAssertFalse(en === zh, "Different locales must produce different instances")
    }

    func testDifferentLocaleShortTimeReturnsDifferentInstance() {
        let en = DateFormatters.shortTime(for: Locale(identifier: "en"))
        let zh = DateFormatters.shortTime(for: Locale(identifier: "zh-Hans"))
        XCTAssertFalse(en === zh)
    }

    // MARK: - 3. Locale-independent formatters produce consistent output

    func testGregorianISODayFormat() {
        let result = DateFormatters.gregorianISODay.string(from: referenceDate)
        XCTAssertEqual(result, "2026-05-05")
    }

    func testGregorianISODayParseRoundTrip() {
        let string = "2025-01-01"
        let parsed = DateFormatters.gregorianISODay.date(from: string)
        XCTAssertNotNil(parsed)
        let roundTripped = DateFormatters.gregorianISODay.string(from: parsed!)
        XCTAssertEqual(roundTripped, string)
    }

    func testHourMinute24Format() {
        // hourMinute24 uses system timezone; verify format shape (HH:mm) rather than exact value.
        var comps = DateComponents()
        comps.calendar = Calendar.current
        comps.year = 2026
        comps.month = 5
        comps.day = 5
        comps.hour = 14
        comps.minute = 30
        let date = comps.date!
        let result = DateFormatters.hourMinute24.string(from: date)
        XCTAssertEqual(result, "14:30", "hourMinute24 should produce 24-hour HH:mm")
    }

    // MARK: - 4. Concurrent access doesn't crash
    // DispatchQueue.concurrentPerform is synchronous — all iterations complete before the call returns.

    func testConcurrentAccessDoesNotCrash() {
        let locale = Locale(identifier: "en_US")
        // concurrentPerform blocks until all 100 iterations finish — no async needed.
        DispatchQueue.concurrentPerform(iterations: 100) { _ in
            _ = DateFormatters.selectedDateHeader(for: locale)
            _ = DateFormatters.weekdaySymbolProvider(for: locale)
            _ = DateFormatters.monthFull(for: locale)
            _ = DateFormatters.shortTime(for: locale)
            _ = DateFormatters.gregorianISODay.string(from: Date())
        }
        // If we reach here without crashing or deadlocking, the test passes.
    }

    func testConcurrentAccessMultipleLocalesDoesNotCrash() {
        let locales = ["en_US", "zh-Hans", "ja_JP", "fr_FR", "de_DE"].map { Locale(identifier: $0) }
        DispatchQueue.concurrentPerform(iterations: 100) { i in
            let locale = locales[i % locales.count]
            _ = DateFormatters.selectedDateHeader(for: locale)
            _ = DateFormatters.monthFull(for: locale)
        }
    }

    // MARK: - 5. selectedDateHeader returns Chinese localized format for zh_CN

    func testSelectedDateHeaderChineseLocale() {
        let zhLocale = Locale(identifier: "zh_CN")
        let formatter = DateFormatters.selectedDateHeader(for: zhLocale)
        let result = formatter.string(from: referenceDate)
        // Chinese locale should produce a string that contains Chinese characters or at least digits
        XCTAssertFalse(result.isEmpty, "Chinese formatted date should not be empty")
        // The formatted result should contain the day number "5"
        XCTAssertTrue(result.contains("5"), "Date should contain the day digit 5: \(result)")
    }

    // MARK: - 6. solarDateKey computation

    func testSolarDateKey() {
        let key = CalendarDay.makeSolarDateKey(from: referenceDate)
        XCTAssertEqual(key, 20260505)
    }

    func testSolarDateKeyEndOfYear() {
        var comps = DateComponents()
        comps.calendar = Calendar(identifier: .gregorian)
        comps.timeZone = TimeZone(secondsFromGMT: 0)
        comps.year = 2025
        comps.month = 12
        comps.day = 31
        let date = comps.date!
        XCTAssertEqual(CalendarDay.makeSolarDateKey(from: date), 20251231)
    }
}
