import Foundation

struct LunarService {
    private var chineseCalendar: Calendar
    private let festivalResolver: TraditionalFestivalResolver
    private let solarTermResolver: SolarTermResolver

    init(
        calendar: Calendar = Calendar(identifier: .chinese),
        festivalResolver: TraditionalFestivalResolver = TraditionalFestivalResolver(),
        solarTermResolver: SolarTermResolver = SolarTermResolver()
    ) {
        var calendar = calendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        chineseCalendar = calendar
        self.festivalResolver = festivalResolver
        self.solarTermResolver = solarTermResolver
    }

    /// (yyyyMMdd, timezone-identifier) → LunarDateDescriptor.
    /// Lunar conversion is pure: same gregorian-day-in-timezone always produces
    /// the same chinese-calendar tuple. Caching avoids 42 repeats per grid build.
    nonisolated(unsafe) private static var cache: [String: LunarDateDescriptor] = [:]
    private static let cacheLock = NSLock()

    func describe(date: Date, timeZone: TimeZone = .autoupdatingCurrent) -> LunarDateDescriptor {
        let key = Self.cacheKey(for: date, timeZone: timeZone)

        Self.cacheLock.lock()
        if let cached = Self.cache[key] {
            Self.cacheLock.unlock()
            return cached
        }
        Self.cacheLock.unlock()

        let components = chineseCalendar.dateComponents(in: timeZone, from: date)
        let year = components.year ?? 1
        let month = components.month ?? 1
        let day = components.day ?? 1
        let isLeapMonth = components.isLeapMonth ?? false

        let yearText = Self.yearText(for: year)
        let monthText = Self.monthText(for: month, isLeapMonth: isLeapMonth)
        let dayText = Self.dayText(for: day)

        let descriptor = LunarDateDescriptor(
            year: year,
            month: month,
            day: day,
            isLeapMonth: isLeapMonth,
            yearText: yearText,
            monthText: monthText,
            dayText: dayText,
            festivalName: festivalResolver.festivalName(month: month, day: day, isLeapMonth: isLeapMonth),
            solarTermName: solarTermResolver.solarTermName(for: date, timeZone: timeZone)
        )

        Self.cacheLock.lock()
        Self.cache[key] = descriptor
        Self.cacheLock.unlock()

        return descriptor
    }

    private static func cacheKey(for date: Date, timeZone: TimeZone) -> String {
        // Day-since-epoch in the target timezone, no Calendar work needed.
        // Two Date values that fall on the same wall-clock day produce the same key.
        let offset = Double(timeZone.secondsFromGMT(for: date))
        let dayInTZ = Int(floor((date.timeIntervalSince1970 + offset) / 86_400))
        return "\(dayInTZ)|\(timeZone.identifier)"
    }

    private static func yearText(for year: Int) -> String {
        let gan = ["甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸"]
        let zhi = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
        
        let ganIndex = (year - 4) % 10
        let zhiIndex = (year - 4) % 12
        
        return gan[max(0, min(9, ganIndex))] + zhi[max(0, min(11, zhiIndex))] + "年"
    }

    private static func monthText(for month: Int, isLeapMonth: Bool) -> String {
        let monthNames = [
            "正月", "二月", "三月", "四月", "五月", "六月",
            "七月", "八月", "九月", "十月", "冬月", "腊月"
        ]

        let resolvedMonth = monthNames[max(0, min(monthNames.count - 1, month - 1))]
        return isLeapMonth ? "闰\(resolvedMonth)" : resolvedMonth
    }

    private static func dayText(for day: Int) -> String {
        let dayNames = [
            "初一", "初二", "初三", "初四", "初五",
            "初六", "初七", "初八", "初九", "初十",
            "十一", "十二", "十三", "十四", "十五",
            "十六", "十七", "十八", "十九", "二十",
            "廿一", "廿二", "廿三", "廿四", "廿五",
            "廿六", "廿七", "廿八", "廿九", "三十"
        ]

        return dayNames[max(0, min(dayNames.count - 1, day - 1))]
    }
}
