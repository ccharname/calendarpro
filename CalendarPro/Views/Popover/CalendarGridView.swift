import SwiftUI

struct CalendarGridView: View {
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let highlightWeekends: Bool
    let weekendIndices: Set<Int>
    let showDayEventDots: Bool
    let onSelectDate: (Date) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(weekdayHeaderColor(isWeekend: weekendIndices.contains(index)))
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<6, id: \.self) { rowIndex in
                GridRow {
                    ForEach(0..<7, id: \.self) { colIndex in
                        let dayIndex = rowIndex * 7 + colIndex
                        if dayIndex < monthDays.count {
                            CalendarDayCellView(
                                day: monthDays[dayIndex],
                                highlightWeekends: highlightWeekends,
                                showDayEventDots: showDayEventDots
                            )
                            .onTapGesture { onSelectDate(monthDays[dayIndex].date) }
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func weekdayHeaderColor(isWeekend: Bool) -> Color {
        guard highlightWeekends && isWeekend else { return .secondary }
        return colorScheme == .dark
            ? Color(red: 0.92, green: 0.45, blue: 0.45)
            : Color(red: 0.85, green: 0.35, blue: 0.35)
    }

}

// MARK: - MeeGo Day Cell

// cornerRadius: 21% × min cell height (34pt) ≈ 7pt (squircle token)
private let meegoCellCornerRadius: CGFloat = 7

private struct CalendarDayCellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    let day: CalendarDay
    let highlightWeekends: Bool
    let showDayEventDots: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background with MeeGo gradient
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .fill(cellGradient)
                // Outer glow ring — only on highlight states
                .shadow(
                    color: glowColor,
                    radius: isHighlighted ? 6 : 0,
                    x: 0,
                    y: 0
                )

            // Inner highlight stroke (1px top white stroke)
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.08 : 0.18),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )

            // Outer border (hover/selection state) with fade animation
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .strokeBorder(cellBorderColor, lineWidth: cellBorderWidth)
                .animation(.easeInOut(duration: 0.12), value: isHovered)

            // Content column
            VStack(spacing: 2) {
                Text(day.solarText)
                    .font(.system(size: 13, weight: day.isToday ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(solarTextColor)

                let subtitleText: String? = {
                    if let badge = day.badges.first, badge.kind == .workingAdjustmentDay {
                        return day.lunarText
                    }
                    return day.badges.first?.text ?? day.lunarText
                }()
                Text(subtitleText ?? "")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Day event dots row (MeeGo lucky-toolkit style)
                if showDayEventDots, let count = day.eventCount, count > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<min(count, 3), id: \.self) { _ in
                            Circle()
                                .fill(Color.secondary.opacity(0.55))
                                .frame(width: 2, height: 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)

            // LED indicator dot — top-trailing, 1pt outset
            if let ledColor = ledIndicatorColor {
                Circle()
                    .fill(ledColor)
                    .frame(width: 4, height: 4)
                    .offset(x: 1, y: -1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous))
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onLongPressGesture(minimumDuration: 0.001, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(dayIdentifier)
    }

    // MARK: - MeeGo Gradient Background

    /// Compute the base fill color for the current cell state (today / selected / holiday / normal).
    private var cellBaseColor: Color {
        if day.isToday {
            // Today: yellow tile per lucky-toolkit token
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.843, blue: 0.369)  // #FFD75E
                : Color(red: 1.0, green: 0.812, blue: 0.251)  // #FFCF40
        }

        if day.isSelected {
            // Selected: indigo/violet tile
            return colorScheme == .dark
                ? Color(red: 0.549, green: 0.627, blue: 1.0).opacity(0.30)   // rgba(140,160,255,0.30)
                : Color(red: 0.471, green: 0.549, blue: 1.0).opacity(0.32)   // rgba(120,140,255,0.32)
        }

        return semanticBaseColor ?? .clear
    }

    /// LinearGradient with 5% luminosity drop top→bottom (reversed in dark mode).
    private var cellGradient: LinearGradient {
        let base = cellBaseColor
        if colorScheme == .dark {
            // Dark: bottom brighter (+5% raise)
            return LinearGradient(
                colors: [base, base.luminanceShift(+0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            // Light: top→bottom 5% drop
            return LinearGradient(
                colors: [base, base.luminanceShift(-0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - LED Indicator Dot

    /// Returns the LED dot color based on cell state priority:
    /// 1. Today's yellow tile → white dot
    /// 2. publicHoliday / statutoryHoliday → red dot
    /// 3. workingAdjustmentDay → blue dot
    /// 4. solarTerm in lunarText → orange dot
    private var ledIndicatorColor: Color? {
        if day.isToday {
            // White dot on today's yellow tile
            return .white
        }

        if let badge = day.badges.first {
            switch badge.kind {
            case .publicHoliday, .statutoryHoliday:
                return colorScheme == .dark
                    ? Color(red: 0.86, green: 0.25, blue: 0.30)
                    : Color.red.opacity(0.88)
            case .workingAdjustmentDay:
                guard LocaleFeatureAvailability.showWorkingAdjustmentDay else { return nil }
                return colorScheme == .dark
                    ? Color(red: 0.17, green: 0.50, blue: 0.94)
                    : Color.blue.opacity(0.88)
            case .festival:
                break
            }
        }

        // Solar term → orange LED
        if day.lunarTextSemantic == .solarTerm {
            return .orange
        }

        return nil
    }

    // MARK: - Highlight States

    private var isHighlighted: Bool {
        day.isToday || day.isSelected || isHovered
    }

    // MARK: - Border

    private var cellBorderColor: Color {
        if day.isToday {
            return colorScheme == .dark
                ? Color(red: 0.9, green: 0.75, blue: 0.25).opacity(0.5)
                : Color(red: 0.85, green: 0.65, blue: 0.15).opacity(0.4)
        }

        if day.isSelected || isHovered {
            return selectionBorderColor
        }

        return semanticStyle?.border ?? .clear
    }

    private var cellBorderWidth: CGFloat {
        if day.isSelected || day.isToday || isHovered {
            return 1
        }
        return semanticStyle == nil ? 0 : 1
    }

    private var selectionBorderColor: Color {
        colorScheme == .dark
            ? Color(red: 0.9, green: 0.75, blue: 0.25).opacity(0.72)
            : Color(red: 0.9, green: 0.67, blue: 0.12).opacity(0.72)
    }

    // MARK: - Glow

    private var glowColor: Color {
        if day.isToday {
            return (colorScheme == .dark
                ? Color(red: 1.0, green: 0.843, blue: 0.369)
                : Color(red: 1.0, green: 0.812, blue: 0.251)).opacity(0.45)
        }
        if day.isSelected {
            return Color(red: 0.471, green: 0.549, blue: 1.0).opacity(0.35)
        }
        if isHovered {
            return selectionBorderColor.opacity(0.4)
        }
        return .clear
    }

    // MARK: - Text Colors

    private var dayIdentifier: String {
        "calendar-day-\(day.solarDateKey)"
    }

    private var solarTextColor: Color {
        // Weekend highlighting — token: #E04F5F light / #FF6B7A dark
        if highlightWeekends && day.isWeekend && day.isInDisplayedMonth {
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.42, blue: 0.48)   // #FF6B7A
                : Color(red: 0.878, green: 0.31, blue: 0.373) // #E04F5F
        }

        if day.isInDisplayedMonth {
            // Adjacent-month: 32% opacity
            return .primary
        }

        if highlightWeekends && day.isWeekend {
            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.42, blue: 0.48).opacity(0.32)
                : Color(red: 0.878, green: 0.31, blue: 0.373).opacity(0.32)
        }

        // Adjacent-month: 32% opacity; Future fallback: 55% opacity
        if semanticStyle != nil {
            return Color.primary.opacity(colorScheme == .dark ? 0.55 : 0.32)
        }

        return .secondary.opacity(0.32)
    }

    private var subtitleColor: Color {
        if let semanticStyle {
            return day.isInDisplayedMonth
                ? semanticStyle.subtitle
                : semanticStyle.subtitle.opacity(colorScheme == .dark ? 0.82 : 0.68)
        }

        if day.lunarTextSemantic == .solarTerm {
            if day.isInDisplayedMonth {
                return colorScheme == .dark
                    ? Color(red: 1.0, green: 0.50, blue: 0.50)
                    : Color.red.opacity(0.82)
            }

            return colorScheme == .dark
                ? Color(red: 1.0, green: 0.50, blue: 0.50).opacity(0.72)
                : Color.red.opacity(0.58)
        }

        guard day.isInDisplayedMonth else {
            return .secondary.opacity(0.45)
        }

        guard let badge = day.badges.first else {
            return .secondary
        }

        switch badge.kind {
        case .festival:
            return .orange
        case .publicHoliday, .statutoryHoliday:
            return .red.opacity(0.8)
        case .workingAdjustmentDay:
            return .blue.opacity(0.8)
        }
    }

    // MARK: - Semantic Style

    /// Base fill color from holiday/workday semantic (no gradient applied yet).
    private var semanticBaseColor: Color? {
        guard let badge = day.badges.first else { return nil }

        switch badge.kind {
        case .publicHoliday, .statutoryHoliday:
            return colorScheme == .dark
                ? Color(red: 0.26, green: 0.09, blue: 0.11).opacity(0.72)
                : Color.red.opacity(0.08)
        case .workingAdjustmentDay:
            return colorScheme == .dark
                ? Color(red: 0.07, green: 0.18, blue: 0.31).opacity(0.78)
                : Color.blue.opacity(0.08)
        case .festival:
            return nil
        }
    }

    private var semanticStyle: SemanticStyle? {
        guard let badge = day.badges.first else { return nil }

        switch badge.kind {
        case .publicHoliday, .statutoryHoliday:
            if colorScheme == .dark {
                return SemanticStyle(
                    border: Color(red: 0.98, green: 0.43, blue: 0.43).opacity(0.28),
                    subtitle: Color(red: 1.0, green: 0.73, blue: 0.73)
                )
            }
            return SemanticStyle(
                border: Color.red.opacity(0.12),
                subtitle: Color.red.opacity(0.82)
            )
        case .workingAdjustmentDay:
            if colorScheme == .dark {
                return SemanticStyle(
                    border: Color(red: 0.45, green: 0.72, blue: 1.0).opacity(0.28),
                    subtitle: Color(red: 0.70, green: 0.85, blue: 1.0)
                )
            }
            return SemanticStyle(
                border: Color.blue.opacity(0.12),
                subtitle: Color.blue.opacity(0.82)
            )
        case .festival:
            return nil
        }
    }
}

// MARK: - Supporting Types

private struct SemanticStyle {
    let border: Color
    let subtitle: Color
}

// MARK: - Color+LuminanceShift (macOS, HSB via NSColor)

private extension Color {
    /// Shift the HSB brightness of this color by `delta` (positive = brighter, negative = darker).
    /// Uses NSColor for reliable HSB conversion on macOS 14+.
    func luminanceShift(_ delta: Double) -> Color {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let newBrightness = max(0, min(1, b + delta))
        return Color(nsColor: NSColor(hue: h, saturation: s, brightness: newBrightness, alpha: a))
    }
}
