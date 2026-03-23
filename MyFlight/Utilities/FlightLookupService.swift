//
//  FlightLookupService.swift
//  MyFlight
//
//  Created by Kam Long Yin on 24/3/2026.
//

import Foundation

struct FlightLookupResult {
    let flightNumber: String
    let airline: String
    let originIATACode: String
    let destinationIATACode: String
    let originName: String?
    let destinationName: String?
    let originLatitude: Double?
    let originLongitude: Double?
    let destinationLatitude: Double?
    let destinationLongitude: Double?
    let originTimezone: String?
    let destinationTimezone: String?
    let scheduledDeparture: Date
    let actualDeparture: Date?
    let scheduledArrival: Date?
    let actualArrival: Date?
    let departureGate: String?
    let departureTerminal: String?
    let arrivalGate: String?
    let arrivalTerminal: String?
    let baggageClaim: String?
    let aircraftModel: String?
    let tailNumber: String?
    let status: FlightStatus
}

enum FlightLookupError: LocalizedError {
    case missingAPIKey
    case noFlightFound
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Flight API key missing. Add FLIGHT_API_KEY in Info.plist or project build settings."
        case .noFlightFound:
            return "No flight data found for the provided flight number and date."
        case .invalidResponse:
            return "Received invalid data from flight provider."
        }
    }
}

enum FlightLookupService {
    /// Looks up a flight using the AeroDataBox API (via RapidAPI).
    /// Requires `FLIGHT_API_KEY` in Info.plist set to your RapidAPI key.
    static func lookup(flightNumber: String, date: Date) async throws -> FlightLookupResult {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "FLIGHT_API_KEY") as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FlightLookupError.missingAPIKey
        }

        // AeroDataBox expects the flight number without internal spaces (e.g. "CX886" not "CX 886").
        let normalizedNumber = flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        let dateString = DateFormatter.apiDate.string(from: date)

        guard let url = URL(string: "https://aerodatabox.p.rapidapi.com/flights/number/\(normalizedNumber)/\(dateString)") else {
            throw FlightLookupError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw FlightLookupError.invalidResponse
        }

        let decoded = try JSONDecoder().decode([AeroFlightItem].self, from: data)
        guard let first = decoded.first else {
            throw FlightLookupError.noFlightFound
        }

        let status: FlightStatus
        switch (first.status ?? "").lowercased() {
        case "cancelled", "cancelleduncertain":
            status = .cancelled
        case "delayed":
            status = .delayed
        default:
            status = .onTime
        }

        let scheduledDep = parseAeroDate(first.departure?.scheduledTime?.utc) ?? date
        let actualDep = parseAeroDate(first.departure?.actualTime?.utc)
        let scheduledArr = parseAeroDate(first.arrival?.scheduledTime?.utc)
        let actualArr = parseAeroDate(first.arrival?.actualTime?.utc)

        return FlightLookupResult(
            flightNumber: first.number ?? flightNumber,
            airline: first.airline?.name ?? "Unknown Airline",
            originIATACode: first.departure?.airport?.iata ?? "",
            destinationIATACode: first.arrival?.airport?.iata ?? "",
            originName: first.departure?.airport?.name,
            destinationName: first.arrival?.airport?.name,
            originLatitude: first.departure?.airport?.location?.lat,
            originLongitude: first.departure?.airport?.location?.lon,
            destinationLatitude: first.arrival?.airport?.location?.lat,
            destinationLongitude: first.arrival?.airport?.location?.lon,
            originTimezone: first.departure?.airport?.timeZone,
            destinationTimezone: first.arrival?.airport?.timeZone,
            scheduledDeparture: scheduledDep,
            actualDeparture: actualDep,
            scheduledArrival: scheduledArr,
            actualArrival: actualArr,
            departureGate: first.departure?.gate,
            departureTerminal: first.departure?.terminal,
            arrivalGate: first.arrival?.gate,
            arrivalTerminal: first.arrival?.terminal,
            baggageClaim: first.arrival?.baggageBelt,
            aircraftModel: first.aircraft?.model,
            tailNumber: first.aircraft?.reg,
            status: status
        )
    }

    private static func parseAeroDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        // AeroDataBox UTC times are formatted as "2024-01-15 01:45Z"
        return DateFormatter.aeroDateTime.date(from: string)
    }
}

// MARK: - AeroDataBox response models

private struct AeroFlightItem: Decodable {
    let number: String?
    let status: String?
    let airline: AeroAirline?
    let aircraft: AeroAircraft?
    let departure: AeroEndpoint?
    let arrival: AeroEndpoint?
}

private struct AeroAirline: Decodable {
    let name: String?
}

private struct AeroAircraft: Decodable {
    let reg: String?
    let model: String?
}

private struct AeroEndpoint: Decodable {
    let airport: AeroAirport?
    let scheduledTime: AeroTime?
    let actualTime: AeroTime?
    let terminal: String?
    let gate: String?
    let baggageBelt: String?

    enum CodingKeys: String, CodingKey {
        case airport, terminal, gate, baggageBelt
        case scheduledTime, actualTime
    }
}

private struct AeroAirport: Decodable {
    let iata: String?
    let name: String?
    let timeZone: String?
    let location: AeroLocation?
}

private struct AeroLocation: Decodable {
    let lat: Double?
    let lon: Double?
}

private struct AeroTime: Decodable {
    let utc: String?
    let local: String?
}

private extension DateFormatter {
    static let apiDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Parses AeroDataBox UTC timestamps: "2024-01-15 01:45Z"
    static let aeroDateTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd HH:mmX"
        return f
    }()
}
