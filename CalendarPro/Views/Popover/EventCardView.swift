import SwiftUI
import EventKit

enum EventCardTimelineState: Equatable {
    case regular
    case past
    case ongoing
}

private enum EventCardMetadata {
    case participation(EventParticipationChoice)
    case meeting(link: MeetingLink, participantCount: Int?)
    case recurringReminder(String)
}

struct EventCardView: View {
    let item: CalendarItem
    let isSelected: Bool
    let showsDisclosure: Bool
    let timelineState: EventCardTimelineState
    var onToggleReminder: ((EKReminder) -> Void)?
    var onDeleteReminder: ((EKReminder) -> Void)?
    /// Current time used for overdue calculations. Defaults to `Date()` for previews.
    var now: Date

    init(
        item: CalendarItem,
        isSelected: Bool = false,
        showsDisclosure: Bool = true,
        timelineState: EventCardTimelineState = .regular,
        onToggleReminder: ((EKReminder) -> Void)? = nil,
        onDeleteReminder: ((EKReminder) -> Void)? = nil,
        now: Date = Date()
    ) {
        self.item = item
        self.isSelected = isSelected
        self.showsDisclosure = showsDisclosure
        self.timelineState = timelineState
        self.onToggleReminder = onToggleReminder
        self.onDeleteReminder = onDeleteReminder
        self.now = now
    }

    init(event: EKEvent, isSelected: Bool) {
        self.init(item: .event(event), isSelected: isSelected)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Leading accent strip: 2pt red for overdue, 3pt accent-color for ongoing.
            // Cancelled and completed reminders get no strip.
            if !item.isCanceled {
                if item.isOverdue(now: now) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color.red)
                        .frame(width: 2)
                        .padding(.vertical, 6)
                        .padding(.trailing, 6)
                } else if timelineState == .ongoing {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(Color(nsColor: item.color))
                        .frame(width: 3)
                        .padding(.vertical, 6)
                        .padding(.trailing, 6)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // ── Title row ──────────────────────────────────────────────
                HStack(alignment: .top, spacing: 4) {
                    // Reminder checkbox / event color dot
                    if item.isReminder {
                        reminderCheckbox
                            .padding(.top, 1)
                    } else {
                        Circle()
                            .fill(indicatorColor)
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)
                    }

                    // Priority indicator prefix (!, !!, !!!) inline before title
                    if let priority = item.reminderPriority, priority > 0 {
                        Text(priorityExclamationText(priority))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(priorityColor(priority))
                            .fixedSize()
                            .padding(.top, 1)
                    }

                    Text(item.title)
                        .font(.system(size: 13, weight: .regular))
                        .lineLimit(2)
                        .strikethrough(item.isCompleted || item.isCanceled)
                        .foregroundStyle(titleColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .animation(.easeInOut(duration: 0.2), value: item.isCompleted)

                    // Metadata icons: right side of the title row
                    if showsDisclosure, !metadataItems.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(Array(metadataItems.enumerated()), id: \.offset) { _, metadata in
                                metadataView(metadata)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }

                // ── Bottom info row: project · status ──────────────────────
                // Always present — replaces the old orphaned secondaryText block.
                // Combines: calendar name · end-time (events) or overdue/recurrence label (reminders)
                bottomInfoRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 56, alignment: .top)
        .background(backgroundColor)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(contentOpacity)
        .animation(.easeInOut(duration: 0.2), value: item.isCompleted)
        .shadow(
            color: ongoingGlowColor,
            radius: 4
        )
        .contextMenu {
            if let reminder = item.ekReminder {
                Button(L("Toggle Completion")) { onToggleReminder?(reminder) }
                Divider()
                Button(L("Delete"), role: .destructive) { onDeleteReminder?(reminder) }
            }
        }
    }

    // MARK: - Bottom info row

    @ViewBuilder
    private var bottomInfoRow: some View {
        let parts = bottomInfoParts
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(bottomInfoColor)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bottomInfoParts: [String] {
        var parts: [String] = []

        // Calendar / list name
        let src = item.sourceTitle
        if !src.isEmpty {
            parts.append(src)
        }

        // Location (events only) — takes precedence over end-time as secondary info
        if let location = item.location, !location.isEmpty {
            parts.append(location)
            return parts
        }

        // End-time for timed events (→ HH:mm)
        if case .event = item {
            if !item.isAllDay, let endDate = item.endDate {
                let formatter = DateFormatters.shortTime(for: AppLocalization.locale)
                parts.append("→ \(formatter.string(from: endDate))")
            }
        }

        // Overdue label for reminders
        if item.isOverdue(now: now) {
            parts.append(L("Overdue"))
        }

        return parts
    }

    private var bottomInfoColor: Color {
        if item.isCanceled { return Color(nsColor: .tertiaryLabelColor) }
        if item.isOverdue(now: now) { return .red.opacity(0.8) }
        return .secondary.opacity(0.8)
    }

    // MARK: - Colors & appearance

    private var backgroundColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.08 : 0.05)
        }
        if isSelected {
            return Color.accentColor.opacity(0.12)
        }
        if timelineState == .ongoing {
            return Color.accentColor.opacity(0.08)
        }
        if timelineState == .past {
            return Color(nsColor: .controlBackgroundColor).opacity(0.6)
        }
        return Color(nsColor: .controlBackgroundColor)
    }

    private var borderColor: Color {
        if item.isCanceled {
            return Color.red.opacity(isSelected ? 0.32 : 0.2)
        }
        if isSelected {
            return Color.accentColor.opacity(0.35)
        }
        if timelineState == .ongoing {
            return Color.accentColor.opacity(0.24)
        }
        return Color.primary.opacity(0.05)
    }

    private var contentOpacity: Double {
        if item.isCanceled {
            return isSelected ? 0.96 : 0.88
        }
        if item.isCompleted { return 0.5 }
        // Overdue reminders pop at full opacity — the red strip + red time label
        // are the visual "you owe this" signal; fading would defeat it.
        if item.isOverdue(now: now) { return 1 }
        if timelineState == .past, !isSelected { return 0.5 }
        return 1
    }

    /// Soft accent-color glow for ongoing events only.
    private var ongoingGlowColor: Color {
        guard timelineState == .ongoing, !item.isCanceled, !isSelected else { return .clear }
        return Color(nsColor: item.color).opacity(0.4)
    }

    private var indicatorColor: Color {
        let color = Color(nsColor: item.color)
        return item.isCanceled ? color.opacity(0.4) : color
    }

    private var titleColor: Color {
        if item.isCompleted || item.isCanceled {
            return .secondary
        }
        return .primary
    }

    private var metadataColor: Color {
        if item.isCanceled {
            return Color(nsColor: .tertiaryLabelColor)
        }
        return isSelected ? Color.accentColor : Color(nsColor: .tertiaryLabelColor)
    }

    private var metadataItems: [EventCardMetadata] {
        var items: [EventCardMetadata] = []

        if let participationChoice = item.currentUserParticipationChoice {
            items.append(.participation(participationChoice))
        }

        if let meetingLink = item.meetingLink {
            items.append(.meeting(link: meetingLink, participantCount: item.meetingParticipantCount))
        }

        if items.isEmpty, let recurrenceText = item.reminderRecurrenceText {
            items.append(.recurringReminder(recurrenceText))
        }

        return items
    }

    // MARK: - Reminder checkbox

    private var reminderCheckbox: some View {
        Button {
            if let reminder = item.ekReminder {
                onToggleReminder?(reminder)
            }
        } label: {
            Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 14))
                .foregroundStyle(
                    item.isCompleted
                        ? Color(nsColor: item.color)
                        : Color(nsColor: item.color).opacity(0.85)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Priority helpers

    private func priorityExclamationText(_ priority: Int) -> String {
        switch priority {
        case 1:  return "!!!"
        case 5:  return "!!"
        case 9:  return "!"
        default: return ""
        }
    }

    private func priorityColor(_ priority: Int) -> Color {
        priority == 9 ? .secondary : .red
    }

    @ViewBuilder
    private func metadataView(_ metadata: EventCardMetadata) -> some View {
        switch metadata {
        case .participation(let choice):
            EventParticipationStatusBadge(choice: choice, style: .compactIcon)
        case .meeting(let link, let participantCount):
            HStack(spacing: 5) {
                MeetingPlatformMark(platform: link.platform, style: .compact)
                    .foregroundStyle(metadataColor)

                if let participantCount {
                    HStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.system(size: 9, weight: .medium))
                        Text(verbatim: "\(participantCount)")
                    }
                    .foregroundStyle(metadataColor)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        case .recurringReminder(let recurrenceText):
            HStack(spacing: 4) {
                Image(systemName: "repeat")
                    .font(.system(size: 9, weight: .semibold))
                Text(recurrenceText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(metadataColor)
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

enum EventParticipationBadgeStyle {
    case compactIcon
    case detail

    var font: Font {
        switch self {
        case .compactIcon:
            return .system(size: 10, weight: .semibold)
        case .detail:
            return .system(size: 11, weight: .semibold)
        }
    }

    var iconFont: Font {
        switch self {
        case .compactIcon:
            return .system(size: 9, weight: .semibold)
        case .detail:
            return .system(size: 10, weight: .semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .compactIcon:
            return 0
        case .detail:
            return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .compactIcon:
            return 0
        case .detail:
            return 4
        }
    }

    var showsTitle: Bool {
        switch self {
        case .compactIcon:
            return false
        case .detail:
            return true
        }
    }

    var iconFrameSize: CGFloat {
        switch self {
        case .compactIcon:
            return 18
        case .detail:
            return 0
        }
    }
}

struct EventParticipationStatusBadge: View {
    let choice: EventParticipationChoice
    let style: EventParticipationBadgeStyle

    var body: some View {
        Group {
            if style.showsTitle {
                HStack(spacing: 4) {
                    Image(systemName: choice.badgeSymbolName)
                        .font(style.iconFont)

                    Text(choice.badgeTitle)
                        .font(style.font)
                        .lineLimit(1)
                }
                .padding(.horizontal, style.horizontalPadding)
                .padding(.vertical, style.verticalPadding)
                .background(
                    Capsule(style: .continuous)
                        .fill(choice.badgeBackgroundColor)
                )
            } else {
                Image(systemName: choice.badgeSymbolName)
                    .font(style.iconFont)
                    .frame(width: style.iconFrameSize, height: style.iconFrameSize)
                    .background(
                        Circle()
                            .fill(choice.badgeBackgroundColor)
                    )
            }
        }
        .foregroundStyle(choice.badgeForegroundColor)
        .fixedSize(horizontal: true, vertical: false)
    }
}

private extension EventParticipationChoice {
    var badgeTitle: String {
        switch self {
        case .accept:
            return L("Accepted")
        case .maybe:
            return L("Maybe")
        case .decline:
            return L("Declined")
        }
    }

    var badgeSymbolName: String {
        switch self {
        case .accept:
            return "checkmark.circle.fill"
        case .maybe:
            return "questionmark.circle.fill"
        case .decline:
            return "xmark.circle.fill"
        }
    }

    var badgeForegroundColor: Color {
        switch self {
        case .accept:
            return Color(red: 0.11, green: 0.55, blue: 0.25)
        case .maybe:
            return Color(red: 0.82, green: 0.48, blue: 0.08)
        case .decline:
            return Color(red: 0.78, green: 0.22, blue: 0.19)
        }
    }

    var badgeBackgroundColor: Color {
        switch self {
        case .accept:
            return Color(red: 0.11, green: 0.55, blue: 0.25).opacity(0.12)
        case .maybe:
            return Color(red: 0.82, green: 0.48, blue: 0.08).opacity(0.14)
        case .decline:
            return Color(red: 0.78, green: 0.22, blue: 0.19).opacity(0.12)
        }
    }
}

enum MeetingPlatformMarkStyle {
    case compact
    case detail

    var frameWidth: CGFloat {
        switch self {
        case .compact: return 14
        case .detail: return 18
        }
    }

    var frameHeight: CGFloat {
        switch self {
        case .compact: return 12
        case .detail: return 16
        }
    }

    var monogramFontSize: CGFloat {
        switch self {
        case .compact: return 6.3
        case .detail: return 7.5
        }
    }

    var symbolFont: Font {
        switch self {
        case .compact:
            return .system(size: 9, weight: .semibold)
        case .detail:
            return .system(size: 13, weight: .semibold)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .compact: return 3.4
        case .detail: return 4.5
        }
    }

    var scale: CGFloat {
        switch self {
        case .compact: return 1
        case .detail: return 1.18
        }
    }
}

struct MeetingPlatformMark: View {
    let platform: MeetingPlatform
    let style: MeetingPlatformMarkStyle

    var body: some View {
        switch platform {
        case .microsoftTeams:
            TeamsBrandMark(style: style)
        case .tencentMeeting:
            MeetingMonogramMark(text: "TM", background: Color(red: 0.11, green: 0.51, blue: 0.98), style: style)
        case .feishu:
            MeetingMonogramMark(text: "F", background: Color(red: 0.18, green: 0.54, blue: 0.96), style: style)
        case .zoom:
            MeetingMonogramMark(text: "Z", background: Color(red: 0.16, green: 0.46, blue: 0.95), style: style)
        case .googleMeet:
            MeetingMonogramMark(text: "G", background: Color(red: 0.20, green: 0.66, blue: 0.33), style: style)
        case .webex:
            MeetingMonogramMark(text: "W", background: Color(red: 0.00, green: 0.68, blue: 0.71), style: style)
        default:
            Image(systemName: platform.symbolName)
                .font(style.symbolFont)
                .frame(width: style.frameWidth, height: style.frameHeight)
                .accessibilityHidden(true)
        }
    }
}

private struct MeetingMonogramMark: View {
    let text: String
    let background: Color
    let style: MeetingPlatformMarkStyle

    var body: some View {
        RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
            .fill(background)
            .overlay {
                Text(verbatim: text)
                    .font(.system(size: style.monogramFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            .frame(width: style.frameWidth, height: style.frameHeight)
            .accessibilityHidden(true)
    }
}

private struct TeamsBrandMark: View {
    let style: MeetingPlatformMarkStyle

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.43, green: 0.47, blue: 0.93))
                .frame(width: 4.6 * style.scale, height: 4.6 * style.scale)
                .offset(x: 4.8 * style.scale, y: 3 * style.scale)

            Circle()
                .fill(Color(red: 0.31, green: 0.36, blue: 0.84))
                .frame(width: 4.4 * style.scale, height: 4.4 * style.scale)
                .offset(x: 5.2 * style.scale, y: -3.1 * style.scale)

            RoundedRectangle(cornerRadius: 2.1, style: .continuous)
                .fill(Color(red: 0.38, green: 0.43, blue: 0.93))
                .frame(width: 6.2 * style.scale, height: 8.2 * style.scale)
                .offset(x: 2.3 * style.scale)

            RoundedRectangle(cornerRadius: 2.4, style: .continuous)
                .fill(Color(red: 0.28, green: 0.32, blue: 0.79))
                .frame(width: 8.1 * style.scale, height: 10.2 * style.scale)
                .offset(x: -1.1 * style.scale)

            Text(verbatim: "T")
                .font(.system(size: style.monogramFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(x: -1.1 * style.scale, y: -0.3 * style.scale)
        }
        .frame(width: style.frameWidth, height: style.frameHeight)
        .accessibilityHidden(true)
    }
}
