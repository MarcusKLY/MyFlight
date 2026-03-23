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
    let scheduledDeparture: Date
    let actualDeparture: Date?
    let arrivalGate: String?
    let baggageClaim: String?
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
    // Example provider endpoint using AviationStack-style payload.
    static func lookup(flightNumber: String, date: Date) async throws -> FlightLookupResult {
        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "FLIGHT_API_KEY") as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FlightLookupError.missingAPIKey
        }

        var components = URLComponents(string: "https://api.aviationstack.com/v1/flights")
        let dateString = DateFormatter.apiDate.string(from: date)
        components?.queryItems = [
            URLQueryItem(name: "access_key", value: apiKey),
            URLQueryItem(name: "flight_iata", value: flightNumber),
            URLQueryItem(name: "flight_date", value: dateString)
        ]

        guard let url = components?.url else {
            throw FlightLookupError.invalidResponse
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
            throw FlightLookupError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(AviationStackResponse.self, from: data)
        guard let first = decoded.data.first else {
            throw FlightLookupError.noFlightFound
        }

        let status: FlightStatus
        switch first.flightStatus.lowercased() {
        case "cancelled":
            status = .cancelled
        case "delayed":
            status = .delayed
        default:
            status = .onTime
        }

        let parsedScheduled = DateFormatter.apiDateTime.date(from: first.departure.scheduled ?? "") ?? date
        let parsedActual = DateFormatter.apiDateTime.date(from: first.departure.actual ?? "")

        return FlightLookupResult(
            flightNumber: first.flight.iata ?? flightNumber,
            airline: first.airline.name ?? "Unknown Airline",
            originIATACode: first.departure.iata ?? "",
            destinationIATACode: first.arrival.iata ?? "",
            scheduledDeparture: parsedScheduled,
            actualDeparture: parsedActual,
            arrivalGate: first.arrival.gate,
            baggageClaim: first.arrival.baggage,
            status: status
        )
    }
}

private struct AviationStackResponse: Decodable {
    let data: [AviationFlightItem]
}

private struct AviationFlightItem: Decodable {
    let flightStatus: String
    let airline: Airline
    let flight: FlightInfo
    let departure: AirportEvent
    let arrival: AirportEvent

    enum CodingKeys: String, CodingKey {
        case flightStatus = "flight_status"
        case airline
        case flight
        case departure
        case arrival
    }
}

private struct Airline: Decodable {
    let name: String?
}

private struct FlightInfo: Decodable {
    let iata: String?
}

private struct AirportEvent: Decodable {
    let iata: String?
    let scheduled: String?
    let actual: String?
    let gate: String?
    let baggage: String?
}

private extension DateFormatter {
    static let apiDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    static let apiDateTime: DateFormatter = {
        let formatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"

        return dateFormatter
    }()
}
