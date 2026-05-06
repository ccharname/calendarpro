import SwiftUI
import EventKit

enum EventTimelineMarkerPosition: Equatable {
    case beforeGroup
    case withinItem(selectionIdentifier: String, progress: Double)
    case afterGroup
}

struct EventTimelineMarker: Equatable {
    let groupID: String
    let position: EventTimelineMarkerPosition
}

struct EventTimelineGroup: Identifiable {
    let id: String
    let displayTime: String
    let startMinutes: Int
    let items: [CalendarItem]
    let containsOngoingItem: Bool
    let isPast: Bool
    let isFuture: Bool
}

private struct EventTimelineItemBoundsPreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

struct EventTimelineSnapshot {
    let timedGroups: [EventTimelineGroup]
    let allDayItems: [CalendarItem]
    let untimedItems: [CalendarItem]
    let marker: EventTimelineMarker?
    let scrollTargetGroupID: String?
    let shouldAnchorBottom: Bool

    static func activeTimedItemInfo(
        items: [CalendarItem],
        selectedDate: Date?,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> (activeIndex: Int?, timedCount: Int) {
        let timedItems = items.compactMap { item -> (CalendarItem, Int)? in
            guard case .timed(let mins) = item.timelinePlacement(using: calendar) else {
                return nil
            }
            return (item, mins)
        }

        let timedCount = timedItems.count

        guard let selectedDate,
              calendar.isDate(selectedDate, inSameDayAs: now),
              timedCount > 0 else {
            return (nil, timedCount)
        }

        let currentMinutes = Self.minutes(for: now, calendar: calendar)

        for (index, pair) in timedItems.enumerated() {
            if pair.0.timelineStatus(at: now, calendar: calendar) == .ongoing {
                return (index + 1, timedCount)
            }
        }

        for (index, pair) in timedItems.enumerated() {
            if pair.1 >= currentMinutes {
                return (index + 1, timedCount)
            }
        }

        return (timedCount, timedCount)
    }

    static func make(
        items: [CalendarItem],
        selectedDate: Date?,
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> EventTimelineSnapshot {
        let timedGroups = makeTimedGroups(items: items, now: now, calendar: calendar)
        let allDayItems = items.filter(\.isAllDay)
        let untimedItems = items.filter { item in
            if item.isAllDay {
                return false
            }
            if case .timed = item.timelinePlacement(using: calendar) {
                return false
            }
            return true
        }

        guard let selectedDate,
              calendar.isDate(selectedDate, inSameDayAs: now),
              !timedGroups.isEmpty else {
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: nil,
                scrollTargetGroupID: nil,
                shouldAnchorBottom: false
            )
        }

        if let ongoingGroup = timedGroups.first(where: \.containsOngoingItem) {
            let shouldAnchorBottom = timedGroups.last?.id == ongoingGroup.id
            let markerPosition: EventTimelineMarkerPosition

            if let ongoingItem = ongoingGroup.items.first(where: { $0.timelineProgress(at: now, calendar: calendar) != nil }) {
                let progress = ongoingItem.timelineProgress(at: now, calendar: calendar) ?? 0.5
                markerPosition = .withinItem(
                    selectionIdentifier: ongoingItem.selectionIdentifier,
                    progress: progress
                )
            } else {
                markerPosition = .beforeGroup
            }

            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: EventTimelineMarker(groupID: ongoingGroup.id, position: markerPosition),
                scrollTargetGroupID: ongoingGroup.id,
                shouldAnchorBottom: shouldAnchorBottom
            )
        }

        let currentMinutes = minutes(for: now, calendar: calendar)

        if let nextGroup = timedGroups.first(where: { $0.startMinutes >= currentMinutes }) {
            let shouldAnchorBottom = timedGroups.last?.id == nextGroup.id
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: EventTimelineMarker(groupID: nextGroup.id, position: .beforeGroup),
                scrollTargetGroupID: nextGroup.id,
                shouldAnchorBottom: shouldAnchorBottom
            )
        }

        guard let lastGroup = timedGroups.last else {
            return EventTimelineSnapshot(
                timedGroups: timedGroups,
                allDayItems: allDayItems,
                untimedItems: untimedItems,
                marker: nil,
                scrollTargetGroupID: nil,
                shouldAnchorBottom: false
            )
        }

        return EventTimelineSnapshot(
            timedGroups: timedGroups,
            allDayItems: allDayItems,
            untimedItems: untimedItems,
            marker: EventTimelineMarker(groupID: lastGroup.id, position: .afterGroup),
            scrollTargetGroupID: lastGroup.id,
            shouldAnchorBottom: true
        )
    }

    private static func makeTimedGroups(items: [CalendarItem], now: Date, calendar: Calendar) -> [EventTimelineGroup] {
        var groupedItems: [Int: [CalendarItem]] = [:]
        var orderedMinutes: [Int] = []

        for item in items {
            guard case .timed(let minutes) = item.timelinePlacement(using: calendar) else {
                continue
            }

            if groupedItems[minutes] == nil {
                orderedMinutes.append(minutes)
                groupedItems[minutes] = []
            }

            groupedItems[minutes, default: []].append(item)
        }

        return orderedMinutes.sorted().compactMap { minutes in
            guard let items = groupedItems[minutes], !items.isEmpty else { return nil }

            let statuses = items.compactMap { $0.timelineStatus(at: now, calendar: calendar) }
            let containsOngoingItem = statuses.contains(.ongoing)
            let isPast = !containsOngoingItem && !statuses.isEmpty && statuses.allSatisfy { $0 == .past }
            let isFuture = !containsOngoingItem && !statuses.isEmpty && statuses.allSatisfy { $0 == .future }

            return EventTimelineGroup(
                id: Self.format(minutes: minutes),
                displayTime: Self.format(minutes: minutes),
                startMinutes: minutes,
                items: items,
                containsOngoingItem: containsOngoingItem,
                isPast: isPast,
                isFuture: isFuture
            )
        }
    }

    private static func format(minutes: Int) -> String {
        let formatter = DateFormatters.shortTime(for: AppLocalization.locale)
        var components = DateComponents()
        components.hour = minutes / 60
        components.minute = minutes % 60
        let date = Calendar(identifier: .gregorian).date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private static func minutes(for date: Date, calendar: Calendar) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }
}

// MARK: - EventListView

struct EventListView: View {
    private struct WithinItemMarkerPlacement {
        let frame: CGRect
        let y: CGFloat
    }

    // Design tokens — uniform, locked.
    private enum Metrics {
        /// Fixed width for the HH:mm time label column (right-aligned text).
        /// 42pt accommodates "HH:mm" (5 chars @ 11pt mono) plus the now-marker's
        /// 6pt horizontal capsule padding without forcing the digits to wrap.
        static let timeLabelWidth: CGFloat = 42
        /// Rail column (dot + vertical line).
        static let railWidth: CGFloat = 10
        /// Gap between the time-label column and the rail column.
        static let laneSpacing: CGFloat = 4
        /// Gap between the rail column and the card area.
        static let cardSpacing: CGFloat = 6
        /// Trailing padding inside the ScrollView so the macOS overlay scrollbar
        /// doesn't bleed onto the card squircle's right edge.
        static let scrollbarInset: CGFloat = 8
        /// Total timeline column width consumed before cards start.
        static let timelineColumnWidth: CGFloat = timeLabelWidth + laneSpacing + railWidth + cardSpacing
        /// Dot diameter on the rail aligned to card top.
        static let railDotSize: CGFloat = 6
        /// Now-marker red dot diameter (same as rail dots for visual consistency).
        static let nowDotSize: CGFloat = 6
        /// Vertical gap between cards in the same time group.
        static let cardSpacingInGroup: CGFloat = 6
        /// Vertical gap between time groups (12pt rhythm).
        static let groupSpacing: CGFloat = 12
    }

    let items: [CalendarItem]
    let isLoading: Bool
    let emptyStateText: String
    let selectedDate: Date?
    let selectedEventIdentifier: String?
    @ObservedObject var timeRefreshCoordinator: TimeRefreshCoordinator
    let onSelectEvent: (EKEvent) -> Void
    let onToggleReminder: (EKReminder) -> Void
    let onOpenReminder: (EKReminder) -> Void
    var onDeleteReminder: ((EKReminder) -> Void)?

    var body: some View {
        if isLoading {
            HStack {
                Spacer()
                ProgressView()
                    .scaleEffect(0.7)
                Spacer()
            }
            .frame(height: 60)
        } else if items.isEmpty {
            Text(emptyStateText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    timelineContent
                        .padding(.trailing, Metrics.scrollbarInset)
                }
                .onAppear {
                    timeRefreshCoordinator.refreshNow()
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: selectedDate) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
                .onChange(of: items.map(\.selectionIdentifier)) { _, _ in
                    scrollToActiveGroup(using: proxy)
                }
            }
        }
    }

    // MARK: - Timeline Content

    private var timelineContent: some View {
        VStack(alignment: .leading, spacing: Metrics.groupSpacing) {
            ForEach(Array(timelineSnapshot.timedGroups.enumerated()), id: \.element.id) { index, group in
                timedGroupView(
                    group,
                    isFirst: index == timelineSnapshot.timedGroups.startIndex,
                    isLast: index == timelineSnapshot.timedGroups.index(before: timelineSnapshot.timedGroups.endIndex),
                    markerPosition: markerPosition(for: group.id)
                )
                .id(group.id)
            }

            if !timelineSnapshot.allDayItems.isEmpty {
                auxiliarySection(title: L("All Day"), items: timelineSnapshot.allDayItems)
            }

            if !timelineSnapshot.untimedItems.isEmpty {
                auxiliarySection(title: L("No Time"), items: timelineSnapshot.untimedItems)
            }
        }
        .overlayPreferenceValue(EventTimelineItemBoundsPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                if let placement = withinItemMarkerPlacement(using: anchors, in: proxy) {
                    withinItemMarkerOverlay(placement: placement)
                }
            }
        }
    }

    // MARK: - Timed group

    private func timedGroupView(
        _ group: EventTimelineGroup,
        isFirst: Bool,
        isLast: Bool,
        markerPosition: EventTimelineMarkerPosition?
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Now-marker BEFORE group (rail column only, no bleed into cards)
            if markerPosition == .beforeGroup {
                nowMarkerRow
            }

            // Time label + rail + cards
            HStack(alignment: .top, spacing: 0) {
                // Fixed-width time label (right-aligned)
                Text(group.displayTime)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(timeLabelColor(for: group))
                    .frame(width: Metrics.timeLabelWidth, alignment: .trailing)
                    // Offset the label 2pt down so it visually aligns with the card top edge.
                    .padding(.top, 2)

                // Rail column
                Spacer().frame(width: Metrics.laneSpacing)
                railColumn(for: group, isFirst: isFirst)
                    .frame(width: Metrics.railWidth)
                Spacer().frame(width: Metrics.cardSpacing)

                // Cards
                VStack(alignment: .leading, spacing: Metrics.cardSpacingInGroup) {
                    ForEach(group.items) { item in
                        itemButton(item, timelineState: timelineState(for: item))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Now-marker AFTER group (last group only — all items in the past)
            if markerPosition == .afterGroup, isLast {
                nowMarkerRow
            }
        }
    }

    // MARK: - Rail column

    private func railColumn(for group: EventTimelineGroup, isFirst: Bool) -> some View {
        // Rail = thin vertical connector line only. Per-group dots removed —
        // the time label on the left + the card on the right are sufficient
        // anchors; the dot was visual noise. Wrap the 1pt line in the full
        // railWidth-sized container so the now-marker overlay's dot still
        // lands at the same x-coordinate.
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.25))
            .frame(width: 1)
            .frame(width: Metrics.railWidth, alignment: .center)
            .frame(maxHeight: .infinity)
    }

    // MARK: - Now-marker

    /// The now-marker occupies only the time-label + rail columns (timeLabelWidth + laneSpacing +
    /// railWidth). It does NOT extend into the card area. A 1pt red horizontal line bridges the
    /// gap from the label trailing edge to the rail centre.
    private var nowMarkerRow: some View {
        HStack(alignment: .center, spacing: 0) {
            // Red time label with subtle red-tinted pill background so it pops out
            // from the gray hour labels. Trailing-aligned within timeLabelWidth so
            // the right edge still lines up with adjacent labels.
            Text(formattedCurrentTime)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.red)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.red.opacity(0.14), in: Capsule(style: .continuous))
                .frame(width: Metrics.timeLabelWidth, alignment: .trailing)

            // Thin 1pt red connector line from label edge to dot centre
            Rectangle()
                .fill(Color.red)
                .frame(width: Metrics.laneSpacing, height: 1)

            // Red dot centred in rail column
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: Metrics.nowDotSize, height: Metrics.nowDotSize)
            }
            .frame(width: Metrics.railWidth)

            // No card-area extension — spacer stops here
        }
        .padding(.vertical, 3)
    }

    // MARK: - Auxiliary sections (all-day, untimed)

    private func auxiliarySection(title: String, items: [CalendarItem]) -> some View {
        VStack(alignment: .leading, spacing: Metrics.cardSpacingInGroup) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: Metrics.cardSpacingInGroup) {
                ForEach(items) { item in
                    itemButton(item, timelineState: .regular)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Item buttons

    @ViewBuilder
    private func itemButton(_ item: CalendarItem, timelineState: EventCardTimelineState) -> some View {
        switch item {
        case .event(let event):
            Button {
                onSelectEvent(event)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == event.selectionIdentifier,
                    showsDisclosure: true,
                    timelineState: timelineState,
                    now: currentTime
                )
            }
            .buttonStyle(.plain)
            .anchorPreference(key: EventTimelineItemBoundsPreferenceKey.self, value: .bounds) {
                [item.selectionIdentifier: $0]
            }
        case .reminder(let reminder):
            Button {
                onOpenReminder(reminder)
            } label: {
                EventCardView(
                    item: item,
                    isSelected: selectedEventIdentifier == CalendarItem.reminder(reminder).selectionIdentifier,
                    showsDisclosure: true,
                    timelineState: timelineState,
                    onToggleReminder: onToggleReminder,
                    onDeleteReminder: onDeleteReminder,
                    now: currentTime
                )
            }
            .buttonStyle(.plain)
            .anchorPreference(key: EventTimelineItemBoundsPreferenceKey.self, value: .bounds) {
                [item.selectionIdentifier: $0]
            }
        }
    }

    // MARK: - Helpers

    private var timelineSnapshot: EventTimelineSnapshot {
        EventTimelineSnapshot.make(
            items: items,
            selectedDate: selectedDate,
            now: currentTime,
            calendar: .autoupdatingCurrent
        )
    }

    private var currentTime: Date {
        timeRefreshCoordinator.currentDate
    }

    private func timelineState(for item: CalendarItem) -> EventCardTimelineState {
        guard let status = item.timelineStatus(at: currentTime, calendar: .autoupdatingCurrent) else {
            return .regular
        }

        switch status {
        case .past:
            return .past
        case .ongoing:
            return .ongoing
        case .future:
            return .regular
        }
    }

    private func markerPosition(for groupID: String) -> EventTimelineMarkerPosition? {
        guard let marker = timelineSnapshot.marker, marker.groupID == groupID else {
            return nil
        }
        return marker.position
    }

    private var formattedCurrentTime: String {
        DateFormatters.shortTime(for: AppLocalization.locale).string(from: currentTime)
    }

    private func timeLabelColor(for group: EventTimelineGroup) -> Color {
        if group.containsOngoingItem {
            return .red
        }
        if group.isPast {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return .secondary
    }

    // MARK: - Within-item marker overlay

    private func withinItemMarkerPlacement(
        using anchors: [String: Anchor<CGRect>],
        in proxy: GeometryProxy
    ) -> WithinItemMarkerPlacement? {
        guard let marker = timelineSnapshot.marker else { return nil }
        guard case let .withinItem(selectionIdentifier, progress) = marker.position else {
            return nil
        }
        guard let anchor = anchors[selectionIdentifier] else {
            return nil
        }
        let frame = proxy[anchor]
        let y = markerY(for: frame, progress: progress)
        return WithinItemMarkerPlacement(frame: frame, y: y)
    }

    private func markerY(for frame: CGRect, progress: Double) -> CGFloat {
        let clampedProgress = min(max(progress, 0), 1)
        let minimumInset: CGFloat = 12
        let inset = min(minimumInset, frame.height / 2)
        let usableHeight = max(frame.height - inset * 2, 0)
        return frame.minY + inset + usableHeight * clampedProgress
    }

    private func withinItemMarkerOverlay(placement: WithinItemMarkerPlacement) -> some View {
        // The overlay sits in the time-label + rail columns only (same layout as nowMarkerRow).
        let dotCenterX = Metrics.timeLabelWidth + Metrics.laneSpacing + (Metrics.railWidth / 2)

        return ZStack(alignment: .topLeading) {
            // Red time label with subtle red-tinted pill background — matches nowMarkerRow style
            Text(formattedCurrentTime)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.red)
                .monospacedDigit()
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(Color.red.opacity(0.14), in: Capsule(style: .continuous))
                .frame(width: Metrics.timeLabelWidth, alignment: .trailing)
                .offset(y: placement.y - 7)

            // Thin 1pt connector
            Rectangle()
                .fill(Color.red)
                .frame(width: Metrics.laneSpacing, height: 1)
                .offset(x: Metrics.timeLabelWidth, y: placement.y)

            // Red dot
            Circle()
                .fill(Color.red)
                .frame(width: Metrics.nowDotSize, height: Metrics.nowDotSize)
                .offset(
                    x: dotCenterX - (Metrics.nowDotSize / 2),
                    y: placement.y - (Metrics.nowDotSize / 2)
                )
        }
        .allowsHitTesting(false)
    }

    private func scrollToActiveGroup(using proxy: ScrollViewProxy) {
        guard let targetID = timelineSnapshot.scrollTargetGroupID else { return }
        let anchor: UnitPoint = timelineSnapshot.shouldAnchorBottom ? .bottom : .top

        DispatchQueue.main.async {
            proxy.scrollTo(targetID, anchor: anchor)
        }
    }
}
