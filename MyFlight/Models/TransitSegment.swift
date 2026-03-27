//
//  TransitSegment.swift
//  MyFlight
//
//  Created by Copilot on 27/3/2026.
//

import Foundation
import SwiftData
import MapKit

// MARK: - Transit Type

enum TransitType: String, CaseIterable, Codable, Identifiable {
    case bus = "Bus"
    case ferry = "Ferry"
    case train = "Train"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bus: return "bus.fill"
        case .ferry: return "ferry.fill"
        case .train: return "tram.fill"
        }
    }

    var color: String {
        switch self {
        case .bus: return "orange"
        case .ferry: return "teal"
        case .train: return "purple"
        }
    }
}

// MARK: - Transit Status

enum TransitStatus: String, CaseIterable, Codable, Identifiable {
    case scheduled = "Scheduled"
    case departed = "Departed"
    case enRoute = "En Route"
    case arrived = "Arrived"
    case delayed = "Delayed"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}

// MARK: - Transit Segment Model

@Model
final class TransitSegment {
    @Attribute(.unique) var id: UUID

    // Core identification
    private var transitTypeRawValue: String
    var routeNumber: String
    var operatorName: String

    // Origin location
    var originName: String
    var originLatitude: Double
    var originLongitude: Double

    // Destination location
    var destinationName: String
    var destinationLatitude: Double
    var destinationLongitude: Double

    // Timestamps (simpler than Flight's 11 types)
    var scheduledDeparture: Date
    var scheduledArrival: Date
    var estimatedDeparture: Date?
    var estimatedArrival: Date?
    var actualDeparture: Date?
    var actualArrival: Date?

    // Status tracking
    private var statusRawValue: String

    // Notes for user reference
    var notes: String?

    init(
        transitType: TransitType,
        routeNumber: String,
        operatorName: String,
        originName: String,
        originLatitude: Double,
        originLongitude: Double,
        destinationName: String,
        destinationLatitude: Double,
        destinationLongitude: Double,
        scheduledDeparture: Date,
        scheduledArrival: Date,
        estimatedDeparture: Date? = nil,
        estimatedArrival: Date? = nil,
        actualDeparture: Date? = nil,
        actualArrival: Date? = nil,
        status: TransitStatus = .scheduled,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.transitTypeRawValue = transitType.rawValue
        self.routeNumber = routeNumber
        self.operatorName = operatorName
        self.originName = originName
        self.originLatitude = originLatitude
        self.originLongitude = originLongitude
        self.destinationName = destinationName
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.scheduledDeparture = scheduledDeparture
        self.scheduledArrival = scheduledArrival
        self.estimatedDeparture = estimatedDeparture
        self.estimatedArrival = estimatedArrival
        self.actualDeparture = actualDeparture
        self.actualArrival = actualArrival
        self.statusRawValue = status.rawValue
        self.notes = notes
    }

    // MARK: - Computed Properties

    var transitType: TransitType {
        get { TransitType(rawValue: transitTypeRawValue) ?? .bus }
        set { transitTypeRawValue = newValue.rawValue }
    }

    var transitStatus: TransitStatus {
        get {
            // Check for manually set cancelled/delayed status
            let stored = TransitStatus(rawValue: statusRawValue) ?? .scheduled
            if stored == .cancelled {
                return .cancelled
            }
            
            // Auto-compute status based on current time
            let now = Date()
            let departure = effectiveDeparture
            let arrival = effectiveArrival
            
            // Arrived: past arrival time
            if now >= arrival {
                return .arrived
            }
            
            // In transit: between departure and arrival
            if now >= departure && now < arrival {
                if stored == .delayed {
                    return .delayed
                }
                return .enRoute
            }
            
            // Departed but not yet en route: right after departure
            if now >= departure {
                return .departed
            }
            
            // Before departure
            if stored == .delayed {
                return .delayed
            }
            return .scheduled
        }
        set { statusRawValue = newValue.rawValue }
    }

    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude)
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
    }

    /// Best estimated departure: actual > estimated > scheduled
    var effectiveDeparture: Date {
        actualDeparture ?? estimatedDeparture ?? scheduledDeparture
    }

    /// Best estimated arrival: actual > estimated > scheduled
    var effectiveArrival: Date {
        actualArrival ?? estimatedArrival ?? scheduledArrival
    }

    /// True when we have definitive arrival confirmation
    var hasArrived: Bool {
        transitStatus == .arrived || actualArrival != nil
    }

    /// Progress in the range 0.0–1.0 based on current time relative to departure and arrival
    var progress: Double? {
        let departure = effectiveDeparture
        let arrival = effectiveArrival
        let total = arrival.timeIntervalSince(departure)
        guard total > 0 else { return nil }

        if hasArrived { return 1.0 }

        let now = Date()
        guard now >= departure else { return 0 }
        guard now <= arrival else { return 1 }
        return now.timeIntervalSince(departure) / total
    }

    /// Duration in minutes
    var durationMinutes: Int {
        let interval = scheduledArrival.timeIntervalSince(scheduledDeparture)
        return max(0, Int(interval / 60))
    }

    /// Human-readable duration string, e.g. "2h 30m"
    var durationFormatted: String {
        let mins = durationMinutes
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    /// Departure delay in minutes compared to scheduled time
    var departureDelayMinutes: Int? {
        guard let actual = actualDeparture ?? estimatedDeparture else { return nil }
        let delta = actual.timeIntervalSince(scheduledDeparture)
        let minutes = Int(delta / 60)
        return minutes != 0 ? minutes : nil
    }

    /// Arrival delay in minutes compared to scheduled time
    var arrivalDelayMinutes: Int? {
        guard let actual = actualArrival ?? estimatedArrival else { return nil }
        let delta = actual.timeIntervalSince(scheduledArrival)
        let minutes = Int(delta / 60)
        return minutes != 0 ? minutes : nil
    }

    /// Route description for display
    var routeDescription: String {
        "\(originName) → \(destinationName)"
    }

    /// Display name combining operator and route number
    var displayName: String {
        if routeNumber.isEmpty {
            return operatorName
        }
        return "\(operatorName) \(routeNumber)"
    }

    /// Formatted departure time
    func formattedDeparture(actual: Bool = false, style: DateFormatter.Style = .short) -> String {
        let date = actual ? (actualDeparture ?? scheduledDeparture) : scheduledDeparture
        return formatTime(date, style: style)
    }

    /// Formatted arrival time
    func formattedArrival(actual: Bool = false, style: DateFormatter.Style = .short) -> String {
        let date = actual ? (actualArrival ?? scheduledArrival) : scheduledArrival
        return formatTime(date, style: style)
    }

    /// Formatted scheduled departure date
    var departureDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: scheduledDeparture)
    }

    private func formatTime(_ date: Date, style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        return formatter.string(from: date)
    }
}
