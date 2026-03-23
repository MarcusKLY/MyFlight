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
    var arrivalGate: String?
    var baggageClaim: String?
    private var statusRawValue: String

    init(
        flightNumber: String,
        airline: String,
        origin: Airport,
        destination: Airport,
        scheduledDeparture: Date,
        actualDeparture: Date? = nil,
        arrivalGate: String? = nil,
        baggageClaim: String? = nil,
        flightStatus: FlightStatus = .onTime
    ) {
        self.id = UUID()
        self.flightNumber = flightNumber
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.scheduledDeparture = scheduledDeparture
        self.actualDeparture = actualDeparture
        self.arrivalGate = arrivalGate
        self.baggageClaim = baggageClaim
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
}
