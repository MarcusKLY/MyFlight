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
    var actualDeparture: Date?
    var scheduledArrival: Date?
    var actualArrival: Date?
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
        actualDeparture: Date? = nil,
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
        self.actualDeparture = actualDeparture
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
