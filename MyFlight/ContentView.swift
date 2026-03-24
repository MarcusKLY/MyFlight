//
//  ContentView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import SwiftUI
import MapKit
import UIKit
import SwiftData
import Combine

// MARK: - Main App Entry Point with TabView Architecture

struct ContentView: View {
    var body: some View {
        MainTabView()
    }
}

// MARK: - TabView Architecture

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LiveMapTab()
                .tabItem {
                    Label("Live Map", systemImage: "map.fill")
                }
                .tag(0)

            LogbookView()
                .tabItem {
                    Label("Logbook", systemImage: "book.closed.fill")
                }
                .tag(1)
        }
        .tint(.blue)
    }
}

// MARK: - Live Map Tab (Primary Interface)

struct LiveMapTab: View {
    enum ActiveSheet: Identifiable, Equatable {
        case flightList
        case addFlight
        case flightDetail(Flight)

        var id: String {
            switch self {
            case .flightList:
                return "flightList"
            case .addFlight:
                return "addFlight"
            case .flightDetail(let flight):
                return "flightDetail-\(flight.id.uuidString)"
            }
        }

        static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
            switch (lhs, rhs) {
            case (.flightList, .flightList), (.addFlight, .addFlight):
                return true
            case (.flightDetail(let a), .flightDetail(let b)):
                return a.id == b.id
            default:
                return false
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flight.scheduledDeparture, order: .reverse) private var flights: [Flight]
    @Query(sort: \Airport.iataCode) private var airports: [Airport]
    @State private var selectedFlight: Flight?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var activeSheet: ActiveSheet? = .flightList
    @State private var sheetDetent: PresentationDetent = .fraction(0.12) // Start collapsed
    @State private var mapStyleMode: FlightMapStyleMode = .mutedStandard
    @State private var showClearDataAlert = false
    @State private var showClearSuccessAlert = false
    @State private var debugCopied = false

    // Haptic feedback generators
    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let deleteHaptic = UINotificationFeedbackGenerator()

    // Next upcoming flight for T-Minus countdown
    private var nextUpcomingFlight: Flight? {
        flights
            .filter { $0.scheduledDeparture > Date() }
            .sorted { $0.scheduledDeparture < $1.scheduledDeparture }
            .first
    }

    var body: some View {
        ZStack {
            // Full-screen map
            MapViewContainer(
                flights: flights,
                position: $mapPosition,
                selectedFlight: $selectedFlight,
                mapStyleMode: mapStyleMode
            )
            .ignoresSafeArea()

            // Minimal floating controls overlay
            VStack {
                // Top bar - only show when sheet is collapsed or dismissed
                HStack {
                    // T-Minus Countdown Widget (only visible when sheet is small)
                    if let nextFlight = nextUpcomingFlight, sheetDetent == .fraction(0.12) {
                        TMinusCountdownView(flight: nextFlight)
                            .onTapGesture {
                                selectFlightWithAnimation(nextFlight)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Map style toggle
                    FloatingButton(systemImage: mapStyleMode == .mutedStandard ? "map" : "globe.americas") {
                        mapStyleMode.toggle()
                    }

                    // Add flight button
                    FloatingButton(systemImage: "plus") {
                        activeSheet = .addFlight
                    }

                    // Show flight list button / close button when list is open
                    if activeSheet == .flightList {
                        FloatingButton(systemImage: "xmark", isClose: true) {
                            activeSheet = nil
                        }
                    } else {
                        FloatingButton(systemImage: "list.bullet") {
                            activeSheet = .flightList
                            sheetDetent = .fraction(0.33)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.22), value: activeSheet)

                // Selected flight action bar (only visible when sheet is small)
                if selectedFlight != nil, sheetDetent == .fraction(0.12) {
                    HStack {
                        Spacer()
                        ActionChip(title: "Details", icon: "info.circle") {
                            // switch to flight detail sheet (single sheet model)
                            if let selectedFlight {
                                activeSheet = .flightDetail(selectedFlight)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
        }
        // Single sheet handling for all sheet states (prevents multiple-sheets warning)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .flightList:
                FlightListSheet(
                    flights: flights,
                    selectedFlight: $selectedFlight,
                    onSelectFlight: { flight in
                        selectFlightWithAnimation(flight)
                        // Collapse sheet when flight is selected to see map
                        sheetDetent = .fraction(0.12)
                        activeSheet = nil
                    },
                    onDeleteFlight: { flight in
                        safeDeleteFlight(flight)
                    },
                    onAddFlight: {
                        activeSheet = .addFlight
                    }
                )
                .presentationDetents(
                    [.fraction(0.33), .medium, .large],
                    selection: $sheetDetent
                )
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .onAppear {
                    sheetDetent = .fraction(0.33)
                }

            case .flightDetail(let flight):
                FlightDetailView(flight: flight)

            case .addFlight:
                AddFlightSheet(airports: FlightSeedData.defaultAirports(from: airports)) { draft in
                    let origin = upsertAirport(
                        code: draft.originCode,
                        fallbackName: draft.originName,
                        latitude: draft.originLatitude,
                        longitude: draft.originLongitude,
                        timezone: draft.originTimezone
                    )
                    let destination = upsertAirport(
                        code: draft.destinationCode,
                        fallbackName: draft.destinationName,
                        latitude: draft.destinationLatitude,
                        longitude: draft.destinationLongitude,
                        timezone: draft.destinationTimezone
                    )

                    let flight = Flight(
                        flightNumber: draft.flightNumber,
                        airline: draft.airline,
                        origin: origin,
                        destination: destination,
                        scheduledDeparture: draft.scheduledDeparture,
                        estimatedDeparture: draft.estimatedDeparture,
                        actualDeparture: draft.actualDeparture,
                        runwayDeparture: draft.runwayDeparture,
                        runwayArrival: draft.runwayArrival,
                        estimatedArrival: draft.estimatedArrival,
                        scheduledArrival: draft.scheduledArrival,
                        actualArrival: draft.actualArrival,
                        departureGate: draft.departureGate,
                        departureTerminal: draft.departureTerminal,
                        arrivalGate: draft.arrivalGate,
                        arrivalTerminal: draft.arrivalTerminal,
                        baggageClaim: draft.baggageClaim,
                        aircraftModel: draft.aircraftModel,
                        tailNumber: draft.tailNumber,
                        flightStatus: draft.flightStatus
                    )
                    modelContext.insert(flight)
                    try? modelContext.save()

                    selectionHaptic.impactOccurred()
                    activeSheet = nil
                }

            }
        }
        .onChange(of: selectedFlight) { _, _ in
            // No longer need to hide sheet - it stays visible
        }
        .onAppear {
            selectionHaptic.prepare()
            deleteHaptic.prepare()
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
        .onAppear {
            print("LiveMapTab appeared - Flights: \(flights.count), Airports: \(airports.count)")
        }
    }

    // MARK: - Cinematic Map Swooping (UX Upgrade 2)

    private func selectFlightWithAnimation(_ flight: Flight) {
        // Haptic feedback
        selectionHaptic.impactOccurred()

        // Calculate region that frames both airports with 20% padding
        let originCoord = flight.origin.coordinate
        let destCoord = flight.destination.coordinate

        let midLat = (originCoord.latitude + destCoord.latitude) / 2
        let midLon = (originCoord.longitude + destCoord.longitude) / 2
        let center = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

        // Calculate span with 20% padding
        let latDelta = abs(destCoord.latitude - originCoord.latitude) * 1.4 // 20% padding = 1.2, extra for UI = 1.4
        let lonDelta = abs(destCoord.longitude - originCoord.longitude) * 1.4

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 5),
                longitudeDelta: max(lonDelta, 5)
            )
        )

        // Cinematic spring animation for swooping effect
        withAnimation(.interpolatingSpring(stiffness: 50, damping: 10)) {
            selectedFlight = flight
            mapPosition = .region(region)
        }
    }

    // MARK: - SwiftData Safe Deletion (Bug Fix 2)

    private func safeDeleteFlight(_ flight: Flight) {
        print("safeDeleteFlight called for: \(flight.flightNumber)")

        // Haptic feedback
        deleteHaptic.notificationOccurred(.warning)

        // Capture the flight ID before any changes
        let flightId = flight.id
        print("Flight ID captured: \(flightId)")

        // CRITICAL: Clear selection FIRST if this flight is selected
        if selectedFlight?.id == flightId {
            selectedFlight = nil
            print("Cleared selected flight")
        }

        // Delete directly - don't rely on @Query array iteration
        do {
            // Use a fetch descriptor to find the object in the context
            var descriptor = FetchDescriptor<Flight>()
            descriptor.predicate = #Predicate { $0.id == flightId }

            let flightsToDelete = try modelContext.fetch(descriptor)
            for flightToDelete in flightsToDelete {
                modelContext.delete(flightToDelete)
            }

            try modelContext.save()
            print("Flight deleted successfully: \(flightId)")
        } catch {
            print("ERROR deleting flight: \(error.localizedDescription)")
            print("Delete error: \(error)")
        }
    }

    private func clearAllData() {
        print("clearAllData called - Flights: \(flights.count), Airports: \(airports.count)")

        // Clear selection first
        selectedFlight = nil

        do {
            // Delete all flights using fetch descriptor to avoid @Query iteration issues
            var flightDescriptor = FetchDescriptor<Flight>()
            let allFlights = try modelContext.fetch(flightDescriptor)
            for flight in allFlights {
                modelContext.delete(flight)
            }
            print("Marked all flights for deletion")

            // Delete all airports using fetch descriptor
            var airportDescriptor = FetchDescriptor<Airport>()
            let allAirports = try modelContext.fetch(airportDescriptor)
            for airport in allAirports {
                modelContext.delete(airport)
            }
            print("Marked all airports for deletion")

            // Save changes
            try modelContext.save()
            print("Data cleared successfully")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showClearSuccessAlert = true
            }
            deleteHaptic.notificationOccurred(.success)
        } catch {
            print("ERROR clearing data: \(error.localizedDescription)")
            print("Clear error: \(error)")
        }
    }

    private func upsertAirport(
        code: String,
        fallbackName: String?,
        latitude: Double? = nil,
        longitude: Double? = nil,
        timezone: String? = nil
    ) -> Airport {
        let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if let existing = airports.first(where: { $0.iataCode.uppercased() == normalizedCode }) {
            if let lat = latitude, let lon = longitude, existing.latitude == 0, existing.longitude == 0 {
                existing.latitude = lat
                existing.longitude = lon
            }
            if let tz = timezone, existing.timezone == nil {
                existing.timezone = tz
            }
            return existing
        }

        let airport = Airport(
            iataCode: normalizedCode,
            name: fallbackName?.nilIfEmpty ?? normalizedCode,
            latitude: latitude ?? 0,
            longitude: longitude ?? 0,
            timezone: timezone
        )
        modelContext.insert(airport)
        return airport
    }
}

// MARK: - T-Minus Countdown Widget (Proactive Polish)

struct TMinusCountdownView: View {
    let flight: Flight
    @State private var timeRemaining: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusGradient)

            VStack(alignment: .leading, spacing: 2) {
                Text("NEXT FLIGHT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)

                Text(countdownString)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusGradient)
            }

            Text(flight.flightNumber)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .onReceive(timer) { _ in
            updateTimeRemaining()
        }
        .onAppear {
            updateTimeRemaining()
        }
    }

    private func updateTimeRemaining() {
        timeRemaining = max(0, flight.scheduledDeparture.timeIntervalSinceNow)
    }

    private var countdownString: String {
        if timeRemaining <= 0 {
            return "DEPARTED"
        }

        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        let seconds = Int(timeRemaining) % 60

        if hours > 24 {
            let days = hours / 24
            return "T-\(days)d \(hours % 24)h"
        } else if hours > 0 {
            return String(format: "T-%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "T-%02d:%02d", minutes, seconds)
        }
    }

    private var statusGradient: LinearGradient {
        let hours = timeRemaining / 3600

        if hours < 1 {
            // Imminent - red/orange pulse
            return LinearGradient(
                colors: [.red, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if hours < 6 {
            // Soon - orange/yellow
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // Relaxed - blue/cyan
            return LinearGradient(
                colors: [.blue, .cyan],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Floating Button Component

struct FloatingButton: View {
    let systemImage: String
    let isClose: Bool
    let action: () -> Void

    init(systemImage: String, isClose: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.isClose = isClose
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(isClose ? .system(size: 14, weight: .bold) : .system(size: 12, weight: .semibold))
                .frame(width: 32, height: 32)
                .padding(6)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.1), radius: 1.5, y: 1)
        }
        .buttonStyle(.borderless)
        .foregroundColor(.primary)
    }
}

// MARK: - Action Chip Component

struct ActionChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
        }
        .foregroundColor(.primary)
    }
}

// MARK: - Flight List Sheet (Native Sheet Implementation)

struct FlightListSheet: View {
    let flights: [Flight]
    @Binding var selectedFlight: Flight?
    let onSelectFlight: (Flight) -> Void
    let onDeleteFlight: (Flight) -> Void
    let onAddFlight: () -> Void

    var body: some View {
        NavigationStack {
            FlightListView(
                flights: flights,
                selectedFlight: $selectedFlight,
                onSelectFlight: onSelectFlight,
                onDeleteFlight: onDeleteFlight
            )
            .navigationTitle("My Flights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onAddFlight()
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

// MARK: - Add Flight Sheet (Flighty-style)

private struct AddFlightSheet: View {
    let airports: [Airport]
    let onSave: (FlightDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    // Search mode state
    @State private var flightNumber = ""
    @State private var selectedDate = Date()
    @State private var isSearching = false
    @State private var searchResult: FlightLookupResult?
    @State private var previewFlight: Flight? = nil
    @State private var searchError: String?
    @State private var showManualEntry = false

    // Manual entry state (only used when showManualEntry = true)
    @State private var manualAirline = ""
    @State private var manualOriginCode = ""
    @State private var manualDestinationCode = ""

    private var canSearch: Bool {
        flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Flight Number Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FLIGHT NUMBER")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField("e.g. CX888, KL1252", text: $flightNumber)
                            .font(.system(size: 28, weight: .bold))
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .padding()
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            .onChange(of: flightNumber) { _, _ in
                                // Clear previous search when typing
                                searchResult = nil
                                searchError = nil
                            }
                    }

                    // Date Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DATE")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            DateChip(title: "Today", isSelected: Calendar.current.isDateInToday(selectedDate)) {
                                selectedDate = Date()
                                searchResult = nil
                            }

                            DateChip(title: "Tomorrow", isSelected: Calendar.current.isDateInTomorrow(selectedDate)) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                searchResult = nil
                            }

                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: selectedDate) { _, _ in
                                    searchResult = nil
                                }
                        }

                        Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    // Search Button
                    Button {
                        Task {
                            await searchFlight()
                        }
                    } label: {
                        HStack {
                            if isSearching {
                                ProgressView()
                                    .tint(.white)
                                Text("Searching...")
                            } else {
                                Image(systemName: "magnifyingglass")
                                Text("Find Flight")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSearch ? Color.blue : Color.gray, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!canSearch || isSearching)

                    // Search Result
                    if let result = searchResult {
                        SearchResultCard(
                            result: result,
                            onAdd: { addFlightFromResult(result) },
                            onTap: { previewFlight = makePreviewFlight(from: result) }
                        )
                        .sheet(item: $previewFlight) { flight in
                            FlightDetailView(flight: flight)
                        }
                    }

                    // Error Message
                    if let error = searchError {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text(error)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                            Button("Add Manually") {
                                showManualEntry = true
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                        }
                    }

                    // Manual Entry Link (always visible at bottom)
                    if searchResult == nil && searchError == nil {
                        Button("Can't find your flight? Add manually") {
                            showManualEntry = true
                        }
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFlightEntrySheet(
                    airports: airports,
                    initialFlightNumber: flightNumber,
                    initialDate: selectedDate,
                    onSave: onSave
                )
            }
        }
    }

    private func searchFlight() async {
        isSearching = true
        searchError = nil
        searchResult = nil

        do {
            let result = try await FlightLookupService.lookup(
                flightNumber: flightNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                date: selectedDate
            )
            searchResult = result
        } catch {
            searchError = error.localizedDescription
        }

        isSearching = false
    }

    private func addFlightFromResult(_ result: FlightLookupResult) {
        onSave(FlightDraft(
            flightNumber: result.flightNumber,
            airline: result.airline,
            originCode: result.originIATACode,
            destinationCode: result.destinationIATACode,
            originName: result.originName,
            destinationName: result.destinationName,
            originLatitude: result.originLatitude,
            originLongitude: result.originLongitude,
            destinationLatitude: result.destinationLatitude,
            destinationLongitude: result.destinationLongitude,
            originTimezone: result.originTimezone,
            destinationTimezone: result.destinationTimezone,
            scheduledDeparture: result.scheduledDeparture,
            estimatedDeparture: result.estimatedDeparture,
            actualDeparture: result.actualDeparture,
            runwayDeparture: result.runwayDeparture,
            runwayArrival: result.runwayArrival,
            estimatedArrival: result.estimatedArrival,
            scheduledArrival: result.scheduledArrival,
            actualArrival: result.actualArrival,
            departureGate: result.departureGate,
            departureTerminal: result.departureTerminal,
            arrivalGate: result.arrivalGate,
            arrivalTerminal: result.arrivalTerminal,
            baggageClaim: result.baggageClaim,
            aircraftModel: result.aircraftModel,
            tailNumber: result.tailNumber,
            flightStatus: result.status
        ))
        dismiss()
    }

    private func makePreviewFlight(from result: FlightLookupResult) -> Flight {
        let origin = Airport(
            iataCode: result.originIATACode,
            name: result.originName ?? result.originIATACode,
            latitude: result.originLatitude ?? 0,
            longitude: result.originLongitude ?? 0,
            timezone: result.originTimezone
        )

        let destination = Airport(
            iataCode: result.destinationIATACode,
            name: result.destinationName ?? result.destinationIATACode,
            latitude: result.destinationLatitude ?? 0,
            longitude: result.destinationLongitude ?? 0,
            timezone: result.destinationTimezone
        )

        return Flight(
            flightNumber: result.flightNumber,
            airline: result.airline,
            origin: origin,
            destination: destination,
            scheduledDeparture: result.scheduledDeparture,
            estimatedDeparture: result.estimatedDeparture,
            actualDeparture: result.actualDeparture,
            runwayDeparture: result.runwayDeparture,
            runwayArrival: result.runwayArrival,
            estimatedArrival: result.estimatedArrival,
            scheduledArrival: result.scheduledArrival,
            actualArrival: result.actualArrival,
            departureGate: result.departureGate,
            departureTerminal: result.departureTerminal,
            arrivalGate: result.arrivalGate,
            arrivalTerminal: result.arrivalTerminal,
            baggageClaim: result.baggageClaim,
            aircraftModel: result.aircraftModel,
            tailNumber: result.tailNumber,
            flightStatus: result.status
        )
    }
}

// MARK: - Date Chip

private struct DateChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color.blue : Color(.systemGray5), in: Capsule())
                .foregroundColor(isSelected ? .white : .primary)
        }
    }
}

// MARK: - Search Result Card

private struct SearchResultCard: View {
    let result: FlightLookupResult
    let onAdd: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Flight header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.airline)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(result.flightNumber)
                        .font(.system(size: 22, weight: .bold))
                }

                Spacer()

                StatusBadge(status: result.status)
            }

            // Route
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.originIATACode)
                        .font(.system(size: 24, weight: .bold))
                    if let name = result.originName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 80, alignment: .leading)

                Spacer()

                Image(systemName: "airplane")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.destinationIATACode)
                        .font(.system(size: 24, weight: .bold))
                    if let name = result.destinationName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }

            // Times
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Departs")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(result.scheduledDeparture, format: .dateTime.hour().minute())
                        .font(.system(size: 16, weight: .semibold))
                }

                Spacer()

                if let arrival = result.scheduledArrival {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Arrives")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(arrival, format: .dateTime.hour().minute())
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }

            // Add Button
            Button(action: onAdd) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add This Flight")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                .shadow(color: Color.gray.opacity(0.2), radius: 2, x: 0, y: 1)
            }
        }
        .padding()
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .onTapGesture {
            // tapping anywhere on the card shows details
            onTap()
        }
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Manual Flight Entry Sheet

private struct ManualFlightEntrySheet: View {
    let airports: [Airport]
    let initialFlightNumber: String
    let initialDate: Date
    let onSave: (FlightDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var flightNumber: String
    @State private var airline = ""
    @State private var originCode = ""
    @State private var destinationCode = ""
    @State private var scheduledDeparture: Date
    @State private var scheduledArrival: Date?
    @State private var validationMessage: String?

    init(airports: [Airport], initialFlightNumber: String, initialDate: Date, onSave: @escaping (FlightDraft) -> Void) {
        self.airports = airports
        self.initialFlightNumber = initialFlightNumber
        self.initialDate = initialDate
        self.onSave = onSave
        _flightNumber = State(initialValue: initialFlightNumber)
        _scheduledDeparture = State(initialValue: initialDate)
    }

    private var canSave: Bool {
        !flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !airline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        originCode.count == 3 &&
        destinationCode.count == 3 &&
        originCode.uppercased() != destinationCode.uppercased()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Flight Details") {
                    TextField("Flight Number (e.g. CX888)", text: $flightNumber)
                        .textInputAutocapitalization(.characters)
                    TextField("Airline Name", text: $airline)
                }

                Section("Route") {
                    TextField("Origin (e.g. HKG)", text: $originCode)
                        .textInputAutocapitalization(.characters)
                    TextField("Destination (e.g. LAX)", text: $destinationCode)
                        .textInputAutocapitalization(.characters)
                }

                Section("Schedule") {
                    DatePicker("Departure", selection: $scheduledDeparture)
                }
            }
            .navigationTitle("Manual Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        saveManualFlight()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .alert("Cannot Save", isPresented: .constant(validationMessage != nil)) {
                Button("OK") { validationMessage = nil }
            } message: {
                Text(validationMessage ?? "")
            }
        }
    }

    private func saveManualFlight() {
        let normalizedOrigin = originCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let normalizedDest = destinationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        guard normalizedOrigin.count == 3, normalizedDest.count == 3 else {
            validationMessage = "Origin and destination must be 3-letter IATA codes."
            return
        }

        guard normalizedOrigin != normalizedDest else {
            validationMessage = "Origin and destination must be different."
            return
        }

        onSave(FlightDraft(
            flightNumber: flightNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            airline: airline.trimmingCharacters(in: .whitespacesAndNewlines),
            originCode: normalizedOrigin,
            destinationCode: normalizedDest,
            originName: nil,
            destinationName: nil,
            originLatitude: nil,
            originLongitude: nil,
            destinationLatitude: nil,
            destinationLongitude: nil,
            originTimezone: nil,
            destinationTimezone: nil,
            scheduledDeparture: scheduledDeparture,
            estimatedDeparture: nil,
            actualDeparture: nil,
            runwayDeparture: nil,
            runwayArrival: nil,
            estimatedArrival: nil,
            scheduledArrival: scheduledArrival,
            actualArrival: nil,
            departureGate: nil,
            departureTerminal: nil,
            arrivalGate: nil,
            arrivalTerminal: nil,
            baggageClaim: nil,
            aircraftModel: nil,
            tailNumber: nil,
            flightStatus: .onTime
        ))
        dismiss()
    }
}

// MARK: - Flight Draft

private struct FlightDraft {
    let flightNumber: String
    let airline: String
    let originCode: String
    let destinationCode: String
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
    let scheduledArrival: Date?
    let actualArrival: Date?
    let departureGate: String?
    let departureTerminal: String?
    let arrivalGate: String?
    let arrivalTerminal: String?
    let baggageClaim: String?
    let aircraftModel: String?
    let tailNumber: String?
    let flightStatus: FlightStatus
}

// MARK: - Extensions

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Airport.self, Flight.self], inMemory: true)
}
