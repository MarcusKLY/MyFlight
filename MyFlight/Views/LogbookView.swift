//
//  LogbookView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 24/3/2026.
//

import SwiftUI
import SwiftData
import CoreLocation
import UIKit
import UniformTypeIdentifiers

struct LogbookView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flight.scheduledDeparture, order: .reverse) private var flights: [Flight]
    @Query(sort: \TransitSegment.scheduledDeparture, order: .reverse) private var transitSegments: [TransitSegment]
    @Query(sort: \Airport.iataCode) private var airports: [Airport]

    @State private var showClearDataAlert = false
    @State private var showClearSuccessAlert = false
    @State private var showImportPicker = false
    @State private var showImportModeDialog = false
    @State private var showImportResultAlert = false
    @State private var importResultMessage = ""
    @State private var importMode: ImportMode = .replace
    @State private var showSettings = false
    @State private var selectedYear: Int? = nil  // nil = All Time

    private enum ImportMode: String, CaseIterable {
        case replace = "Replace Existing Data"
        case merge = "Merge Into Existing Data"
    }
    
    // Available years from flights/transit
    private var availableYears: [Int] {
        var allDates: [Date] = []
        allDates.append(contentsOf: flights.map { $0.scheduledDeparture })
        allDates.append(contentsOf: transitSegments.map { $0.scheduledDeparture })
        
        guard !allDates.isEmpty else {
            return [Calendar.current.component(.year, from: Date())]
        }
        
        let oldestDate = allDates.min() ?? Date()
        let oldestYear = Calendar.current.component(.year, from: oldestDate)
        let currentYear = Calendar.current.component(.year, from: Date())
        
        return Array(oldestYear...currentYear).reversed()
    }

    // MARK: - Filtered Data
    
    private var filteredFlights: [Flight] {
        guard let year = selectedYear else { return flights }
        
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date()
        
        return flights.filter { flight in
            flight.scheduledDeparture >= startOfYear && flight.scheduledDeparture < endOfYear
        }
    }
    
    private var filteredTransit: [TransitSegment] {
        guard let year = selectedYear else { return transitSegments }
        
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? Date()
        let endOfYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? Date()
        
        return transitSegments.filter { transit in
            transit.scheduledDeparture >= startOfYear && transit.scheduledDeparture < endOfYear
        }
    }

    // Statistics (now using filtered data)
    private var totalFlights: Int { filteredFlights.count }
    private var totalTransit: Int { filteredTransit.count }
    private var totalTrips: Int { filteredFlights.count + filteredTransit.count }

    private var upcomingFlights: [Flight] {
        filteredFlights.filter { $0.scheduledDeparture >= Date() }
    }

    private var pastFlights: [Flight] {
        filteredFlights.filter { $0.scheduledDeparture < Date() }
    }
    
    private var upcomingTransit: [TransitSegment] {
        filteredTransit.filter { $0.scheduledDeparture >= Date() }
    }
    
    private var pastTransit: [TransitSegment] {
        filteredTransit.filter { $0.scheduledDeparture < Date() }
    }

    private var totalMiles: Int {
        let flightMiles = filteredFlights.reduce(0) { total, flight in
            total + calculateDistanceMiles(from: flight.origin, to: flight.destination)
        }
        let transitMiles = filteredTransit.reduce(into: 0) { total, transit in
            let originLoc = CLLocation(latitude: transit.originLatitude, longitude: transit.originLongitude)
            let destLoc = CLLocation(latitude: transit.destinationLatitude, longitude: transit.destinationLongitude)
            let meters = originLoc.distance(from: destLoc)
            total += Int(meters / 1609.34) // Convert to miles
        }
        return flightMiles + transitMiles
    }

    private var totalHours: Int {
        let flightMinutes = filteredFlights.compactMap { $0.durationMinutes }.reduce(0, +)
        let transitMinutes = filteredTransit.compactMap { $0.durationMinutes }.reduce(0, +)
        return (flightMinutes + transitMinutes) / 60
    }

    private var uniqueAirports: Int {
        var airports = Set<String>()
        for flight in filteredFlights {
            airports.insert(flight.origin.iataCode)
            airports.insert(flight.destination.iataCode)
        }
        return airports.count
    }

    private var uniqueAirlines: Int {
        Set(filteredFlights.map { $0.airline }).count
    }
    
    // MARK: - Enhanced Statistics
    
    private var domesticFlights: Int {
        filteredFlights.filter { flight in
            // Simple heuristic: domestic if origin and destination in same rough region
            // More accurate would be country codes, but IATA doesn't always indicate country
            let originCode = flight.origin.iataCode.prefix(1)
            let destCode = flight.destination.iataCode.prefix(1)
            return originCode == destCode
        }.count
    }
    
    private var internationalFlights: Int {
        totalFlights - domesticFlights
    }
    
    private var longHaulFlights: Int {
        filteredFlights.filter { flight in
            guard let duration = flight.durationMinutes else { return false }
            return duration >= 360 // 6 hours or more
        }.count
    }
    
    private var shortestFlight: Flight? {
        filteredFlights.min { ($0.durationMinutes ?? Int.max) < ($1.durationMinutes ?? Int.max) }
    }
    
    private var longestFlight: Flight? {
        filteredFlights.max { ($0.durationMinutes ?? 0) < ($1.durationMinutes ?? 0) }
    }
    
    private var averageFlightDuration: Int {
        let durations = filteredFlights.compactMap { $0.durationMinutes }
        guard !durations.isEmpty else { return 0 }
        return durations.reduce(0, +) / durations.count
    }
    
    private var topAirlines: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredFlights, by: { $0.airline })
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    private var topAirports: [(code: String, name: String, count: Int)] {
        var airportVisits: [String: (name: String, count: Int)] = [:]
        for flight in filteredFlights {
            let originCode = flight.origin.iataCode
            let destCode = flight.destination.iataCode
            airportVisits[originCode, default: (flight.origin.name, 0)].count += 1
            airportVisits[destCode, default: (flight.destination.name, 0)].count += 1
        }
        return airportVisits.map { (code: $0.key, name: $0.value.name, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    private var topRoutes: [(route: String, count: Int)] {
        let routes = filteredFlights.map { "\($0.origin.iataCode)-\($0.destination.iataCode)" }
        let grouped = Dictionary(grouping: routes, by: { $0 })
        return grouped.map { (route: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    private var seatClassBreakdown: [(seatClass: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredFlights.compactMap { $0.seatClass }, by: { $0.rawValue })
        return grouped.map { (seatClass: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    private var seatPositionBreakdown: [(position: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredFlights.compactMap { $0.seatPosition }, by: { $0.rawValue })
        return grouped.map { (position: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
    
    private var topAircraft: [(model: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredFlights.compactMap { $0.aircraftModel }, by: { $0 })
        return grouped.map { (model: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }
    
    private var uniqueAircraftRegistrations: Int {
        Set(filteredFlights.compactMap { $0.tailNumber }).count
    }
    
    private var transitByType: [(type: String, count: Int, miles: Int)] {
        let grouped = Dictionary(grouping: filteredTransit, by: { $0.transitType.rawValue })
        return grouped.map { type, segments in
            let miles = segments.reduce(0) { total, transit in
                let originLoc = CLLocation(latitude: transit.originLatitude, longitude: transit.originLongitude)
                let destLoc = CLLocation(latitude: transit.destinationLatitude, longitude: transit.destinationLongitude)
                let meters = originLoc.distance(from: destLoc)
                return total + Int(meters / 1609.34)
            }
            return (type: type, count: segments.count, miles: miles)
        }.sorted { $0.count > $1.count }
    }
    
    private var topTransitOperators: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: filteredTransit, by: { $0.operatorName })
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Period Filter
                    timePeriodPicker
                    
                    // Hero Stats Card
                    heroCard

                    // Quick Stats Grid
                    quickStatsGrid

                    // Flight Breakdown
                    flightBreakdownSection
                    
                    // Enhanced Statistics Sections
                    if !filteredFlights.isEmpty {
                        detailedFlightStatsSection
                        topRankingsSection
                        
                        if !seatClassBreakdown.isEmpty || !seatPositionBreakdown.isEmpty {
                            seatStatsSection
                        }
                        
                        if !topAircraft.isEmpty {
                            aircraftStatsSection
                        }
                    }
                    
                    if !filteredTransit.isEmpty {
                        transitStatsSection
                    }

                    // Recent Activity
                    if !pastFlights.isEmpty {
                        recentActivitySection
                    }

                    // Upcoming Section
                    if !upcomingFlights.isEmpty {
                        upcomingSection
                    }

                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Logbook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showClearDataAlert = true
                        } label: {
                            Label("Clear All Data", systemImage: "trash.fill")
                        }

                        Menu {
                            Button {
                                exportBackupCSV()
                            } label: {
                                Label("Export as CSV", systemImage: "doc.text")
                            }
                            
                            Button {
                                exportBackup()
                            } label: {
                                Label("Export as JSON", systemImage: "doc.badge.gearshape")
                            }
                        } label: {
                            Label("Export Backup", systemImage: "square.and.arrow.up")
                        }

                        Button {
                            showImportModeDialog = true
                        } label: {
                            Label("Import Backup", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            exportDatabaseInfo()
                        } label: {
                            Label("Export Debug Info", systemImage: "doc.on.doc")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                    }
                }
            }
            .alert("Clear All Data?", isPresented: $showClearDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear Everything", role: .destructive) {
                    clearAllData()
                }
            } message: {
                Text("This will permanently delete all flights and airports. This action cannot be undone.")
            }
            .alert("Data Cleared", isPresented: $showClearSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("All flight and airport data has been cleared successfully.")
            }
            .alert("Import Result", isPresented: $showImportResultAlert) {
                Button("OK") { }
            } message: {
                Text(importResultMessage)
            }
            .confirmationDialog("Import Backup", isPresented: $showImportModeDialog, titleVisibility: .visible) {
                Button("Replace Existing Data") {
                    importMode = .replace
                    showImportPicker = true
                }
                Button("Merge Into Existing Data") {
                    importMode = .merge
                    showImportPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .sheet(isPresented: $showImportPicker) {
                DocumentPickerView(supportedTypes: ["public.json"]) { url in
                    showImportPicker = false
                    if let url {
                        importBackup(from: url, merge: importMode == .merge)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    // MARK: - Database Management

    private func clearAllData() {
        // Delete all flights
        for flight in flights {
            modelContext.delete(flight)
        }
        
        // Delete all transit segments
        for transit in transitSegments {
            modelContext.delete(transit)
        }

        // Delete all airports
        for airport in airports {
            modelContext.delete(airport)
        }

        // Save and show confirmation
        do {
            try modelContext.save()
            showClearSuccessAlert = true
        } catch {
            print("Error clearing data: \(error)")
        }
    }

    private func exportDatabaseInfo() {
        let info = """
        Database Debug Info
        ===================
        Total Flights: \(flights.count)
        Total Airports: \(airports.count)

        Flights:
        \(flights.map { "\($0.flightNumber) - \($0.origin.iataCode) to \($0.destination.iataCode)" }.joined(separator: "\n"))

        Airports:
        \(airports.map { "\($0.iataCode) - \($0.name)" }.joined(separator: "\n"))
        """
        print(info)
        UIPasteboard.general.string = info
    }

    private func exportBackup() {
        let backup = LogbookBackup(
            airports: airports.map { AirportBackup(from: $0) },
            flights: flights.map { FlightBackup(from: $0) },
            transitSegments: transitSegments.map { TransitBackup(from: $0) }
        )

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(backup)

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("MyFlight-Logbook-Backup-\(Date().timeIntervalSince1970).json")
            try data.write(to: tempURL, options: .atomic)

            let activity = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                root.present(activity, animated: true, completion: nil)
            }
        } catch {
            importResultMessage = "Failed to export backup: \(error.localizedDescription)"
            showImportResultAlert = true
        }
    }
    
    private func exportBackupCSV() {
        do {
            let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
            
            // Create CSV files
            let flightsCSV = generateFlightsCSV()
            let transitCSV = generateTransitCSV()
            let airportsCSV = generateAirportsCSV()
            
            // Save to temporary directory
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("MyFlight-CSV-\(timestamp)")
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            let flightsURL = tempDir.appendingPathComponent("flights.csv")
            let transitURL = tempDir.appendingPathComponent("transit.csv")
            let airportsURL = tempDir.appendingPathComponent("airports.csv")
            
            try flightsCSV.write(to: flightsURL, atomically: true, encoding: .utf8)
            try transitCSV.write(to: transitURL, atomically: true, encoding: .utf8)
            try airportsCSV.write(to: airportsURL, atomically: true, encoding: .utf8)
            
            // Share all three files
            let activity = UIActivityViewController(
                activityItems: [flightsURL, transitURL, airportsURL],
                applicationActivities: nil
            )
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
               let root = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                root.present(activity, animated: true)
            }
        } catch {
            importResultMessage = "Failed to export CSV: \(error.localizedDescription)"
            showImportResultAlert = true
        }
    }
    
    private func generateFlightsCSV() -> String {
        var csv = "Flight Number,Airline,IATA,Origin,Destination,Scheduled Departure,Scheduled Arrival,Status,Aircraft,Tail Number,Departure Gate,Departure Terminal,Arrival Gate,Arrival Terminal,Seat Number,Seat Class,Seat Position\n"
        
        for flight in flights.sorted(by: { $0.scheduledDeparture < $1.scheduledDeparture }) {
            let row = [
                escapeCSV(flight.flightNumber),
                escapeCSV(flight.airline),
                escapeCSV(flight.airlineIATA ?? ""),
                escapeCSV(flight.origin.iataCode),
                escapeCSV(flight.destination.iataCode),
                ISO8601DateFormatter().string(from: flight.scheduledDeparture),
                ISO8601DateFormatter().string(from: flight.scheduledArrival ?? flight.scheduledDeparture),
                escapeCSV(flight.flightStatus.rawValue),
                escapeCSV(flight.aircraftModel ?? ""),
                escapeCSV(flight.tailNumber ?? ""),
                escapeCSV(flight.departureGate ?? ""),
                escapeCSV(flight.departureTerminal ?? ""),
                escapeCSV(flight.arrivalGate ?? ""),
                escapeCSV(flight.arrivalTerminal ?? ""),
                escapeCSV(flight.seatNumber ?? ""),
                escapeCSV(flight.seatClass?.rawValue ?? ""),
                escapeCSV(flight.seatPosition?.rawValue ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func generateTransitCSV() -> String {
        var csv = "Transit Type,Operator,Route Number,Origin,Destination,Origin Lat,Origin Lon,Dest Lat,Dest Lon,Scheduled Departure,Scheduled Arrival,Notes\n"
        
        for transit in transitSegments.sorted(by: { $0.scheduledDeparture < $1.scheduledDeparture }) {
            let row = [
                escapeCSV(transit.transitType.rawValue),
                escapeCSV(transit.operatorName),
                escapeCSV(transit.routeNumber),
                escapeCSV(transit.originName),
                escapeCSV(transit.destinationName),
                String(transit.originLatitude),
                String(transit.originLongitude),
                String(transit.destinationLatitude),
                String(transit.destinationLongitude),
                ISO8601DateFormatter().string(from: transit.scheduledDeparture),
                ISO8601DateFormatter().string(from: transit.scheduledArrival),
                escapeCSV(transit.notes ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func generateAirportsCSV() -> String {
        var csv = "IATA Code,Name,Latitude,Longitude,Timezone\n"
        
        for airport in airports.sorted(by: { $0.iataCode < $1.iataCode }) {
            let row = [
                escapeCSV(airport.iataCode),
                escapeCSV(airport.name),
                String(airport.latitude),
                String(airport.longitude),
                escapeCSV(airport.timezone ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        return csv
    }
    
    private func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func importBackup(from url: URL, merge: Bool = false) {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let backup = try decoder.decode(LogbookBackup.self, from: data)

            // Replace or merge
            if !merge {
                clearAllData()
            }

            // Keep airport map by iata for linking flights
            var airportByIATA: [String: Airport] = [:]
            for airportBackup in backup.airports {
                if airportByIATA[airportBackup.iataCode] != nil { continue }
                let airport = Airport(
                    iataCode: airportBackup.iataCode,
                    name: airportBackup.name,
                    latitude: airportBackup.latitude,
                    longitude: airportBackup.longitude,
                    timezone: airportBackup.timezone
                )
                modelContext.insert(airport)
                airportByIATA[airport.iataCode] = airport
            }

            // Insert flights
            for flightBackup in backup.flights {
                guard let origin = airportByIATA[flightBackup.originIATACode],
                      let destination = airportByIATA[flightBackup.destinationIATACode] else {
                    continue
                }

                let status = FlightStatus(rawValue: flightBackup.flightStatus) ?? .onTime
                let flight = Flight(
                    flightNumber: flightBackup.flightNumber,
                    airline: flightBackup.airline,
                    airlineIATA: flightBackup.airlineIATA,
                    origin: origin,
                    destination: destination,
                    scheduledDeparture: flightBackup.scheduledDeparture,
                    revisedDeparture: flightBackup.revisedDeparture,
                    estimatedDeparture: flightBackup.estimatedDeparture,
                    actualDeparture: flightBackup.actualDeparture,
                    runwayDeparture: flightBackup.runwayDeparture,
                    runwayArrival: flightBackup.runwayArrival,
                    revisedArrival: flightBackup.revisedArrival,
                    estimatedArrival: flightBackup.estimatedArrival,
                    predictedArrival: flightBackup.predictedArrival,
                    scheduledArrival: flightBackup.scheduledArrival,
                    actualArrival: flightBackup.actualArrival,
                    departureGate: flightBackup.departureGate,
                    departureTerminal: flightBackup.departureTerminal,
                    departureRunway: flightBackup.departureRunway,
                    departureCheckInDesk: flightBackup.departureCheckInDesk,
                    arrivalGate: flightBackup.arrivalGate,
                    arrivalTerminal: flightBackup.arrivalTerminal,
                    arrivalRunway: flightBackup.arrivalRunway,
                    baggageClaim: flightBackup.baggageClaim,
                    aircraftModel: flightBackup.aircraftModel,
                    aircraftImageUrl: flightBackup.aircraftImageUrl,
                    aircraftAge: flightBackup.aircraftAge,
                    tailNumber: flightBackup.tailNumber,
                    distanceKm: flightBackup.distanceKm,
                    distanceNm: flightBackup.distanceNm,
                    distanceMiles: flightBackup.distanceMiles,
                    callSign: flightBackup.callSign,
                    flightStatus: status
                )
                modelContext.insert(flight)
            }
            
            // Insert transit segments (optional for backward compatibility)
            if let transitBackups = backup.transitSegments {
                for transitBackup in transitBackups {
                    guard let transitType = TransitType(rawValue: transitBackup.transitType) else {
                        continue
                    }
                    
                    let transit = TransitSegment(
                        transitType: transitType,
                        routeNumber: transitBackup.routeNumber,
                        operatorName: transitBackup.operatorName,
                        originName: transitBackup.originName,
                        originLatitude: transitBackup.originLatitude,
                        originLongitude: transitBackup.originLongitude,
                        destinationName: transitBackup.destinationName,
                        destinationLatitude: transitBackup.destinationLatitude,
                        destinationLongitude: transitBackup.destinationLongitude,
                        scheduledDeparture: transitBackup.scheduledDeparture,
                        scheduledArrival: transitBackup.scheduledArrival,
                        estimatedDeparture: transitBackup.estimatedDeparture,
                        actualDeparture: transitBackup.actualDeparture,
                        notes: transitBackup.notes
                    )
                    modelContext.insert(transit)
                }
            }

            try modelContext.save()

            importResultMessage = "Successfully imported \(backup.flights.count) flights, \(backup.transitSegments?.count ?? 0) transit segments, and \(backup.airports.count) airports."
            showImportResultAlert = true
        } catch {
            importResultMessage = "Failed to import backup: \(error.localizedDescription)"
            showImportResultAlert = true
        }
    }

    private struct LogbookBackup: Codable {
        let airports: [AirportBackup]
        let flights: [FlightBackup]
        let transitSegments: [TransitBackup]?  // Optional for backward compatibility
    }

    private struct AirportBackup: Codable {
        let iataCode: String
        let name: String
        let latitude: Double
        let longitude: Double
        let timezone: String?

        init(from airport: Airport) {
            self.iataCode = airport.iataCode
            self.name = airport.name
            self.latitude = airport.latitude
            self.longitude = airport.longitude
            self.timezone = airport.timezone
        }
    }

    private struct FlightBackup: Codable {
        let flightNumber: String
        let airline: String
        let airlineIATA: String?
        let originIATACode: String
        let destinationIATACode: String
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
        let distanceKm: Double?
        let distanceNm: Double?
        let distanceMiles: Double?
        let callSign: String?
        let flightStatus: String

        init(from flight: Flight) {
            self.flightNumber = flight.flightNumber
            self.airline = flight.airline
            self.airlineIATA = flight.airlineIATA
            self.originIATACode = flight.origin.iataCode
            self.destinationIATACode = flight.destination.iataCode
            self.scheduledDeparture = flight.scheduledDeparture
            self.revisedDeparture = flight.revisedDeparture
            self.estimatedDeparture = flight.estimatedDeparture
            self.actualDeparture = flight.actualDeparture
            self.runwayDeparture = flight.runwayDeparture
            self.runwayArrival = flight.runwayArrival
            self.revisedArrival = flight.revisedArrival
            self.estimatedArrival = flight.estimatedArrival
            self.predictedArrival = flight.predictedArrival
            self.scheduledArrival = flight.scheduledArrival
            self.actualArrival = flight.actualArrival
            self.departureGate = flight.departureGate
            self.departureTerminal = flight.departureTerminal
            self.departureRunway = flight.departureRunway
            self.departureCheckInDesk = flight.departureCheckInDesk
            self.arrivalGate = flight.arrivalGate
            self.arrivalTerminal = flight.arrivalTerminal
            self.arrivalRunway = flight.arrivalRunway
            self.baggageClaim = flight.baggageClaim
            self.aircraftModel = flight.aircraftModel
            self.aircraftImageUrl = flight.aircraftImageUrl
            self.aircraftAge = flight.aircraftAge
            self.tailNumber = flight.tailNumber
            self.distanceKm = flight.distanceKm
            self.distanceNm = flight.distanceNm
            self.distanceMiles = flight.distanceMiles
            self.callSign = flight.callSign
            self.flightStatus = flight.flightStatus.rawValue
        }
    }
    
    private struct TransitBackup: Codable {
        let transitType: String
        let operatorName: String
        let routeNumber: String
        let originName: String
        let originLatitude: Double
        let originLongitude: Double
        let destinationName: String
        let destinationLatitude: Double
        let destinationLongitude: Double
        let scheduledDeparture: Date
        let scheduledArrival: Date
        let estimatedDeparture: Date?
        let actualDeparture: Date?
        let notes: String?
        
        init(from transit: TransitSegment) {
            self.transitType = transit.transitType.rawValue
            self.operatorName = transit.operatorName
            self.routeNumber = transit.routeNumber
            self.originName = transit.originName
            self.originLatitude = transit.originLatitude
            self.originLongitude = transit.originLongitude
            self.destinationName = transit.destinationName
            self.destinationLatitude = transit.destinationLatitude
            self.destinationLongitude = transit.destinationLongitude
            self.scheduledDeparture = transit.scheduledDeparture
            self.scheduledArrival = transit.scheduledArrival
            self.estimatedDeparture = transit.estimatedDeparture
            self.actualDeparture = transit.actualDeparture
            self.notes = transit.notes
        }
    }

    // MARK: - Time Period Picker
    
    private var timePeriodPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Time button
                Button(action: { selectedYear = nil }) {
                    Text("All Time")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(selectedYear == nil ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedYear == nil ? Color.blue : Color(.secondarySystemGroupedBackground))
                        .cornerRadius(6)
                }
                
                // Year buttons
                ForEach(availableYears, id: \.self) { year in
                    Button(action: { selectedYear = year }) {
                        Text("\(year)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(selectedYear == year ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedYear == year ? Color.blue : Color(.secondarySystemGroupedBackground))
                            .cornerRadius(6)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Enhanced Statistics Sections
    
    private var detailedFlightStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight Statistics")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                MiniStatCard(label: "Domestic", value: "\(domesticFlights)", icon: "house.fill", color: .blue)
                MiniStatCard(label: "International", value: "\(internationalFlights)", icon: "airplane.departure", color: .cyan)
                MiniStatCard(label: "Long-Haul (6h+)", value: "\(longHaulFlights)", icon: "timer", color: .orange)
                MiniStatCard(label: "Avg Duration", value: formatMinutes(averageFlightDuration), icon: "clock.fill", color: .purple)
            }
            
            if let shortest = shortestFlight {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundStyle(.green)
                    Text("Shortest: \(shortest.origin.iataCode)→\(shortest.destination.iataCode)")
                        .font(.caption)
                    Spacer()
                    Text(formatMinutes(shortest.durationMinutes ?? 0))
                        .font(.caption.bold())
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }
            
            if let longest = longestFlight {
                HStack {
                    Image(systemName: "airplane.circle")
                        .foregroundStyle(.indigo)
                    Text("Longest: \(longest.origin.iataCode)→\(longest.destination.iataCode)")
                        .font(.caption)
                    Spacer()
                    Text(formatMinutes(longest.durationMinutes ?? 0))
                        .font(.caption.bold())
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var topRankingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Top Rankings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
            
            // Top Airlines
            if !topAirlines.isEmpty {
                RankingCard(title: "Airlines", icon: "airplane.circle", items: topAirlines.map { "\($0.name) (\($0.count))" })
            }
            
            // Top Airports
            if !topAirports.isEmpty {
                RankingCard(title: "Airports", icon: "building.2", items: topAirports.map { "\($0.code) - \($0.name) (\($0.count))" })
            }
            
            // Top Routes
            if !topRoutes.isEmpty {
                RankingCard(title: "Routes", icon: "arrow.left.and.right", items: topRoutes.map { "\($0.route) (\($0.count))" })
            }
        }
    }
    
    private var seatStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seat Preferences")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
            
            if !seatClassBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Class")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    ForEach(seatClassBreakdown, id: \.seatClass) { item in
                        HStack {
                            Text(item.seatClass)
                            Spacer()
                            Text("\(item.count)")
                                .fontWeight(.semibold)
                            Text("(\(Int(Double(item.count) / Double(totalFlights) * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            
            if !seatPositionBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    ForEach(seatPositionBreakdown, id: \.position) { item in
                        HStack {
                            Text(item.position)
                            Spacer()
                            Text("\(item.count)")
                                .fontWeight(.semibold)
                            Text("(\(Int(Double(item.count) / Double(totalFlights) * 100))%)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var aircraftStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Aircraft")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
            
            HStack {
                MiniStatCard(label: "Unique Types", value: "\(topAircraft.count)", icon: "airplane", color: .blue)
                MiniStatCard(label: "Unique Tails", value: "\(uniqueAircraftRegistrations)", icon: "number", color: .cyan)
            }
            
            if !topAircraft.isEmpty {
                RankingCard(title: "Most Flown Aircraft", icon: "airplane", items: topAircraft.map { "\($0.model) (\($0.count))" })
            }
        }
    }
    
    private var transitStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transit Statistics")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .padding(.horizontal, 4)
            
            ForEach(transitByType, id: \.type) { item in
                HStack {
                    Image(systemName: transitIcon(for: item.type))
                        .foregroundStyle(transitColor(for: item.type))
                    Text(item.type)
                        .fontWeight(.medium)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(item.count) trips")
                            .font(.caption.bold())
                        Text("\(item.miles) miles")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            
            if !topTransitOperators.isEmpty {
                RankingCard(title: "Top Operators", icon: "bus.fill", items: topTransitOperators.map { "\($0.name) (\($0.count))" })
            }
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
    
    private func transitIcon(for type: String) -> String {
        switch type.lowercased() {
        case "bus": return "bus.fill"
        case "ferry": return "ferry.fill"
        case "train": return "tram.fill"
        default: return "mappin.circle"
        }
    }
    
    private func transitColor(for type: String) -> Color {
        switch type.lowercased() {
        case "bus": return .orange
        case "ferry": return .teal
        case "train": return .purple
        default: return .gray
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: 16) {
            // Main number with animation
            VStack(spacing: 4) {
                Text("\(totalMiles.formatted())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .cyan, .teal],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .contentTransition(.numericText())

                Text("MILES FLOWN")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(2)
            }

            // Equivalent stats
            HStack(spacing: 24) {
                equivalentStat(
                    value: String(format: "%.1fx", Double(totalMiles) / 24901),
                    label: "Around Earth"
                )

                Divider()
                    .frame(height: 30)

                equivalentStat(
                    value: "\(totalHours)",
                    label: "Hours Airborne"
                )

                Divider()
                    .frame(height: 30)

                equivalentStat(
                    value: "\(totalFlights)",
                    label: "Flights"
                )
                
                Divider()
                    .frame(height: 30)
                
                equivalentStat(
                    value: "\(totalTransit)",
                    label: "Transit"
                )
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [.blue.opacity(0.3), .cyan.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func equivalentStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Quick Stats Grid

    private var quickStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                icon: "building.2",
                iconColor: .purple,
                value: "\(uniqueAirports)",
                label: "Airports Visited"
            )

            StatCard(
                icon: "airplane.circle",
                iconColor: .orange,
                value: "\(uniqueAirlines)",
                label: "Airlines Flown"
            )

            StatCard(
                icon: "calendar.badge.checkmark",
                iconColor: .green,
                value: "\(pastFlights.count)",
                label: "Completed"
            )

            StatCard(
                icon: "calendar.badge.clock",
                iconColor: .blue,
                value: "\(upcomingFlights.count)",
                label: "Upcoming"
            )
        }
    }

    // MARK: - Flight Breakdown Section

    private var flightBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Flight Breakdown")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 8) {
                BreakdownRow(
                    label: "Upcoming Flights",
                    value: upcomingFlights.count,
                    total: totalFlights,
                    color: .blue
                )

                BreakdownRow(
                    label: "Past Flights",
                    value: pastFlights.count,
                    total: totalFlights,
                    color: .gray
                )

                // Status breakdown
                let onTime = flights.filter { $0.flightStatus == .onTime }.count
                let delayed = flights.filter { $0.flightStatus == .delayed }.count
                let cancelled = flights.filter { $0.flightStatus == .cancelled }.count

                if onTime > 0 {
                    BreakdownRow(
                        label: "On Time",
                        value: onTime,
                        total: totalFlights,
                        color: .green
                    )
                }

                if delayed > 0 {
                    BreakdownRow(
                        label: "Delayed",
                        value: delayed,
                        total: totalFlights,
                        color: .orange
                    )
                }

                if cancelled > 0 {
                    BreakdownRow(
                        label: "Cancelled",
                        value: cancelled,
                        total: totalFlights,
                        color: .red
                    )
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Recent Activity Section

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Flights")
                    .font(.headline)

                Spacer()

                Text("\(pastFlights.count) total")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(pastFlights.prefix(3)) { flight in
                    RecentFlightRow(flight: flight)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Coming Up")
                    .font(.headline)

                Spacer()

                if let next = upcomingFlights.sorted(by: { $0.scheduledDeparture < $1.scheduledDeparture }).first {
                    Text(countdownString(for: next))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }

            VStack(spacing: 8) {
                ForEach(upcomingFlights.sorted { $0.scheduledDeparture < $1.scheduledDeparture }.prefix(3)) { flight in
                    UpcomingFlightRow(flight: flight)
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    private func calculateDistanceMiles(from origin: Airport, to destination: Airport) -> Int {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)

        // Distance in meters, convert to miles
        let meters = originLocation.distance(from: destLocation)
        return Int(meters / 1609.34)
    }

    private func countdownString(for flight: Flight) -> String {
        let interval = flight.scheduledDeparture.timeIntervalSinceNow
        guard interval > 0 else { return "Departing now" }

        let hours = Int(interval) / 3600
        let days = hours / 24

        if days > 0 {
            return "Next flight in \(days)d"
        } else if hours > 0 {
            return "Next flight in \(hours)h"
        } else {
            let minutes = (Int(interval) % 3600) / 60
            return "Next flight in \(minutes)m"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(iconColor.gradient)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Breakdown Row

struct BreakdownRow: View {
    let label: String
    let value: Int
    let total: Int
    let color: Color

    private var percentage: Double {
        guard total > 0 else { return 0 }
        return Double(value) / Double(total)
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text("(\(Int(percentage * 100))%)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(color.gradient)
                        .frame(width: geo.size.width * percentage, height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Ranking Card

struct RankingCard: View {
    let title: String
    let icon: String
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.subheadline.bold())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack {
                        Text("#\(index + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 25, alignment: .leading)
                        Text(item)
                            .font(.caption)
                        Spacer()
                    }
                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Recent Flight Row

struct RecentFlightRow: View {
    let flight: Flight

    var body: some View {
        HStack(spacing: 12) {
            // Route
            HStack(spacing: 6) {
                Text(flight.origin.iataCode)
                    .font(.system(size: 14, weight: .bold))

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)

                Text(flight.destination.iataCode)
                    .font(.system(size: 14, weight: .bold))
            }

            Spacer()

            // Flight info
            VStack(alignment: .trailing, spacing: 2) {
                Text(flight.flightNumber)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Text(relativeDate(flight.scheduledDeparture))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Upcoming Flight Row

struct UpcomingFlightRow: View {
    let flight: Flight

    var body: some View {
        HStack(spacing: 12) {
            // Date badge
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.blue)

                Text(monthAbbr)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            // Route
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(flight.origin.iataCode)
                        .font(.system(size: 14, weight: .bold))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(flight.destination.iataCode)
                        .font(.system(size: 14, weight: .bold))
                }

                Text("\(flight.airline) \(flight.flightNumber)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Time
            Text(flight.formattedDeparture())
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }

    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: flight.scheduledDeparture)
    }

    private var monthAbbr: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: flight.scheduledDeparture).uppercased()
    }
}

private struct DocumentPickerView: UIViewControllerRepresentable {
    var supportedTypes: [String]
    var onPick: (URL?) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types = supportedTypes.compactMap { UTType($0) }
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        controller.delegate = context.coordinator
        controller.allowsMultipleSelection = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL?) -> Void

        init(onPick: @escaping (URL?) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls.first)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onPick(nil)
        }
    }
}

// MARK: - LogbookSheetView for Pull-up Sheet Presentation

struct LogbookSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        LogbookView()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
    }
}

#Preview {
    LogbookView()
        .modelContainer(for: [Airport.self, Flight.self], inMemory: true)
}
