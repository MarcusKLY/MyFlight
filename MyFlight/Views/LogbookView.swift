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
    @Query(sort: \Airport.iataCode) private var airports: [Airport]

    @State private var showClearDataAlert = false
    @State private var showClearSuccessAlert = false
    @State private var showImportPicker = false
    @State private var showImportModeDialog = false
    @State private var showImportResultAlert = false
    @State private var importResultMessage = ""
    @State private var importMode: ImportMode = .replace

    private enum ImportMode: String, CaseIterable {
        case replace = "Replace Existing Data"
        case merge = "Merge Into Existing Data"
    }

    // Statistics
    private var totalFlights: Int { flights.count }

    private var upcomingFlights: [Flight] {
        flights.filter { $0.scheduledDeparture >= Date() }
    }

    private var pastFlights: [Flight] {
        flights.filter { $0.scheduledDeparture < Date() }
    }

    private var totalMiles: Int {
        flights.reduce(0) { total, flight in
            total + calculateDistanceMiles(from: flight.origin, to: flight.destination)
        }
    }

    private var totalHours: Int {
        let totalMinutes = flights.compactMap { $0.durationMinutes }.reduce(0, +)
        return totalMinutes / 60
    }

    private var uniqueAirports: Int {
        var airports = Set<String>()
        for flight in flights {
            airports.insert(flight.origin.iataCode)
            airports.insert(flight.destination.iataCode)
        }
        return airports.count
    }

    private var uniqueAirlines: Int {
        Set(flights.map { $0.airline }).count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Stats Card
                    heroCard

                    // Quick Stats Grid
                    quickStatsGrid

                    // Flight Breakdown
                    flightBreakdownSection

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
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showClearDataAlert = true
                        } label: {
                            Label("Clear All Data", systemImage: "trash.fill")
                        }

                        Button {
                            exportBackup()
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
                        Image(systemName: "ellipsis.circle")
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
        }
    }

    // MARK: - Database Management

    private func clearAllData() {
        // Delete all flights
        for flight in flights {
            modelContext.delete(flight)
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
            flights: flights.map { FlightBackup(from: $0) }
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

            try modelContext.save()

            importResultMessage = "Backup imported successfully."
            showImportResultAlert = true
        } catch {
            importResultMessage = "Failed to import backup: \(error.localizedDescription)"
            showImportResultAlert = true
        }
    }

    private struct LogbookBackup: Codable {
        let airports: [AirportBackup]
        let flights: [FlightBackup]
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

#Preview {
    LogbookView()
        .modelContainer(for: [Airport.self, Flight.self], inMemory: true)
}
