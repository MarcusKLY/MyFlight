//
//  FlightData.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import Foundation
import SwiftData

struct FlightSeedData {
    static let airportDefinitions: [(code: String, name: String, latitude: Double, longitude: Double)] = [
        ("HKG", "Hong Kong International", 22.3080, 113.9185),
        ("HEL", "Helsinki-Vantaa", 60.3166, 25.0432),
        ("LIS", "Humberto Delgado Lisbon", 38.7742, -9.1342),
        ("RAK", "Marrakech Menara", 31.6087, -8.0195)
    ]

    static func seedIfNeeded(in context: ModelContext) {
        let existingFlights = (try? context.fetch(FetchDescriptor<Flight>())) ?? []
        guard existingFlights.isEmpty else {
            return
        }

        var airportByCode: [String: Airport] = [:]
        for definition in airportDefinitions {
            let airport = Airport(
                iataCode: definition.code,
                name: definition.name,
                latitude: definition.latitude,
                longitude: definition.longitude
            )
            context.insert(airport)
            airportByCode[definition.code] = airport
        }

        let now = Date()
        let flights: [Flight] = [
            Flight(
                flightNumber: "CX886",
                airline: "Cathay Pacific",
                origin: airportByCode["HKG"]!,
                destination: airportByCode["HEL"]!,
                scheduledDeparture: Calendar.current.date(byAdding: .day, value: -30, to: now) ?? now,
                actualDeparture: Calendar.current.date(byAdding: .day, value: -30, to: now),
                arrivalGate: "A8",
                baggageClaim: "12",
                flightStatus: .onTime
            ),
            Flight(
                flightNumber: "AY12",
                airline: "Finnair",
                origin: airportByCode["HEL"]!,
                destination: airportByCode["LIS"]!,
                scheduledDeparture: Calendar.current.date(byAdding: .day, value: -25, to: now) ?? now,
                actualDeparture: Calendar.current.date(byAdding: .day, value: -25, to: now),
                arrivalGate: "B4",
                baggageClaim: "6",
                flightStatus: .delayed
            ),
            Flight(
                flightNumber: "AT714",
                airline: "Royal Air Maroc",
                origin: airportByCode["RAK"]!,
                destination: airportByCode["HEL"]!,
                scheduledDeparture: Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now,
                actualDeparture: nil,
                arrivalGate: "C2",
                baggageClaim: nil,
                flightStatus: .onTime
            )
        ]

        for flight in flights {
            context.insert(flight)
        }

        try? context.save()
    }

    static func defaultAirports(from airports: [Airport]) -> [Airport] {
        let sorted = airports.sorted { $0.iataCode < $1.iataCode }
        if !sorted.isEmpty {
            return sorted
        }
        return airportDefinitions.map {
            Airport(iataCode: $0.code, name: $0.name, latitude: $0.latitude, longitude: $0.longitude)
        }
    }
}
