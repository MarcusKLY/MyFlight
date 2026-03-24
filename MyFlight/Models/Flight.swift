//
//  Flight.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import Foundation
import SwiftData

enum FlightStatus: String, CaseIterable, Codable, Identifiable {
    case onTime = "On Time"
    case delayed = "Delayed"
    case arrived = "Arrived"
    case cancelled = "Cancelled"

    var id: String { rawValue }
}

@Model
final class Flight {
    @Attribute(.unique) var id: UUID
    var flightNumber: String
    var airline: String
    var origin: Airport
    var destination: Airport
    var scheduledDeparture: Date
    var estimatedDeparture: Date?     // Estimated gate-out time
    var actualDeparture: Date?        // Actual gate-out time
    var runwayDeparture: Date?        // Wheels-off / takeoff time
    var runwayArrival: Date?          // Wheels-on / landing time
    var estimatedArrival: Date?       // Estimated gate-in time
    var scheduledArrival: Date?
    var actualArrival: Date?          // Actual gate-in time
    var departureGate: String?
    var departureTerminal: String?
    var arrivalGate: String?
    var arrivalTerminal: String?
    var baggageClaim: String?
    var aircraftModel: String?
    var tailNumber: String?
    private var statusRawValue: String

    init(
        flightNumber: String,
        airline: String,
        origin: Airport,
        destination: Airport,
        scheduledDeparture: Date,
        estimatedDeparture: Date? = nil,
        actualDeparture: Date? = nil,
        runwayDeparture: Date? = nil,
        runwayArrival: Date? = nil,
        estimatedArrival: Date? = nil,
        scheduledArrival: Date? = nil,
        actualArrival: Date? = nil,
        departureGate: String? = nil,
        departureTerminal: String? = nil,
        arrivalGate: String? = nil,
        arrivalTerminal: String? = nil,
        baggageClaim: String? = nil,
        aircraftModel: String? = nil,
        tailNumber: String? = nil,
        flightStatus: FlightStatus = .onTime
    ) {
        self.id = UUID()
        self.flightNumber = flightNumber
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.scheduledDeparture = scheduledDeparture
        self.estimatedDeparture = estimatedDeparture
        self.actualDeparture = actualDeparture
        self.runwayDeparture = runwayDeparture
        self.runwayArrival = runwayArrival
        self.estimatedArrival = estimatedArrival
        self.scheduledArrival = scheduledArrival
        self.actualArrival = actualArrival
        self.departureGate = departureGate
        self.departureTerminal = departureTerminal
        self.arrivalGate = arrivalGate
        self.arrivalTerminal = arrivalTerminal
        self.baggageClaim = baggageClaim
        self.aircraftModel = aircraftModel
        self.tailNumber = tailNumber
        self.statusRawValue = flightStatus.rawValue
    }

    var flightStatus: FlightStatus {
        get { FlightStatus(rawValue: statusRawValue) ?? .onTime }
        set { statusRawValue = newValue.rawValue }
    }

    // Keep compatibility with existing call sites that still reference `date`.
    var date: Date {
        scheduledDeparture
    }

    /// Best estimated departure: actual gate-out > estimated > scheduled.
    var effectiveDeparture: Date {
        actualDeparture ?? estimatedDeparture ?? scheduledDeparture
    }

    /// Best estimated arrival: actual gate-in > estimated > scheduled.
    var effectiveArrival: Date? {
        actualArrival ?? estimatedArrival ?? scheduledArrival
    }

    /// Flight progress in the range 0.0–1.0 based on current time relative to
    /// takeoff (or gate departure) and landing (or gate/scheduled arrival).
    /// Returns nil when the flight is not yet trackable (no arrival time known).
    var flightProgress: Double? {
        let departure = runwayDeparture ?? actualDeparture ?? scheduledDeparture
        guard let arrival = runwayArrival ?? actualArrival ?? estimatedArrival ?? scheduledArrival else {
            return nil
        }
        let total = arrival.timeIntervalSince(departure)
        guard total > 0 else { return nil }
        let now = Date()
        guard now >= departure else { return 0 }
        guard now <= arrival else { return 1 }
        return now.timeIntervalSince(departure) / total
    }

    /// Departure delay in minutes compared to scheduled time.
    var departureDelayMinutes: Int? {
        guard let actual = actualDeparture ?? estimatedDeparture else { return nil }
        let delta = actual.timeIntervalSince(scheduledDeparture)
        let minutes = Int(delta / 60)
        return minutes != 0 ? minutes : nil
    }

    /// Arrival delay in minutes compared to scheduled time.
    var arrivalDelayMinutes: Int? {
        guard let scheduled = scheduledArrival else { return nil }
        guard let actual = actualArrival ?? estimatedArrival else { return nil }
        let delta = actual.timeIntervalSince(scheduled)
        let minutes = Int(delta / 60)
        return minutes != 0 ? minutes : nil
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: scheduledDeparture)
    }

    var routeDescription: String {
        "\(origin.iataCode) → \(destination.iataCode)"
    }

    /// Formatted departure time in the origin airport's local timezone (falls back to device timezone).
    func formattedDeparture(actual: Bool = false, style: DateFormatter.Style = .short) -> String {
        let date = actual ? (actualDeparture ?? scheduledDeparture) : scheduledDeparture
        return formatDate(date, timezone: origin.timezone, dateStyle: .none, timeStyle: style)
    }

    /// Formatted arrival time in the destination airport's local timezone (falls back to device timezone).
    func formattedArrival(actual: Bool = false, style: DateFormatter.Style = .short) -> String {
        let date = actual ? (actualArrival ?? scheduledArrival) : scheduledArrival
        guard let date else { return "—" }
        return formatDate(date, timezone: destination.timezone, dateStyle: .none, timeStyle: style)
    }

    /// Formatted scheduled departure date (medium) in origin timezone.
    var departureDateFormatted: String {
        formatDate(scheduledDeparture, timezone: origin.timezone, dateStyle: .medium, timeStyle: .none)
    }

    /// Flight duration in minutes derived from scheduled times. Returns nil if arrival is unknown.
    var durationMinutes: Int? {
        guard let arrival = scheduledArrival else { return nil }
        let interval = arrival.timeIntervalSince(scheduledDeparture)
        guard interval > 0 else { return nil }
        return Int(interval / 60)
    }

    /// Human-readable flight duration string, e.g. "9h 45m".
    var durationFormatted: String? {
        guard let mins = durationMinutes else { return nil }
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func formatDate(_ date: Date, timezone: String?, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        if let tz = timezone, let zone = TimeZone(identifier: tz) {
            formatter.timeZone = zone
        }
        return formatter.string(from: date)
    }
}
