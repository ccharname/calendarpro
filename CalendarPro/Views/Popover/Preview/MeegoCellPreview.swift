#if DEBUG
import SwiftUI

// MARK: - Preview helpers

private func makeDay(
    solarText: String,
    isToday: Bool = false,
    isSelected: Bool = false,
    isInDisplayedMonth: Bool = true,
    isWeekend: Bool = false,
    lunarText: String? = "初一",
    lunarTextSemantic: LunarTextSemantic = .regular,
    badges: [DayBadge] = []
) -> CalendarDay {
    let date = Date()
    return CalendarDay(
        date: date,
        solarDateKey: CalendarDay.makeSolarDateKey(from: date),
        isInDisplayedMonth: isInDisplayedMonth,
        isToday: isToday,
        isSelected: isSelected,
        isWeekend: isWeekend,
        solarText: solarText,
        lunarText: lunarText,
        lunarTextSemantic: lunarTextSemantic,
        badges: badges,
        eventCount: nil
    )
}

private let normalDay = makeDay(solarText: "12", lunarText: "十二")

private let todayDay = makeDay(solarText: "5", isToday: true, lunarText: "初七")

private let selectedDay = makeDay(solarText: "18", isSelected: true, lunarText: "十八")

private let holidayDay = makeDay(
    solarText: "1",
    lunarText: "元旦",
    badges: [DayBadge(kind: .publicHoliday, text: "元旦", priority: 1)]
)

// MARK: - MeegoCellPreviewProvider

struct MeegoCellPreviewProvider: PreviewProvider {
    static var previews: some View {
        Group {
            // Normal day — light
            previewCell(normalDay, label: "Normal / Light")
                .preferredColorScheme(.light)

            // Normal day — dark
            previewCell(normalDay, label: "Normal / Dark")
                .preferredColorScheme(.dark)

            // Today — light
            previewCell(todayDay, label: "Today / Light")
                .preferredColorScheme(.light)

            // Today — dark
            previewCell(todayDay, label: "Today / Dark")
                .preferredColorScheme(.dark)

            // Selected — light
            previewCell(selectedDay, label: "Selected / Light")
                .preferredColorScheme(.light)

            // Selected — dark
            previewCell(selectedDay, label: "Selected / Dark")
                .preferredColorScheme(.dark)

            // Holiday (OFF LED) — light
            previewCell(holidayDay, label: "Holiday OFF / Light")
                .preferredColorScheme(.light)

            // Holiday (OFF LED) — dark
            previewCell(holidayDay, label: "Holiday OFF / Dark")
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private static func previewCell(_ day: CalendarDay, label: String) -> some View {
        VStack(spacing: 4) {
            CalendarGridView(
                weekdaySymbols: ["日", "一", "二", "三", "四", "五", "六"],
                monthDays: [day],
                highlightWeekends: true,
                weekendIndices: [0, 6],
                showDayEventDots: false,
                onSelectDate: { _ in }
            )
            .frame(width: 60, height: 60)
            .padding(8)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .previewDisplayName(label)
        .previewLayout(.sizeThatFits)
    }
}
#endif
