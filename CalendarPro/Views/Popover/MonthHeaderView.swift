import SwiftUI

struct MonthHeaderView: View {
    let displayedMonth: Date
    let showVacationGuideButton: Bool
    let isVacationGuideEnabled: Bool
    let vacationGuideDisabledReason: String?
    let onPreviousMonth: () -> Void
    let onNextMonth: () -> Void
    let onSelectYear: () -> Void
    let onSelectMonth: () -> Void
    let onOpenVacationGuide: () -> Void
    let onResetToToday: () -> Void

    private var yearText: String {
        DateFormatters.yearOnly(for: AppLocalization.locale).string(from: displayedMonth)
    }

    private var monthText: String {
        DateFormatters.monthFull(for: AppLocalization.locale).string(from: displayedMonth)
    }

    var body: some View {
        ZStack {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    navigationButton(
                        systemImage: "chevron.left",
                        label: L("Previous Month"),
                        identifier: "previous-month-button",
                        action: onPreviousMonth
                    )

                    if showVacationGuideButton {
                        vacationGuideButton
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 8) {
                    todayButton

                    navigationButton(
                        systemImage: "chevron.right",
                        label: L("Next Month"),
                        identifier: "next-month-button",
                        action: onNextMonth
                    )
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            HStack(spacing: 4) {
                Button(action: onSelectYear) {
                    Text(yearText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button(action: onSelectMonth) {
                    Text(monthText)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
            }
            .lineLimit(1)
            .padding(.horizontal, 88)
        }
    }

    private var vacationGuideButton: some View {
        // Demoted to secondary styling — Today remains the sole blue accent in the header.
        Button(action: onOpenVacationGuide) {
            headerPillLabel(
                title: "休假",
                foregroundStyle: .secondary,
                backgroundColor: Color.secondary.opacity(0.1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isVacationGuideEnabled)
        .accessibilityIdentifier("vacation-guide-button")
        .help(vacationGuideDisabledReason ?? "查看年度休假建议")
    }

    private var todayButton: some View {
        Button(action: onResetToToday) {
            headerPillLabel(
                title: L("Today Nav"),
                foregroundStyle: Color.accentColor,
                backgroundColor: Color.accentColor.opacity(0.12)
            )
        }
        .buttonStyle(.plain)
        .keyboardShortcut("t", modifiers: .command)
        .accessibilityIdentifier("reset-to-today-button")
        .accessibilityLabel(L("Today Nav"))
    }

    private func navigationButton(
        systemImage: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func headerPillLabel(
        title: String,
        foregroundStyle: Color,
        backgroundColor: Color
    ) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundStyle)
            .padding(.horizontal, 8)
            .frame(height: 28)
            .background(
                Capsule(style: .continuous)
                    .fill(backgroundColor)
            )
    }
}
