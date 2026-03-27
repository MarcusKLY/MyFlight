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
    case enRoute = "En Route"
    case departed = "Departed"
    case expected = "Expected"

    var id: String { rawValue }
}

@Model
final class Flight {
    @Attribute(.unique) var id: UUID
    var flightNumber: String
    var airline: String
    var airlineIATA: String?
    var origin: Airport
    var destination: Airport
    var scheduledDeparture: Date
    var revisedDeparture: Date?       // Last revised departure time from provider
    var estimatedDeparture: Date?     // Estimated gate-out time
    var actualDeparture: Date?        // Actual gate-out time
    var runwayDeparture: Date?        // Wheels-off / takeoff time
    var runwayArrival: Date?          // Wheels-on / landing time
    var revisedArrival: Date?         // Last revised arrival time from provider
    var estimatedArrival: Date?       // Estimated gate-in time
    var predictedArrival: Date?       // Predicted arrival (more accurate for in-flight)
    var scheduledArrival: Date?
    var actualArrival: Date?          // Actual gate-in time
    var departureGate: String?
    var departureTerminal: String?
    var departureRunway: String?
    var departureCheckInDesk: String?
    var arrivalGate: String?
    var arrivalTerminal: String?
    var arrivalRunway: String?
    var baggageClaim: String?
    var aircraftModel: String?
    var aircraftImageUrl: String?
    var aircraftAge: String?
    var aircraftTypeName: String?
    var aircraftModelCode: String?
    var aircraftSeatCount: Int?
    var aircraftEngineCount: Int?
    var aircraftEngineType: String?
    var aircraftIsActive: Bool?
    var aircraftIsFreighter: Bool?
    var aircraftDataVerified: Bool?
    var aircraftManufacturedYear: Int?
    var aircraftRegistrationDate: String?
    var tailNumber: String?
    var distanceKm: Double?
    var distanceNm: Double?
    var distanceMiles: Double?
    var callSign: String?
    private var statusRawValue: String

    init(
        flightNumber: String,
        airline: String,
        airlineIATA: String? = nil,
        origin: Airport,
        destination: Airport,
        scheduledDeparture: Date,
        revisedDeparture: Date? = nil,
        estimatedDeparture: Date? = nil,
        actualDeparture: Date? = nil,
        runwayDeparture: Date? = nil,
        runwayArrival: Date? = nil,
        revisedArrival: Date? = nil,
        estimatedArrival: Date? = nil,
        predictedArrival: Date? = nil,
        scheduledArrival: Date? = nil,
        actualArrival: Date? = nil,
        departureGate: String? = nil,
        departureTerminal: String? = nil,
        departureRunway: String? = nil,
        departureCheckInDesk: String? = nil,
        arrivalGate: String? = nil,
        arrivalTerminal: String? = nil,
        arrivalRunway: String? = nil,
        baggageClaim: String? = nil,
        aircraftModel: String? = nil,
        aircraftImageUrl: String? = nil,
        aircraftAge: String? = nil,
        aircraftTypeName: String? = nil,
        aircraftModelCode: String? = nil,
        aircraftSeatCount: Int? = nil,
        aircraftEngineCount: Int? = nil,
        aircraftEngineType: String? = nil,
        aircraftIsActive: Bool? = nil,
        aircraftIsFreighter: Bool? = nil,
        aircraftDataVerified: Bool? = nil,
        aircraftManufacturedYear: Int? = nil,
        tailNumber: String? = nil,
        distanceKm: Double? = nil,
        distanceNm: Double? = nil,
        distanceMiles: Double? = nil,
        callSign: String? = nil,
        flightStatus: FlightStatus = .onTime,
        aircraftRegistrationDate: String? = nil
    ) {
        self.id = UUID()
        self.flightNumber = flightNumber
        self.airline = airline
        self.airlineIATA = airlineIATA
        self.origin = origin
        self.destination = destination
        self.scheduledDeparture = scheduledDeparture
        self.revisedDeparture = revisedDeparture
        self.estimatedDeparture = estimatedDeparture
        self.actualDeparture = actualDeparture
        self.runwayDeparture = runwayDeparture
        self.runwayArrival = runwayArrival
        self.revisedArrival = revisedArrival
        self.estimatedArrival = estimatedArrival
        self.predictedArrival = predictedArrival
        self.scheduledArrival = scheduledArrival
        self.actualArrival = actualArrival
        self.departureGate = departureGate
        self.departureTerminal = departureTerminal
        self.departureRunway = departureRunway
        self.departureCheckInDesk = departureCheckInDesk
        self.arrivalGate = arrivalGate
        self.arrivalTerminal = arrivalTerminal
        self.arrivalRunway = arrivalRunway
        self.baggageClaim = baggageClaim
        self.aircraftModel = aircraftModel
        self.aircraftImageUrl = aircraftImageUrl
        self.aircraftAge = aircraftAge
        self.aircraftTypeName = aircraftTypeName
        self.aircraftModelCode = aircraftModelCode
        self.aircraftSeatCount = aircraftSeatCount
        self.aircraftEngineCount = aircraftEngineCount
        self.aircraftEngineType = aircraftEngineType
        self.aircraftIsActive = aircraftIsActive
        self.aircraftIsFreighter = aircraftIsFreighter
        self.aircraftDataVerified = aircraftDataVerified
        self.aircraftManufacturedYear = aircraftManufacturedYear
        self.tailNumber = tailNumber
        self.distanceKm = distanceKm
        self.distanceNm = distanceNm
        self.distanceMiles = distanceMiles
        self.callSign = callSign
        self.statusRawValue = flightStatus.rawValue
        self.aircraftRegistrationDate = aircraftRegistrationDate
    }

    var flightStatus: FlightStatus {
        get { FlightStatus(rawValue: statusRawValue) ?? .onTime }
        set { statusRawValue = newValue.rawValue }
    }

    /// Computed status based on actual timestamps - overrides stored status for accuracy.
    var computedFlightStatus: FlightStatus {
        let now = Date()
        
        // If flight has actually arrived, it's arrived
        if actualArrival != nil {
            return .arrived
        }
        
        // If flight has actually departed, check if it should be arrived based on best arrival estimate
        if actualDeparture != nil {
            // Use effective arrival which accounts for delays: actual > estimated > scheduled
            let arrivalEstimate = effectiveArrival ?? Date.distantFuture
            if now > arrivalEstimate {
                return .arrived
            }
            return .enRoute
        }
        
        // If departure time has passed, flight has departed or is in air
        let departureCutoff = estimatedDeparture ?? revisedDeparture ?? scheduledDeparture
        if now > departureCutoff {
            // Use effective arrival for delayed arrivals
            let arrivalEstimate = effectiveArrival ?? Date.distantFuture
            if now > arrivalEstimate {
                return .arrived
            }
            return .enRoute
        }
        
        // Flight hasn't departed yet
        return flightStatus
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

    /// True when we have definitive arrival confirmation.
    var hasLanded: Bool {
        computedFlightStatus == .arrived || actualArrival != nil
    }

    /// Best arrival time for progress calculation and timeline completion.
    var progressArrival: Date? {
        if hasLanded {
            // actual gate arrival is definitive.
            return actualArrival ?? runwayArrival
        }

        // In-flight endpoint estimation: predicted > estimated > scheduled.
        return predictedArrival ?? estimatedArrival ?? scheduledArrival
    }

    /// Flight progress in the range 0.0–1.0 based on current time relative to
    /// takeoff (or gate departure) and landing prediction.
    /// Returns nil when the flight is not yet trackable (no meaningful arrival time known).
    var flightProgress: Double? {
        let departure = runwayDeparture ?? actualDeparture ?? scheduledDeparture
        guard let arrival = progressArrival else { return nil }
        let total = arrival.timeIntervalSince(departure)
        guard total > 0 else { return nil }

        if hasLanded { return 1.0 }

        let now = Date()
        guard now >= departure else { return 0 }
        guard now <= arrival else { return 1 }
        return now.timeIntervalSince(departure) / total
    }

    /// Best predicted arrival time: prioritizes predictedArrival over estimatedArrival.
    var bestPredictedArrival: Date? {
        predictedArrival ?? estimatedArrival ?? scheduledArrival
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
