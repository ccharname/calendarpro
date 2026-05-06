import SwiftUI

struct CalendarGridView: View {
    let weekdaySymbols: [String]
    let monthDays: [CalendarDay]
    let highlightWeekends: Bool
    let weekendIndices: Set<Int>
    let onSelectDate: (Date) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var selectionNamespace

    var body: some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            GridRow {
                // Week-number gutter header — empty spacer, fixed width
                Color.clear.frame(width: weekNumberGutterWidth)

                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(weekdayHeaderColor(isWeekend: weekendIndices.contains(index)))
                        .frame(maxWidth: .infinity)
                }
            }

            ForEach(0..<rowCount, id: \.self) { rowIndex in
                GridRow {
                    Text(weekNumberText(for: rowIndex))
                        .font(.system(size: 10, weight: .regular, design: .rounded).monospacedDigit())
                        .foregroundStyle(Color.secondary.opacity(0.55))
                        .frame(width: weekNumberGutterWidth, alignment: .top)
                        .padding(.top, 8)

                    ForEach(0..<7, id: \.self) { colIndex in
                        let dayIndex = rowIndex * 7 + colIndex
                        if dayIndex < monthDays.count {
                            CalendarDayCellView(
                                day: monthDays[dayIndex],
                                highlightWeekends: highlightWeekends,
                                selectionNamespace: selectionNamespace
                            )
                            // Use simultaneousGesture so the tap fires alongside the cell's
                            // onLongPressGesture (which drives the press-animation). Without
                            // this, the long press gesture (minimumDuration 0.001 s) completes
                            // first and causes SwiftUI to cancel the parent-level tap, meaning
                            // date selection silently never fires.
                            .simultaneousGesture(TapGesture().onEnded { onSelectDate(monthDays[dayIndex].date) })
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Week numbers

    private static let isoCalendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }()

    private let weekNumberGutterWidth: CGFloat = 20

    /// ISO 8601 week number for the row. Use middle-of-week day (index +3) so the
    /// number is stable regardless of weekStart preference.
    private func weekNumberText(for rowIndex: Int) -> String {
        let referenceIndex = rowIndex * 7 + 3
        guard referenceIndex < monthDays.count else { return "" }
        let week = Self.isoCalendar.component(.weekOfYear, from: monthDays[referenceIndex].date)
        return String(week)
    }

    private func weekdayHeaderColor(isWeekend: Bool) -> Color {
        guard highlightWeekends && isWeekend else { return .secondary }
        return colorScheme == .dark
            ? Color(red: 0.92, green: 0.45, blue: 0.45)
            : Color(red: 0.85, green: 0.35, blue: 0.35)
    }

    /// Number of day rows (5 or 6) derived from monthDays count.
    private var rowCount: Int {
        max(1, (monthDays.count + 6) / 7)
    }

}

// MARK: - MeeGo Day Cell

// MeeGo icon-tile squircle (continuous curvature).
// N9 / Harmattan 80×80 spec: 22–24pt corner = 27–30% × short side.
// We use 35% (12pt × 34pt short side) — N9 baseline + slight 玩具感 amplification.
private let meegoCellCornerRadius: CGFloat = 12

private struct CalendarDayCellView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovered = false
    @State private var isPressed = false

    let day: CalendarDay
    let highlightWeekends: Bool
    let selectionNamespace: Namespace.ID

    var body: some View {
        ZStack {
            // 1. Tile body — gradient fill simulating top-down luminosity drop
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .fill(cellGradient)

            // 2. Glossy top-half highlight — half-height white fade overlay (MeeGo "icon gloss")
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(glossOpacity),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.55)
                    )
                )
                .allowsHitTesting(false)

            // 3. Inner top-edge highlight (1px crisp white rim, fades down)
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.22 : 0.45),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: UnitPoint(x: 0.5, y: 0.4)
                    ),
                    lineWidth: 1
                )

            // 4. Outer border (hover/selection state) with fade animation
            RoundedRectangle(cornerRadius: meegoCellCornerRadius, style: .continuous)
                .strokeBorder(cellBorderColor, lineWidth: cellBorderWidth)
                .animation(.snappy(duration: 0.15), value: isHovered)

            // 5. Content (day number + subtitle + optional event dots)
            VStack(spacing: 1) {
                Text(day.solarText)
                    .font(.system(size: 16, weight: day.isToday ? .semibold : .medium, design: .rounded))
                    .foregroundStyle(solarTextColor)

                let subtitleText: String? = {
                    if let badge = day.badges.first, badge.kind == .workingAdjustmentDay {
                        return day.lunarText
                    }
                    return day.badges.first?.text ?? day.lunarText
                }()
                Text(subtitleText ?? "")
                    .font(.system(size: 8, weight: .regular, design: .rounded))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
            .padding(.vertical, 2)
            .padding(.horizontal, 4)

            // 6. Top-trailing badge pill — only one at a time to avoid crowding.
            // Priority: holiday/workday badge wins (yellow tile already screams "today").
            HStack(spacing: 2) {
                if let indicator = badgeIndicator {
                    badgeView(indicator)
                } else if day.isToday {
                    todayBadgeView
                }
            }
            .padding(.top, -4)
            .padding(.trailing, -4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .allowsHitTesting(false)

            // 7. Geometry anchor for matchedGeometryEffect — carries the selection
            // frame between cells when selectedDate changes, enabling a physical
            // slide instead of cross-fade. Color.clear so no visual is double-drawn.
            if day.isSelected {
                Color.clear
                    .matchedGeometryEffect(id: "selectedDay", in: selectionNamespace)
                    .allowsHitTesting(false)
            }
        }
        // drawingGroup flattens layers 1–7 into a single GPU-rasterized layer per
        // cell, reducing layer commit cost during scroll / hover / selection animation.
        // Placed BEFORE shadow/scale/gestures so those remain dynamic.
        .drawingGroup()
        // Outer drop shadow — gives the tile a "floating玩具" feel
        .shadow(
            color: tileShadowColor,
            radius: tileShadowRadius,
            x: 0,
            y: tileShadowYOffset
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.snappy(duration: 0.15), value: isPressed)
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

    // MARK: - Original-style badge pills (restored)

    private func badgeView(_ indicator: BadgeIndicator) -> some View {
        Text(indicator.text)
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(indicator.fill)
            }
            .overlay {
                Capsule().strokeBorder(indicator.fill.opacity(colorScheme == .dark ? 0.55 : 0.2), lineWidth: 0.5)
            }
            .shadow(color: indicator.shadow, radius: colorScheme == .dark ? 6 : 0, y: 1)
    }

    private var todayBadgeView: some View {
        Text(L("Today"))
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.96))
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(
                    colorScheme == .dark
                        ? Color(red: 0.9, green: 0.75, blue: 0.25)
                        : Color(red: 0.95, green: 0.6, blue: 0.1)
                )
            }
            .overlay {
                Capsule().strokeBorder(Color.orange.opacity(colorScheme == .dark ? 0.55 : 0.2), lineWidth: 0.5)
            }
            .shadow(color: Color.orange.opacity(colorScheme == .dark ? 0.28 : 0), radius: colorScheme == .dark ? 6 : 0, y: 1)
    }

    private var badgeIndicator: BadgeIndicator? {
        guard let badge = day.badges.first else { return nil }
        switch badge.kind {
        case .publicHoliday, .statutoryHoliday:
            return BadgeIndicator(
                text: L("OFF"),
                fill: colorScheme == .dark ? Color(red: 0.86, green: 0.25, blue: 0.30) : Color.red.opacity(0.88),
                shadow: Color.red.opacity(colorScheme == .dark ? 0.28 : 0)
            )
        case .workingAdjustmentDay:
            guard LocaleFeatureAvailability.showWorkingAdjustmentDay else { return nil }
            return BadgeIndicator(
                text: L("WRK"),
                fill: colorScheme == .dark ? Color(red: 0.17, green: 0.50, blue: 0.94) : Color.blue.opacity(0.88),
                shadow: Color.blue.opacity(colorScheme == .dark ? 0.26 : 0)
            )
        case .festival:
            return nil
        }
    }

    // MARK: - Tile Depth Tokens (玩具感)

    private var glossOpacity: Double {
        // Bigger gloss on highlighted tiles (today/selected) so they pop
        if day.isToday { return colorScheme == .dark ? 0.18 : 0.40 }
        if day.isSelected { return colorScheme == .dark ? 0.14 : 0.30 }
        if semanticStyle != nil { return colorScheme == .dark ? 0.12 : 0.22 }
        return colorScheme == .dark ? 0.06 : 0.14
    }

    private var tileShadowColor: Color {
        if isHighlighted {
            return glowColor
        }
        // Resting tiles get a faint dark drop shadow — gives "floating" feel
        return Color.black.opacity(colorScheme == .dark ? 0.45 : 0.10)
    }

    private var tileShadowRadius: CGFloat {
        if isHighlighted { return 6 }
        return semanticStyle != nil ? 2 : 1.5
    }

    private var tileShadowYOffset: CGFloat {
        isHighlighted ? 0 : 1
    }

    // MARK: - MeeGo Gradient Background

    /// Compute the base fill color for the current cell state (today / selected / holiday / normal).
    /// Even "normal" cells get a faint base so the gradient + gloss read as a 3D tile.
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
                ? Color(red: 0.549, green: 0.627, blue: 1.0).opacity(0.55)
                : Color(red: 0.471, green: 0.549, blue: 1.0).opacity(0.45)
        }

        if let semantic = semanticBaseColor {
            return semantic
        }

        // Normal in-month tile: faint neutral fill so MeeGo gradient + gloss are visible.
        // Adjacent-month tiles get a flatter, even fainter base so they recede.
        if day.isInDisplayedMonth {
            return colorScheme == .dark
                ? Color(red: 0.78, green: 0.78, blue: 0.82).opacity(0.10)
                : Color(red: 0.47, green: 0.47, blue: 0.50).opacity(0.10)
        }

        return colorScheme == .dark
            ? Color(red: 0.78, green: 0.78, blue: 0.82).opacity(0.04)
            : Color(red: 0.47, green: 0.47, blue: 0.50).opacity(0.04)
    }

    /// LinearGradient with stronger top→bottom luminosity delta (玩具感 amplification).
    /// Light mode: top brighter (+8%) → bottom darker (-8%) gives 16% spread.
    /// Dark mode: top darker (-6%) → bottom brighter (+10%) gives 16% spread (reversed gloss).
    private var cellGradient: LinearGradient {
        let base = cellBaseColor
        if colorScheme == .dark {
            return LinearGradient(
                colors: [
                    base.luminanceShift(-0.06),
                    base.luminanceShift(+0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            return LinearGradient(
                colors: [
                    base.luminanceShift(+0.08),
                    base.luminanceShift(-0.08)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
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
        // Today's yellow tile demands a dark deep-amber number for contrast,
        // regardless of weekend / holiday — must precede other branches.
        if day.isToday {
            return Color(red: 0.30, green: 0.18, blue: 0)
        }

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
        // Today's yellow tile: deep amber subtitle wins over holiday red,
        // otherwise the holiday name disappears against the yellow gradient.
        if day.isToday {
            return Color(red: 0.45, green: 0.20, blue: 0).opacity(0.92)
        }

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
                : Color.red.opacity(0.18)
        case .workingAdjustmentDay:
            return colorScheme == .dark
                ? Color(red: 0.07, green: 0.18, blue: 0.31).opacity(0.78)
                : Color.blue.opacity(0.18)
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

private struct BadgeIndicator {
    let text: String
    let fill: Color
    let shadow: Color
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
