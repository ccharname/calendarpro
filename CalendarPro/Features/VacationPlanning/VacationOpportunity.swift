import Foundation

enum VacationSegmentKind: String, Equatable {
    case weekend
    case statutoryHoliday
    case leaveRequired
    case adjustmentWorkday
    case bridgeRestDay
}

struct VacationSegment: Equatable, Identifiable {
    let date: Date
    let kind: VacationSegmentKind
    let label: String

    var id: Date { date }
}

struct VacationOpportunity: Equatable, Identifiable {
    let year: Int
    let holidayName: String
    let startDate: Date
    let endDate: Date
    let focusDate: Date
    let leaveDaysRequired: Int
    let continuousRestDays: Int
    let segments: [VacationSegment]
    let rankingScore: Int
    let starRating: Int
    let summary: String
    let note: String

    var id: String {
        let formatter = DateFormatters.gregorianISODay
        return "\(year)-\(formatter.string(from: startDate))-\(formatter.string(from: endDate))-\(holidayName)"
    }
}
