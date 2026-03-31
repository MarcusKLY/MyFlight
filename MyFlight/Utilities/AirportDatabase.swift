import Foundation

struct AirportInfo: Codable, Identifiable {
    let icao: String
    let iata: String
    let name: String
    let city: String
    let state: String?
    let country: String
    let elevation: Int?
    let lat: Double
    let lon: Double
    let tz: String

    var id: String { icao }

    var displayName: String {
        if let state = state, !state.isEmpty {
            return "\(iata) - \(name), \(state), \(country)"
        }
        return "\(iata) - \(name), \(country)"
    }
}

class AirportDatabase {
    static let shared = AirportDatabase()

    private var allAirports: [AirportInfo] = []
    private var airportsByIATA: [String: AirportInfo] = [:]
    private var searchCache: [String: [AirportInfo]] = [:]

    private init() {
        loadAirports()
    }

    private func loadAirports() {
        guard let url = Bundle.main.url(forResource: "iata-airports", withExtension: "json") else {
            print("AirportDatabase: iata-airports.json not found")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            allAirports = try JSONDecoder().decode([AirportInfo].self, from: data)

            // Build IATA lookup dictionary
            for airport in allAirports {
                if !airport.iata.isEmpty {
                    airportsByIATA[airport.iata.uppercased()] = airport
                }
            }

            print("AirportDatabase: Loaded \(allAirports.count) airports")
        } catch {
            print("AirportDatabase: Failed to load airports - \(error.localizedDescription)")
        }
    }

    func search(query: String) -> [AirportInfo] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return [] }

        // Check cache first
        if let cached = searchCache[trimmed] {
            return cached
        }

        // Search by IATA code first (exact prefix match)
        var results = allAirports.filter { airport in
            airport.iata.uppercased().starts(with: trimmed)
        }

        // If not enough results, search by name and city
        if results.count < 5 {
            let additionalResults = allAirports.filter { airport in
                (airport.name.uppercased().contains(trimmed) ||
                 airport.city.uppercased().contains(trimmed)) &&
                !results.contains(where: { $0.id == airport.id })
            }
            results.append(contentsOf: additionalResults)
        }

        // Sort: IATA matches first, then by frequency of use, then alphabetically
        results.sort { a, b in
            let aIsIATAMatch = a.iata.uppercased().starts(with: trimmed)
            let bIsIATAMatch = b.iata.uppercased().starts(with: trimmed)

            if aIsIATAMatch != bIsIATAMatch {
                return aIsIATAMatch
            }
            return a.iata < b.iata
        }

        // Limit to 10 results and cache
        let limited = Array(results.prefix(10))
        searchCache[trimmed] = limited
        return limited
    }

    func airport(byIATA iata: String) -> AirportInfo? {
        let normalized = iata.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return airportsByIATA[normalized]
    }
}
