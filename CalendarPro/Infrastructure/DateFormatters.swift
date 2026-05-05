import Foundation

// Central pool of DateFormatter instances.
// Thread-safe via NSLock for locale-keyed formatters.
// Locale-independent (POSIX/GMT) formatters are plain static lets — safe to call from any thread.
enum DateFormatters {

    // MARK: - Locale-independent (stable) formatters

    /// "yyyy-MM-dd" gregorian, en_US_POSIX, GMT — accessibility identifiers and stable date keys.
    static let gregorianISODay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "HH:mm" — 24-hour time for tooltip/upcoming-event display (locale-agnostic).
    static let hourMinute24: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    /// "yyyy-MM-dd" gregorian POSIX, autoupdatingCurrent timezone — weather daily response parsing.
    static let weatherISODay: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// "yyyy-MM-dd'T'HH:mm" gregorian POSIX, autoupdatingCurrent timezone — weather hourly response parsing.
    static let weatherISOMinute: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .autoupdatingCurrent
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return f
    }()

    // MARK: - Locale-aware formatter cache

    // nonisolated(unsafe): access is serialized by cacheLock below.
    private nonisolated(unsafe) static var localeCache: [String: DateFormatter] = [:]
    private static let cacheLock = NSLock()

    // MARK: - Named locale-aware factories

    /// Short standalone weekday symbols provider.
    /// Callers read `f.shortStandaloneWeekdaySymbols` directly.
    static func weekdaySymbolProvider(for locale: Locale) -> DateFormatter {
        formatter(key: "weekdaySymbolProvider", locale: locale) { _ in }
    }

    /// "MMMM yyyy" (or locale-equivalent) for the month-year header.
    static func monthYearTitle(for locale: Locale) -> DateFormatter {
        formatter(key: "monthYearTitle", locale: locale) { f in
            f.setLocalizedDateFormatFromTemplate("yMMMM")
        }
    }

    /// Full month name "MMMM" — used in month-header and month-picker.
    static func monthFull(for locale: Locale) -> DateFormatter {
        formatter(key: "monthFull", locale: locale) { f in
            f.setLocalizedDateFormatFromTemplate("MMMM")
        }
    }

    /// Year-only formatter — used in month-picker year display and month-header year text.
    static func yearOnly(for locale: Locale) -> DateFormatter {
        formatter(key: "yearOnly", locale: locale) { f in
            f.setLocalizedDateFormatFromTemplate("y")
        }
    }

    /// "MMMdEEEE" selected-date header — used in CalendarPopoverView, EventDetailWindowView,
    /// ReminderDetailWindowView (due date), and CalendarItemComposerView.
    static func selectedDateHeader(for locale: Locale) -> DateFormatter {
        formatter(key: "selectedDateHeader", locale: locale) { f in
            f.setLocalizedDateFormatFromTemplate("MMMdEEEE")
        }
    }

    /// Short time formatter — dateStyle none, timeStyle short.
    /// Used in EventCardView, EventListView, ReminderDetailWindowView (due time).
    static func shortTime(for locale: Locale) -> DateFormatter {
        formatter(key: "shortTime", locale: locale) { f in
            f.dateStyle = .none
            f.timeStyle = .short
        }
    }

    /// Short date + short time — used in ReminderDetailWindowView alarm absolute dates.
    static func shortDateTime(for locale: Locale) -> DateFormatter {
        formatter(key: "shortDateTime", locale: locale) { f in
            f.dateStyle = .short
            f.timeStyle = .short
        }
    }

    /// All month symbols provider — callers read `f.monthSymbols`.
    static func monthSymbolsProvider(for locale: Locale) -> DateFormatter {
        formatter(key: "monthSymbolsProvider", locale: locale) { _ in }
    }

    /// Compact forecast date "M/d" — used in WeatherStripView.
    static func compactMonthDay(for locale: Locale) -> DateFormatter {
        formatter(key: "compactMonthDay", locale: locale) { f in
            f.calendar = Calendar(identifier: .gregorian)
            f.dateFormat = "M/d"
        }
    }

    /// "MMMd" range text — used in VacationOpportunityCardView.
    static func shortMonthDay(for locale: Locale) -> DateFormatter {
        formatter(key: "shortMonthDay", locale: locale) { f in
            f.setLocalizedDateFormatFromTemplate("MMMd")
        }
    }

    // MARK: - Private helper

    private static func formatter(
        key: String,
        locale: Locale,
        configure: (DateFormatter) -> Void
    ) -> DateFormatter {
        let cacheKey = "\(key)|\(locale.identifier)"
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let cached = localeCache[cacheKey] {
            return cached
        }
        let f = DateFormatter()
        f.locale = locale
        configure(f)
        localeCache[cacheKey] = f
        return f
    }
}
