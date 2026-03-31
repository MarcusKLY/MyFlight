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
    let revisedDeparture: Date?
    let estimatedDeparture: Date?
    let actualDeparture: Date?
    let runwayDeparture: Date?
    let runwayArrival: Date?
    let revisedArrival: Date?
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
    let aircraftImageUrl: String?
    let aircraftAge: String?
    let tailNumber: String?
    let aircraftTypeName: String?
    let aircraftModelCode: String?
    let aircraftSeatCount: Int?
    let aircraftEngineCount: Int?
    let aircraftEngineType: String?
    let aircraftIsActive: Bool?
    let aircraftIsFreighter: Bool?
    let aircraftDataVerified: Bool?
    let aircraftManufacturedYear: Int?
    let aircraftRegistrationDate: String?
    let distanceKm: Double?
    let distanceNm: Double?
    let distanceMiles: Double?
    let callSign: String?
    let status: FlightStatus
}

enum FlightLookupError: LocalizedError {
    case missingAPIKey
    case rateLimitExceeded
    case noFlightFound
    case invalidResponse
    case networkTimeout

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Flight API key missing. Add FLIGHT_API_KEYS or FLIGHT_API_KEY in Info.plist or project build settings."
        case .rateLimitExceeded:
            return "All configured RapidAPI keys hit rate limits. Add more keys in FLIGHT_API_KEYS."
        case .noFlightFound:
            return "No flight data found for the provided flight number and date."
        case .invalidResponse:
            return "Received invalid data from flight provider."
        case .networkTimeout:
            return "Network request timed out. Please check your connection and try again."
        }
    }
}

struct AircraftExtraInfo {
    let age: String?
    let typeName: String?
    let modelCode: String?
    let seatCount: Int?
    let engineCount: Int?
    let engineType: String?
    let isActive: Bool?
    let isFreighter: Bool?
    let isVerified: Bool?
    let manufacturedYear: Int?
    let registrationDate: String?
}

enum FlightLookupService {
    /// Looks up a flight using the AeroDataBox API (via RapidAPI).
    /// Requires `FLIGHT_API_KEYS` (comma-separated) or `FLIGHT_API_KEY` in Info.plist.
    static func lookup(flightNumber: String, date: Date) async throws -> FlightLookupResult {
        let rapidAPIKeys = rapidAPIKeysFromConfig()
        guard !rapidAPIKeys.isEmpty else {
            throw FlightLookupError.missingAPIKey
        }

        // AeroDataBox expects the flight number without internal spaces (e.g. "CX886" not "CX 886").
        let normalizedNumber = flightNumber
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
        let selectedDateKey = DateFormatter.apiDateLocal.string(from: date)
        let dateString = selectedDateKey

        guard let url = URL(string: "https://aerodatabox.p.rapidapi.com/flights/number/\(normalizedNumber)/\(dateString)?withAircraftImage=true") else {
            throw FlightLookupError.invalidResponse
        }

        let (data, httpResponse, usedRapidKey) = try await performAeroDataBoxRequest(url: url, apiKeys: rapidAPIKeys)

        let decoded = try JSONDecoder().decode([AeroFlightItem].self, from: data)
        guard !decoded.isEmpty else {
            throw FlightLookupError.noFlightFound
        }

        let datedCandidates = decoded.filter { item in
            let localMatch = item.departure?.scheduledTime?.local.map { $0.contains(selectedDateKey) } ?? false
            let utcMatch = item.departure?.scheduledTime?.utc.map { $0.contains(selectedDateKey) } ?? false
            return localMatch || utcMatch
        }

        let pool = datedCandidates
        guard let selected = pool.min(by: { lhs, rhs in
            let lhsPriority = statusSelectionPriority(rawStatus: lhs.status)
            let rhsPriority = statusSelectionPriority(rawStatus: rhs.status)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }

            let lhsDep = parseAeroDate(lhs.departure?.scheduledTime?.utc) ?? Date.distantFuture
            let rhsDep = parseAeroDate(rhs.departure?.scheduledTime?.utc) ?? Date.distantFuture
            let lhsDistance = abs(lhsDep.timeIntervalSinceNow)
            let rhsDistance = abs(rhsDep.timeIntervalSinceNow)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }

            return lhsDep < rhsDep
        }) else {
            throw FlightLookupError.noFlightFound
        }

        let scheduledDep = parseAeroDate(selected.departure?.scheduledTime?.utc) ?? date
        let revisedDep = parseAeroDate(selected.departure?.revisedTime?.utc)
        let estimatedDep = parseAeroDate(selected.departure?.estimatedTime?.utc)
        let actualDep = parseAeroDate(selected.departure?.actualTime?.utc)
        let runwayDep = parseAeroDate(selected.departure?.runwayTime?.utc)

        let scheduledArr = parseAeroDate(selected.arrival?.scheduledTime?.utc)
        let revisedArr = parseAeroDate(selected.arrival?.revisedTime?.utc)
        let estimatedArr = parseAeroDate(selected.arrival?.estimatedTime?.utc)
        let predictedArr = parseAeroDate(selected.arrival?.predictedTime?.utc)
        let runwayArr = parseAeroDate(selected.arrival?.runwayTime?.utc)
        let actualArr = parseAeroDate(selected.arrival?.actualTime?.utc)

        // Fallback: if scheduledArr is nil, use predictedArr or estimatedArr as the scheduled arrival
        let effectiveScheduledArr = scheduledArr ?? predictedArr ?? estimatedArr
        let aircraftImageUrl = selected.aircraft?.image?.url
        async let aircraftExtraInfo = fetchAircraftExtraInfoIfAvailable(
            apiKeys: rapidAPIKeys,
            registration: selected.aircraft?.reg
        )

        // Determine status based on API status + departure data.
        let status: FlightStatus
        let statusString = (selected.status ?? "").lowercased()

        let computedDelayMinutes: Int? = {
            if let actual = actualDep {
                return Int(actual.timeIntervalSince(scheduledDep) / 60)
            }
            if let revised = revisedDep {
                return Int(revised.timeIntervalSince(scheduledDep) / 60)
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
        print("FlightLookupService: selectedDateKey=\(selectedDateKey), decoded=\(decoded.count), datedCandidates=\(datedCandidates.count), selectedStatus=\(selected.status ?? "unknown"), selectedDepLocal=\(selected.departure?.scheduledTime?.local ?? "nil"), statusString=\(statusString), scheduled=\(scheduledDep), estimated=\(String(describing: estimatedDep)), actual=\(String(describing: actualDep)), runway=\(String(describing: selected.departure?.runwayTime?.utc)), arrivalScheduled=\(String(describing: selected.arrival?.scheduledTime?.utc)), arrivalEstimated=\(String(describing: selected.arrival?.estimatedTime?.utc)), arrivalPredicted=\(String(describing: selected.arrival?.predictedTime?.utc)), arrivalActual=\(String(describing: selected.arrival?.actualTime?.utc)), computedDelay=\(String(describing: computedDelayMinutes)), resolvedStatus=\(status), requestStatus=\(httpResponse.statusCode), keySuffix=\(String(usedRapidKey.suffix(4))))")
        #endif

        return FlightLookupResult(
            flightNumber: selected.number ?? flightNumber,
            airline: selected.airline?.name ?? "Unknown Airline",
            airlineIATA: selected.airline?.iata,
            originIATACode: selected.departure?.airport?.iata ?? "",
            destinationIATACode: selected.arrival?.airport?.iata ?? "",
            originName: selected.departure?.airport?.name,
            destinationName: selected.arrival?.airport?.name,
            originLatitude: selected.departure?.airport?.location?.lat,
            originLongitude: selected.departure?.airport?.location?.lon,
            destinationLatitude: selected.arrival?.airport?.location?.lat,
            destinationLongitude: selected.arrival?.airport?.location?.lon,
            originTimezone: selected.departure?.airport?.timeZone,
            destinationTimezone: selected.arrival?.airport?.timeZone,
            scheduledDeparture: scheduledDep,
            revisedDeparture: revisedDep,
            estimatedDeparture: estimatedDep,
            actualDeparture: actualDep,
            runwayDeparture: runwayDep,
            runwayArrival: runwayArr,
            revisedArrival: revisedArr,
            estimatedArrival: estimatedArr,
            predictedArrival: predictedArr,
            scheduledArrival: effectiveScheduledArr,
            actualArrival: actualArr,
            departureGate: selected.departure?.gate,
            departureTerminal: selected.departure?.terminal,
            departureRunway: selected.departure?.runway,
            departureCheckInDesk: selected.departure?.checkInDesk,
            arrivalGate: selected.arrival?.gate,
            arrivalTerminal: selected.arrival?.terminal,
            arrivalRunway: selected.arrival?.runway,
            baggageClaim: selected.arrival?.baggageBelt,
            aircraftModel: selected.aircraft?.model,
            aircraftImageUrl: aircraftImageUrl,
            aircraftAge: await aircraftExtraInfo?.age,
            tailNumber: selected.aircraft?.reg,
            aircraftTypeName: await aircraftExtraInfo?.typeName,
            aircraftModelCode: await aircraftExtraInfo?.modelCode,
            aircraftSeatCount: await aircraftExtraInfo?.seatCount,
            aircraftEngineCount: await aircraftExtraInfo?.engineCount,
            aircraftEngineType: await aircraftExtraInfo?.engineType,
            aircraftIsActive: await aircraftExtraInfo?.isActive,
            aircraftIsFreighter: await aircraftExtraInfo?.isFreighter,
            aircraftDataVerified: await aircraftExtraInfo?.isVerified,
            aircraftManufacturedYear: await aircraftExtraInfo?.manufacturedYear,
            aircraftRegistrationDate: await aircraftExtraInfo?.registrationDate,
            distanceKm: selected.greatCircleDistance?.km,
            distanceNm: selected.greatCircleDistance?.nm,
            distanceMiles: selected.greatCircleDistance?.mile,
            callSign: selected.callSign,
            status: status
        )
    }

    private static func statusSelectionPriority(rawStatus: String?) -> Int {
        let status = (rawStatus ?? "").lowercased()
        if status.contains("arriv") || status.contains("land") {
            return 1
        }
        return 0
    }

    private static func rapidAPIKeysFromConfig() -> [String] {
        if let csv = Bundle.main.object(forInfoDictionaryKey: "FLIGHT_API_KEYS") as? String {
            let keys = csv
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !keys.isEmpty { return keys }
        }

        if let single = Bundle.main.object(forInfoDictionaryKey: "FLIGHT_API_KEY") as? String {
            let key = single.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty { return [key] }
        }

        return []
    }

    private static let timeoutSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15.0 // 15 seconds total request timeout
        config.timeoutIntervalForResource = 20.0 // 20 seconds total resource timeout
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()
    
    private static func performAeroDataBoxRequest(url: URL, apiKeys: [String]) async throws -> (Data, HTTPURLResponse, String) {
        var lastRateLimited = false
        var lastError: Error?

        for (index, apiKey) in apiKeys.enumerated() {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
            request.setValue("aerodatabox.p.rapidapi.com", forHTTPHeaderField: "X-RapidAPI-Host")
            request.timeoutInterval = 15.0

            do {
                let (data, response) = try await timeoutSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw FlightLookupError.invalidResponse
                }

                if httpResponse.statusCode == 429 {
                    #if DEBUG
                    print("FlightLookupService: 429 from \(url.absoluteString), rotating key index \(index)")
                    #endif
                    lastRateLimited = true
                    let hasNextKey = index < apiKeys.count - 1
                    if hasNextKey {
                        continue
                    }
                    break
                }

                guard 200..<300 ~= httpResponse.statusCode else {
                    #if DEBUG
                    print("FlightLookupService: non-2xx \(httpResponse.statusCode) from \(url.absoluteString)")
                    #endif
                    throw FlightLookupError.invalidResponse
                }

                return (data, httpResponse, apiKey)
            } catch let error as URLError where error.code == .timedOut {
                lastError = FlightLookupError.networkTimeout
                #if DEBUG
                print("FlightLookupService: timeout on key index \(index), trying next key if available")
                #endif
                let hasNextKey = index < apiKeys.count - 1
                if !hasNextKey { break }
                continue
            } catch {
                lastError = error
                let hasNextKey = index < apiKeys.count - 1
                if !hasNextKey { break }
            }
        }

        if let timeoutError = lastError as? FlightLookupError, case .networkTimeout = timeoutError {
            throw FlightLookupError.networkTimeout
        }
        if lastRateLimited {
            throw FlightLookupError.rateLimitExceeded
        }
        throw lastError ?? FlightLookupError.invalidResponse
    }

    private static func fetchAircraftImageURL(apiKeys: [String], registration: String?) async -> String? {
        #if DEBUG
        print("FlightLookupService.fetchAircraftImageURL: tail=\(registration ?? "nil")")
        #endif
        guard let registration,
              !registration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let encodedReg = registration.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://aerodatabox.p.rapidapi.com/aircrafts/reg/\(encodedReg)/image/image") else {
            #if DEBUG
            print("FlightLookupService.fetchAircraftImageURL: skipped (missing/invalid registration)")
            #endif
            return nil
        }

        do {
            let (data, httpResponse, usedKey) = try await performAeroDataBoxRequest(url: url, apiKeys: apiKeys)
            #if DEBUG
            print("FlightLookupService.fetchAircraftImageURL: status=\(httpResponse.statusCode), contentType=\(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "nil"), bytes=\(data.count), keySuffix=\(String(usedKey.suffix(4)))")
            #endif

            if let mimeType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
               mimeType.lowercased().contains("image") {
                #if DEBUG
                print("FlightLookupService.fetchAircraftImageURL: direct image response")
                #endif
                return url.absoluteString
            }

            let object = try JSONSerialization.jsonObject(with: data)
            let extracted = extractURLString(from: object)
            #if DEBUG
            if extracted == nil {
                let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? "<non-utf8 body>"
                print("FlightLookupService.fetchAircraftImageURL: no URL extracted; bodyPreview=\(bodyPreview)")
            } else {
                print("FlightLookupService.fetchAircraftImageURL: extractedURL=\(extracted!)")
            }
            #endif
            return extracted
        } catch {
            #if DEBUG
            print("FlightLookupService.fetchAircraftImageURL: error=\(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private struct AeroDataBoxAircraftLookup: Codable {
        let ageYears: Double?
        let deliveryDate: String?
        let rolloutDate: String?
        let firstFlightDate: String?
        let registrationDate: String?
        let typeName: String?
        let modelCode: String?
        let numSeats: Int?
        let numEngines: Int?
        let engineType: String?
        let active: Bool?
        let isFreighter: Bool?
        let verified: Bool?
    }

    static func lookupAircraftExtraInfo(registration: String) async throws -> AircraftExtraInfo {
        let rapidAPIKeys = rapidAPIKeysFromConfig()
        guard !rapidAPIKeys.isEmpty else {
            throw FlightLookupError.missingAPIKey
        }

        let normalizedRegistration = registration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRegistration.isEmpty,
              let encodedReg = normalizedRegistration.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://aerodatabox.p.rapidapi.com/aircrafts/reg/\(encodedReg)") else {
            throw FlightLookupError.invalidResponse
        }

        let (data, _, _) = try await performAeroDataBoxRequest(url: url, apiKeys: rapidAPIKeys)
        let details = try JSONDecoder().decode(AeroDataBoxAircraftLookup.self, from: data)

        return AircraftExtraInfo(
            age: formattedAircraftAge(ageYears: details.ageYears, deliveryDateString: details.deliveryDate),
            typeName: details.typeName,
            modelCode: details.modelCode,
            seatCount: details.numSeats,
            engineCount: details.numEngines,
            engineType: details.engineType,
            isActive: details.active,
            isFreighter: details.isFreighter,
            isVerified: details.verified,
            manufacturedYear: extractManufacturedYear(rolloutDate: details.rolloutDate, firstFlightDate: details.firstFlightDate, deliveryDate: details.deliveryDate),
            registrationDate: details.registrationDate
        )
    }

    private static func fetchAircraftExtraInfoIfAvailable(
        apiKeys: [String],
        registration: String?
    ) async -> AircraftExtraInfo? {
        guard let registration = registration?.trimmingCharacters(in: .whitespacesAndNewlines),
              !registration.isEmpty else {
            return nil
        }

        do {
            return try await lookupAircraftExtraInfo(registration: registration)
        } catch {
            #if DEBUG
            print("FlightLookupService.fetchAircraftExtraInfoIfAvailable: error=\(error.localizedDescription)")
            #endif
            return nil
        }
    }

    private static func formattedAircraftAge(ageYears: Double?, deliveryDateString: String?) -> String? {
        if let ageYears, ageYears >= 0 {
            let rounded = (ageYears * 10).rounded() / 10
            return String(format: "%.1f years", rounded)
        }

        if let deliveryDateString,
           let deliveryDate = parseDeliveryDate(deliveryDateString) {
            let now = Date()
            let seconds = max(0, now.timeIntervalSince(deliveryDate))
            let years = seconds / (365.25 * 24 * 60 * 60)
            let rounded = (years * 10).rounded() / 10
            return String(format: "%.1f years", rounded)
        }

        return nil
    }

    private static func extractManufacturedYear(rolloutDate: String?, firstFlightDate: String?, deliveryDate: String?) -> Int? {
        if let year = yearPrefix(from: rolloutDate) { return year }
        if let year = yearPrefix(from: firstFlightDate) { return year }
        if let year = yearPrefix(from: deliveryDate) { return year }
        return nil
    }

    private static func yearPrefix(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let digits = raw.prefix(4)
        guard let year = Int(digits), year > 1900 else { return nil }
        return year
    }

    private static func parseDeliveryDate(_ string: String) -> Date? {
        let formats = ["yyyy-MM-dd", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"]
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }

        if #available(iOS 13.0, macOS 10.15, *) {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: string) {
                return date
            }

            iso.formatOptions = [.withInternetDateTime]
            return iso.date(from: string)
        }

        return nil
    }

    private static func extractURLString(from object: Any) -> String? {
        if let string = object as? String,
           let url = URL(string: string),
           let scheme = url.scheme,
           (scheme == "http" || scheme == "https") {
            return string
        }

        if let dict = object as? [String: Any] {
            let preferredKeys = ["url", "image", "imageUrl", "webUrl", "src", "href"]
            for key in preferredKeys {
                if let value = dict[key], let extracted = extractURLString(from: value) {
                    return extracted
                }
            }
            for value in dict.values {
                if let extracted = extractURLString(from: value) {
                    return extracted
                }
            }
        }

        if let array = object as? [Any] {
            for item in array {
                if let extracted = extractURLString(from: item) {
                    return extracted
                }
            }
        }

        return nil
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
    let image: AeroAircraftImage?
}

private struct AeroAircraftImage: Codable {
    let url: String?
    let webUrl: String?
    let author: String?
    let title: String?
    let description: String?
    let license: String?
    let htmlAttributions: [String]?
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
    static let apiDateLocal: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
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
