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
    let airlineIATA: String?
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
    let estimatedDeparture: Date?
    let actualDeparture: Date?
    let runwayDeparture: Date?
    let runwayArrival: Date?
    let estimatedArrival: Date?
    let predictedArrival: Date?
    let scheduledArrival: Date?
    let actualArrival: Date?
    let departureGate: String?
    let departureTerminal: String?
    let departureRunway: String?
    let departureCheckInDesk: String?
    let arrivalGate: String?
    let arrivalTerminal: String?
    let arrivalRunway: String?
    let baggageClaim: String?
    let aircraftModel: String?
    let tailNumber: String?
    let distanceKm: Double?
    let distanceNm: Double?
    let distanceMiles: Double?
    let callSign: String?
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

        let scheduledDep = parseAeroDate(first.departure?.scheduledTime?.utc) ?? date
        let revisedDep = parseAeroDate(first.departure?.revisedTime?.utc)
        let estimatedDep = parseAeroDate(first.departure?.estimatedTime?.utc)
        let actualDep = parseAeroDate(first.departure?.actualTime?.utc) ?? revisedDep
        let runwayDep = parseAeroDate(first.departure?.runwayTime?.utc)

        let scheduledArr = parseAeroDate(first.arrival?.scheduledTime?.utc)
        let revisedArr = parseAeroDate(first.arrival?.revisedTime?.utc)
        let estimatedArr = parseAeroDate(first.arrival?.estimatedTime?.utc)
        let predictedArr = parseAeroDate(first.arrival?.predictedTime?.utc)
        let runwayArr = parseAeroDate(first.arrival?.runwayTime?.utc)
        let actualArr = parseAeroDate(first.arrival?.actualTime?.utc) ?? runwayArr

        // Determine status based on API status + departure data.
        let status: FlightStatus
        let statusString = (first.status ?? "").lowercased()

        let computedDelayMinutes: Int? = {
            if let actual = actualDep {
                return Int(actual.timeIntervalSince(scheduledDep) / 60)
            }
            if let estimated = estimatedDep {
                return Int(estimated.timeIntervalSince(scheduledDep) / 60)
            }
            return nil
        }()

        if statusString.contains("cancel") {
            status = .cancelled
        } else if statusString.contains("arriv") || statusString.contains("land") {
            status = .arrived
        } else if statusString.contains("enroute") || statusString.contains("en route") {
            status = .enRoute
        } else if statusString.contains("depart") {
            status = .departed
        } else if statusString.contains("expect") {
            status = .expected
        } else if statusString.contains("delay") {
            status = .delayed
        } else if let arrival = actualArr ?? runwayArr, arrival < Date() {
            status = .arrived
        } else if let delay = computedDelayMinutes {
            status = delay > 10 ? .delayed : .onTime
        } else {
            // When no explicit delay indicator from API, assume on time (could be stale).
            status = .onTime
        }

        #if DEBUG
        print("FlightLookupService: statusString=\(statusString), scheduled=\(scheduledDep), estimated=\(String(describing: estimatedDep)), actual=\(String(describing: actualDep)), runway=\(String(describing: first.departure?.runwayTime?.utc)), arrivalScheduled=\(String(describing: first.arrival?.scheduledTime?.utc)), arrivalEstimated=\(String(describing: first.arrival?.estimatedTime?.utc)), arrivalPredicted=\(String(describing: first.arrival?.predictedTime?.utc)), arrivalActual=\(String(describing: first.arrival?.actualTime?.utc)), computedDelay=\(String(describing: computedDelayMinutes)), resolvedStatus=\(status)")
        #endif

        return FlightLookupResult(
            flightNumber: first.number ?? flightNumber,
            airline: first.airline?.name ?? "Unknown Airline",
            airlineIATA: first.airline?.iata,
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
            estimatedDeparture: revisedDep ?? estimatedDep,
            actualDeparture: actualDep ?? revisedDep ?? revisedDep,
            runwayDeparture: runwayDep,
            runwayArrival: runwayArr,
            estimatedArrival: revisedArr ?? estimatedArr,
            predictedArrival: predictedArr,
            scheduledArrival: scheduledArr,
            actualArrival: actualArr,
            departureGate: first.departure?.gate,
            departureTerminal: first.departure?.terminal,
            departureRunway: first.departure?.runway,
            departureCheckInDesk: first.departure?.checkInDesk,
            arrivalGate: first.arrival?.gate,
            arrivalTerminal: first.arrival?.terminal,
            arrivalRunway: first.arrival?.runway,
            baggageClaim: first.arrival?.baggageBelt,
            aircraftModel: first.aircraft?.model,
            tailNumber: first.aircraft?.reg,
            distanceKm: first.greatCircleDistance?.km,
            distanceNm: first.greatCircleDistance?.nm,
            distanceMiles: first.greatCircleDistance?.mile,
            callSign: first.callSign,
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

private struct AeroFlightItem: Codable {
    let number: String?
    let status: String?
    let callSign: String?
    let airline: AeroAirline?
    let aircraft: AeroAircraft?
    let departure: AeroEndpoint?
    let arrival: AeroEndpoint?
    let greatCircleDistance: AeroDistance?
}

private struct AeroAirline: Codable {
    let name: String?
    let iata: String?
    let icao: String?
}

private struct AeroAircraft: Codable {
    let reg: String?
    let model: String?
    let modeS: String?
}

private struct AeroDistance: Codable {
    let km: Double?
    let mile: Double?
    let nm: Double?
    let meter: Double?
    let feet: Double?
}

private struct AeroEndpoint: Codable {
    let airport: AeroAirport?
    let scheduledTime: AeroTime?
    let revisedTime: AeroTime?
    let estimatedTime: AeroTime?
    let predictedTime: AeroTime?
    let actualTime: AeroTime?
    let runwayTime: AeroTime?
    let terminal: String?
    let gate: String?
    let runway: String?
    let checkInDesk: String?
    let baggageBelt: String?

    enum CodingKeys: String, CodingKey {
        case airport, terminal, gate, runway, checkInDesk, baggageBelt
        case scheduledTime, revisedTime, estimatedTime, predictedTime, actualTime, runwayTime
    }
}

private struct AeroAirport: Codable {
    let iata: String?
    let name: String?
    let timeZone: String?
    let location: AeroLocation?
}

private struct AeroLocation: Codable {
    let lat: Double?
    let lon: Double?
}

private struct AeroTime: Codable {
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
