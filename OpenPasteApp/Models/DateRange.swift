//
//  DateRange.swift
//  OpenPaste
//
//  Created by fictionking on 2026-03-28.
//

import Foundation

/// Date range filter options
enum DateRange: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case pastWeek = "Past Week"
    case pastMonth = "Past Month"
    case allTime = "All Time"

    var displayName: String {
        return rawValue
    }

    /// Returns the date range start date for filtering
    var startDate: Date? {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            return calendar.startOfDay(for: now)
        case .yesterday:
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        case .pastWeek:
            return calendar.date(byAdding: .day, value: -7, to: now)
        case .pastMonth:
            return calendar.date(byAdding: .month, value: -1, to: now)
        case .allTime:
            return nil
        }
    }

    /// Returns the NSPredicate for filtering by this date range
    var predicate: NSPredicate? {
        guard let startDate = self.startDate else {
            return nil // All time - no filter
        }

        return NSPredicate(format: "capturedAt >= %@", startDate as CVarArg)
    }
}
