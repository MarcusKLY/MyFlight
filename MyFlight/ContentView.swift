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

// MARK: - Main App View (No TabView - Single Map with Logbook Sheet)

struct MainTabView: View {
    // Preserve state across interactions
    @State private var selectedFlight: Flight?
    @State private var selectedTransit: TransitSegment?
    @State private var sheetDetent: PresentationDetent = .fraction(0.12)  // For My Trip
    @State private var logbookSheetDetent: PresentationDetent = .height(320)  // For Logbook
    @State private var showLogbook = false

    var body: some View {
        LiveMapTab(
            selectedFlight: $selectedFlight,
            selectedTransit: $selectedTransit,
            sheetDetent: $sheetDetent,
            showLogbook: $showLogbook
        )
        .sheet(isPresented: $showLogbook) {
            LogbookSheetView()
                .presentationDetents([.height(320), .large], selection: $logbookSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .onAppear {
                    logbookSheetDetent = .height(320)
                }
        }
    }
}

// MARK: - Live Map Tab (Primary Interface)

struct LiveMapTab: View {
    enum ActiveSheet: Identifiable, Equatable {
        case flightList
        case addFlight
        case addTransit
        case flightDetail(Flight)
        case transitDetail(TransitSegment)

        var id: String {
            switch self {
            case .flightList:
                return "flightList"
            case .addFlight:
                return "addFlight"
            case .addTransit:
                return "addTransit"
            case .flightDetail(let flight):
                return "flightDetail-\(flight.id.uuidString)"
            case .transitDetail(let transit):
                return "transitDetail-\(transit.id.uuidString)"
            }
        }

        static func == (lhs: ActiveSheet, rhs: ActiveSheet) -> Bool {
            switch (lhs, rhs) {
            case (.flightList, .flightList), (.addFlight, .addFlight), (.addTransit, .addTransit):
                return true
            case (.flightDetail(let a), .flightDetail(let b)):
                return a.id == b.id
            case (.transitDetail(let a), .transitDetail(let b)):
                return a.id == b.id
            default:
                return false
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flight.scheduledDeparture, order: .reverse) private var flights: [Flight]
    @Query(sort: \TransitSegment.scheduledDeparture, order: .reverse) private var transitSegments: [TransitSegment]
    @Query(sort: \Airport.iataCode) private var airports: [Airport]
    @Binding var selectedFlight: Flight?
    @Binding var selectedTransit: TransitSegment?
    @Binding var sheetDetent: PresentationDetent
    @Binding var showLogbook: Bool
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var activeSheet: ActiveSheet? = .flightList
    @State private var mapStyleMode: FlightMapStyleMode = .mutedStandard
    @State private var showClearDataAlert = false
    @State private var showClearSuccessAlert = false
    @State private var debugCopied = false
    @State private var listFilter: ListFilter = .all

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

    private var topOverlayFlight: Flight? {
        selectedFlight
    }

    private var isTrackingFlight: Bool {
        selectedFlight != nil
    }

    private var isTrackedFlightAlsoNext: Bool {
        guard let tracked = selectedFlight, let next = nextUpcomingFlight else { return false }
        return tracked.id == next.id
    }

    var body: some View {
        ZStack {
            // Full-screen map
            MapViewContainer(
                flights: flights,
                transitSegments: transitSegments,
                position: $mapPosition,
                selectedFlight: $selectedFlight,
                selectedTransit: $selectedTransit,
                mapStyleMode: mapStyleMode,
                filter: listFilter
            )
            .ignoresSafeArea()

            // Minimal floating controls overlay
            VStack {
                // Top bar - only show when sheet is collapsed or dismissed
                HStack(alignment: .top) {
                    // T-Minus Countdown Widget (only visible when sheet is small)
                    if let overlayFlight = topOverlayFlight, sheetDetent == .fraction(0.12), selectedTransit == nil {
                        TMinusCountdownView(
                            flight: overlayFlight,
                            isTracking: isTrackingFlight,
                            showNextBadge: isTrackedFlightAlsoNext,
                            onCloseTracking: isTrackingFlight ? { selectedFlight = nil } : nil
                        )
                            .onTapGesture {
                                activeSheet = .flightDetail(overlayFlight)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }

                    // Transit Countdown Widget (only visible when transit selected and sheet is small)
                    if let transit = selectedTransit, sheetDetent == .fraction(0.12) {
                        TransitCountdownView(
                            transit: transit,
                            isTracking: true,
                            onCloseTracking: { selectedTransit = nil }
                        )
                            .onTapGesture {
                                activeSheet = .transitDetail(transit)
                            }
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer()

                    // Map style toggle
                    FloatingButton(systemImage: mapStyleMode == .mutedStandard ? "map" : "globe.americas") {
                        mapStyleMode.toggle()
                    }

                    // Logbook button - closes flight list if open
                    FloatingButton(systemImage: "book.closed") {
                        if showLogbook {
                            showLogbook = false
                        } else {
                            // Simultaneous transition: close flight list and open logbook at same time
                            activeSheet = nil
                            showLogbook = true
                        }
                    }

                    // Show flight list button (always shows list.bullet, no X)
                    FloatingButton(systemImage: "list.bullet") {
                        if activeSheet == .flightList {
                            activeSheet = nil
                            sheetDetent = .height(290)  // Reset to collapsed state
                        } else {
                            // Simultaneous transition: close logbook and open flight list at same time
                            showLogbook = false
                            activeSheet = .flightList
                            sheetDetent = .height(290)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.22), value: activeSheet)

                Spacer()
            }
        }
        // Single sheet handling for all sheet states (prevents multiple-sheets warning)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .flightList:
                CombinedListSheet(
                    flights: flights,
                    transitSegments: transitSegments,
                    selectedFlight: $selectedFlight,
                    selectedTransit: $selectedTransit,
                    filter: $listFilter,
                    onSelectFlight: { flight in
                        selectedTransit = nil
                        selectFlightWithAnimation(flight)
                        sheetDetent = .fraction(0.12)
                        activeSheet = nil
                    },
                    onSelectTransit: { transit in
                        selectedFlight = nil
                        selectTransitWithAnimation(transit)
                        sheetDetent = .fraction(0.12)
                        activeSheet = nil
                    },
                    onDeleteFlight: { flight in
                        safeDeleteFlight(flight)
                    },
                    onDeleteTransit: { transit in
                        safeDeleteTransit(transit)
                    },
                    onAddFlight: {
                        activeSheet = .addFlight
                    },
                    onAddTransit: {
                        activeSheet = .addTransit
                    },
                    onViewFlightDetail: { flight in
                        activeSheet = .flightDetail(flight)
                    },
                    onViewTransitDetail: { transit in
                        activeSheet = .transitDetail(transit)
                    }
                )
                .presentationDetents([.height(290), .large], selection: $sheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .presentationBackground(Color(.systemGroupedBackground))
                .onAppear {
                    sheetDetent = .height(290)
                }

            case .flightDetail(let flight):
                FlightDetailView(flight: flight)
                    .presentationBackground(Color(.systemGroupedBackground))

            case .addFlight:
                AddFlightSheet(
                    airports: FlightSeedData.defaultAirports(from: airports),
                    existingFlights: flights
                ) { draft in
                    // Check for duplicate flight (same flight number and departure date)
                    let departureDate = Calendar.current.startOfDay(for: draft.scheduledDeparture)
                    let isDuplicate = flights.contains { existing in
                        let existingDate = Calendar.current.startOfDay(for: existing.scheduledDeparture)
                        return existing.flightNumber.uppercased() == draft.flightNumber.uppercased() &&
                               existingDate == departureDate
                    }
                    
                    if isDuplicate {
                        // Show error - flight already exists
                        deleteHaptic.notificationOccurred(.error)
                        return
                    }
                    
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
                        airlineIATA: draft.airlineIATA,
                        origin: origin,
                        destination: destination,
                        scheduledDeparture: draft.scheduledDeparture,
                        revisedDeparture: draft.revisedDeparture,
                        estimatedDeparture: draft.estimatedDeparture,
                        actualDeparture: draft.actualDeparture,
                        runwayDeparture: draft.runwayDeparture,
                        runwayArrival: draft.runwayArrival,
                        revisedArrival: draft.revisedArrival,
                        estimatedArrival: draft.estimatedArrival,
                        predictedArrival: draft.predictedArrival,
                        scheduledArrival: draft.scheduledArrival,
                        actualArrival: draft.actualArrival,
                        departureGate: draft.departureGate,
                        departureTerminal: draft.departureTerminal,
                        departureRunway: draft.departureRunway,
                        departureCheckInDesk: draft.departureCheckInDesk,
                        arrivalGate: draft.arrivalGate,
                        arrivalTerminal: draft.arrivalTerminal,
                        arrivalRunway: draft.arrivalRunway,
                        baggageClaim: draft.baggageClaim,
                        aircraftModel: draft.aircraftModel,
                        aircraftImageUrl: draft.aircraftImageUrl,
                        aircraftAge: draft.aircraftAge,
                        aircraftTypeName: draft.aircraftTypeName,
                        aircraftModelCode: draft.aircraftModelCode,
                        aircraftSeatCount: draft.aircraftSeatCount,
                        aircraftEngineCount: draft.aircraftEngineCount,
                        aircraftEngineType: draft.aircraftEngineType,
                        aircraftIsActive: draft.aircraftIsActive,
                        aircraftIsFreighter: draft.aircraftIsFreighter,
                        aircraftDataVerified: draft.aircraftDataVerified,
                        aircraftManufacturedYear: draft.aircraftManufacturedYear,
                        tailNumber: draft.tailNumber,
                        distanceKm: draft.distanceKm,
                        distanceNm: draft.distanceNm,
                        distanceMiles: draft.distanceMiles,
                        callSign: draft.callSign,
                        flightStatus: draft.flightStatus,
                        aircraftRegistrationDate: draft.aircraftRegistrationDate
                    )
                    modelContext.insert(flight)
                    try? modelContext.save()

                    selectionHaptic.impactOccurred()
                    activeSheet = nil
                }
                .presentationBackground(Color(.systemGroupedBackground))

            case .addTransit:
                AddTransitSheet { transit in
                    modelContext.insert(transit)
                    try? modelContext.save()
                    selectionHaptic.impactOccurred()
                    activeSheet = nil
                }
                .presentationBackground(Color(.systemGroupedBackground))

            case .transitDetail(let transit):
                TransitDetailView(transit: transit)
                    .presentationBackground(Color(.systemGroupedBackground))

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

    private func selectTransitWithAnimation(_ transit: TransitSegment) {
        selectionHaptic.impactOccurred()

        let originCoord = transit.originCoordinate
        let destCoord = transit.destinationCoordinate

        let midLat = (originCoord.latitude + destCoord.latitude) / 2
        let midLon = (originCoord.longitude + destCoord.longitude) / 2
        let center = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

        let latDelta = abs(destCoord.latitude - originCoord.latitude) * 1.4
        let lonDelta = abs(destCoord.longitude - originCoord.longitude) * 1.4

        let region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(latDelta, 2),
                longitudeDelta: max(lonDelta, 2)
            )
        )

        withAnimation(.interpolatingSpring(stiffness: 50, damping: 10)) {
            selectedTransit = transit
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
            let descriptor = FetchDescriptor<Flight>(predicate: #Predicate { $0.id == flightId })

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

    private func safeDeleteTransit(_ transit: TransitSegment) {
        deleteHaptic.notificationOccurred(.warning)

        let transitId = transit.id

        if selectedTransit?.id == transitId {
            selectedTransit = nil
        }

        do {
            let descriptor = FetchDescriptor<TransitSegment>(predicate: #Predicate { $0.id == transitId })
            let transitsToDelete = try modelContext.fetch(descriptor)
            for transitToDelete in transitsToDelete {
                modelContext.delete(transitToDelete)
            }
            try modelContext.save()
        } catch {
            print("ERROR deleting transit: \(error.localizedDescription)")
        }
    }

    private func clearAllData() {
        print("clearAllData called - Flights: \(flights.count), Airports: \(airports.count)")

        // Clear selection first
        selectedFlight = nil

        do {
            // Delete all flights using fetch descriptor to avoid @Query iteration issues
            let flightDescriptor = FetchDescriptor<Flight>()
            let allFlights = try modelContext.fetch(flightDescriptor)
            for flight in allFlights {
                modelContext.delete(flight)
            }
            print("Marked all flights for deletion")

            // Delete all airports using fetch descriptor
            let airportDescriptor = FetchDescriptor<Airport>()
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
    let isTracking: Bool
    let showNextBadge: Bool
    let onCloseTracking: (() -> Void)?
    @State private var timeRemaining: TimeInterval = 0
    @State private var timeToArrival: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusGradient)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(isTracking ? "TRACKING" : "NEXT FLIGHT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)

                    if showNextBadge {
                        Text("NEXT")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12), in: Capsule())
                    }
                }

                Text(countdownString)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(statusGradient)

                Text("\(flight.flightNumber)  \(flight.origin.iataCode) -> \(flight.destination.iataCode)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onCloseTracking {
                Button(action: onCloseTracking) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop tracking")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 220, alignment: .leading)
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
        timeRemaining = max(0, flight.effectiveDeparture.timeIntervalSinceNow)
        if let arrival = flight.progressArrival {
            timeToArrival = max(0, arrival.timeIntervalSinceNow)
        } else {
            timeToArrival = 0
        }
    }
    
    private var statusIcon: String {
        switch flight.computedFlightStatus {
        case .arrived, .arrivedLate:
            return "airplane.arrival"
        case .enRoute:
            return "airplane"
        case .cancelled:
            return "xmark.circle"
        default:
            return "airplane.departure"
        }
    }

    private var countdownString: String {
        let status = flight.computedFlightStatus
        
        switch status {
        case .arrived:
            return "Arrived"
        case .arrivedLate:
            return "Arrived Late"
        case .enRoute:
            // Show time to arrival
            if timeToArrival > 0 {
                return "Arriving in \(formatTimeInterval(timeToArrival))"
            }
            return "En Route"
        case .cancelled:
            return "Cancelled"
        default:
            // Future flight - show countdown to departure
            if timeRemaining <= 0 {
                return "Departed"
            }
            return formatCountdown(timeRemaining)
        }
    }
    
    private func formatCountdown(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        let seconds = Int(interval) % 60
        
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "T-\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return String(format: "T-%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "T-%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private func formatDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private var statusGradient: LinearGradient {
        let status = flight.computedFlightStatus
        
        switch status {
        case .arrived:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case .arrivedLate:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        case .enRoute:
            return LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
        case .cancelled:
            return LinearGradient(colors: [.red, .pink], startPoint: .leading, endPoint: .trailing)
        case .delayed:
            return LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
        default:
            // Future flights - color based on time remaining
            let hours = timeRemaining / 3600
            if hours < 1 {
                return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
            } else if hours < 6 {
                return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
            } else {
                return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
            }
        }
    }
}

// MARK: - Transit Countdown Widget

struct TransitCountdownView: View {
    let transit: TransitSegment
    let isTracking: Bool
    let onCloseTracking: (() -> Void)?
    @State private var timeRemaining: TimeInterval = 0

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: transit.transitType.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(statusGradient)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(isTracking ? "TRACKING" : "NEXT TRANSIT")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.secondary)

                Text(countdownString)
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(statusGradient)

                Text("\(transit.operatorName)  \(shortenLocation(transit.originName)) → \(shortenLocation(transit.destinationName))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let onCloseTracking {
                Button(action: onCloseTracking) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop tracking")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 220, alignment: .leading)
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
        timeRemaining = max(0, transit.scheduledDeparture.timeIntervalSinceNow)
    }

    private func shortenLocation(_ location: String) -> String {
        let parts = location.components(separatedBy: ",")
        if let first = parts.first?.trimmingCharacters(in: .whitespaces) {
            return String(first.prefix(10))
        }
        return String(location.prefix(10))
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
        let transitColor = transitTypeColor

        if hours < 1 {
            // Imminent - vibrant to orange
            return LinearGradient(
                colors: [transitColor, .orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if hours < 6 {
            // Soon - color to yellow
            return LinearGradient(
                colors: [transitColor, transitColor.opacity(0.7)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            // Relaxed - transit type color
            return LinearGradient(
                colors: [transitColor, transitColor],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var transitTypeColor: Color {
        switch transit.transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
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
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .padding(4)
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

// MARK: - List Filter

enum ListFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case flights = "Flights"
    case transit = "Transit"

    var id: String { rawValue }
}

// MARK: - Combined List Sheet (Flights + Transit)

struct CombinedListSheet: View {
    let flights: [Flight]
    let transitSegments: [TransitSegment]
    @Binding var selectedFlight: Flight?
    @Binding var selectedTransit: TransitSegment?
    @Binding var filter: ListFilter
    let onSelectFlight: (Flight) -> Void
    let onSelectTransit: (TransitSegment) -> Void
    let onDeleteFlight: (Flight) -> Void
    let onDeleteTransit: (TransitSegment) -> Void
    let onAddFlight: () -> Void
    let onAddTransit: () -> Void
    let onViewFlightDetail: (Flight) -> Void
    let onViewTransitDetail: (TransitSegment) -> Void

    @State private var showAddMenu = false

    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let deleteHaptic = UINotificationFeedbackGenerator()

    // Combine and sort all items by departure date
    private var upcomingFlights: [Flight] {
        flights
            .filter { $0.scheduledDeparture >= Date() }
            .sorted { $0.scheduledDeparture < $1.scheduledDeparture }
    }

    private var pastFlights: [Flight] {
        flights
            .filter { $0.scheduledDeparture < Date() }
            .sorted { $0.scheduledDeparture > $1.scheduledDeparture }
    }

    private var upcomingTransit: [TransitSegment] {
        transitSegments
            .filter { $0.scheduledDeparture >= Date() }
            .sorted { $0.scheduledDeparture < $1.scheduledDeparture }
    }

    private var pastTransit: [TransitSegment] {
        transitSegments
            .filter { $0.scheduledDeparture < Date() }
            .sorted { $0.scheduledDeparture > $1.scheduledDeparture }
    }

    private var filteredUpcomingFlights: [Flight] {
        filter == .transit ? [] : upcomingFlights
    }

    private var filteredPastFlights: [Flight] {
        filter == .transit ? [] : pastFlights
    }

    private var filteredUpcomingTransit: [TransitSegment] {
        filter == .flights ? [] : upcomingTransit
    }

    private var filteredPastTransit: [TransitSegment] {
        filter == .flights ? [] : pastTransit
    }

    private var hasUpcoming: Bool {
        !filteredUpcomingFlights.isEmpty || !filteredUpcomingTransit.isEmpty
    }

    private var hasPast: Bool {
        !filteredPastFlights.isEmpty || !filteredPastTransit.isEmpty
    }

    private var isEmpty: Bool {
        filteredUpcomingFlights.isEmpty && filteredPastFlights.isEmpty &&
        filteredUpcomingTransit.isEmpty && filteredPastTransit.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Color.clear
                        .frame(width: 36, height: 36)

                    Text("My Trips")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Menu {
                        Button {
                            onAddFlight()
                        } label: {
                            Label("Add Flight", systemImage: "airplane")
                        }
                        Button {
                            onAddTransit()
                        } label: {
                            Label("Add Transit", systemImage: "bus.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))

                // Segmented filter
                Picker("Filter", selection: $filter) {
                    ForEach(ListFilter.allCases) { filterOption in
                        Text(filterOption.rawValue).tag(filterOption)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(Color(.systemGroupedBackground))

                // List content
                if isEmpty {
                    emptyStateView
                } else {
                    listContent
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            selectionHaptic.prepare()
            deleteHaptic.prepare()
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(emptyStateTitle, systemImage: emptyStateIcon)
        } description: {
            Text(emptyStateDescription)
        }
        .symbolEffect(.pulse.byLayer, options: .repeating)
    }

    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Trips Yet"
        case .flights: return "No Flights Yet"
        case .transit: return "No Transit Yet"
        }
    }

    private var emptyStateIcon: String {
        switch filter {
        case .all: return "airplane.departure"
        case .flights: return "airplane"
        case .transit: return "bus.fill"
        }
    }

    private var emptyStateDescription: String {
        switch filter {
        case .all: return "Tap + to add a flight or transit segment."
        case .flights: return "Tap + to add your first flight."
        case .transit: return "Tap + to add your first transit segment."
        }
    }

    private var listContent: some View {
        List {
            // Upcoming section - only show if there are upcoming items
            if hasUpcoming {
                Section {
                    // Combine and sort upcoming items by departure time
                    ForEach(sortedUpcomingItems, id: \.id) { item in
                        switch item {
                        case .flight(let flight):
                            FlightListItemView(
                                flight: flight,
                                isSelected: selectedFlight?.id == flight.id,
                                isUpcoming: true
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectionHaptic.impactOccurred()
                                onSelectFlight(flight)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteHaptic.notificationOccurred(.warning)
                                    onDeleteFlight(flight)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    onViewFlightDetail(flight)
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(.blue)
                            }
                        case .transit(let transit):
                            TransitListItemView(
                                transit: transit,
                                isSelected: selectedTransit?.id == transit.id,
                                isUpcoming: true
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectionHaptic.impactOccurred()
                                onSelectTransit(transit)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteHaptic.notificationOccurred(.warning)
                                    onDeleteTransit(transit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    onViewTransitDetail(transit)
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    SectionHeader(title: "Upcoming", count: upcomingCount, icon: "airplane.departure")
                }
            }

            // Past section
            Section {
                if !hasPast {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        Text("No past trips")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sortedPastItems, id: \.id) { item in
                        switch item {
                        case .flight(let flight):
                            FlightListItemView(
                                flight: flight,
                                isSelected: selectedFlight?.id == flight.id,
                                isUpcoming: false
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectionHaptic.impactOccurred()
                                onSelectFlight(flight)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteHaptic.notificationOccurred(.warning)
                                    onDeleteFlight(flight)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    onViewFlightDetail(flight)
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(.blue)
                            }
                        case .transit(let transit):
                            TransitListItemView(
                                transit: transit,
                                isSelected: selectedTransit?.id == transit.id,
                                isUpcoming: false
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectionHaptic.impactOccurred()
                                onSelectTransit(transit)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteHaptic.notificationOccurred(.warning)
                                    onDeleteTransit(transit)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    onViewTransitDetail(transit)
                                } label: {
                                    Label("Details", systemImage: "info.circle")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            } header: {
                SectionHeader(title: "Past", count: pastCount, icon: "airplane.arrival")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }

    // Helper enum for unified list items
    private enum TripItem {
        case flight(Flight)
        case transit(TransitSegment)

        var id: String {
            switch self {
            case .flight(let f): return "flight-\(f.id)"
            case .transit(let t): return "transit-\(t.id)"
            }
        }

        var departureDate: Date {
            switch self {
            case .flight(let f): return f.scheduledDeparture
            case .transit(let t): return t.scheduledDeparture
            }
        }
    }

    private var sortedUpcomingItems: [TripItem] {
        var items: [TripItem] = []
        items.append(contentsOf: filteredUpcomingFlights.map { .flight($0) })
        items.append(contentsOf: filteredUpcomingTransit.map { .transit($0) })
        return items.sorted { $0.departureDate < $1.departureDate }
    }

    private var sortedPastItems: [TripItem] {
        var items: [TripItem] = []
        items.append(contentsOf: filteredPastFlights.map { .flight($0) })
        items.append(contentsOf: filteredPastTransit.map { .transit($0) })
        return items.sorted { $0.departureDate > $1.departureDate }
    }

    private var upcomingCount: Int {
        filteredUpcomingFlights.count + filteredUpcomingTransit.count
    }

    private var pastCount: Int {
        filteredPastFlights.count + filteredPastTransit.count
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
            VStack(spacing: 0) {
                // Centered title with balanced side controls
                HStack(spacing: 12) {
                    Color.clear
                        .frame(width: 36, height: 36)

                    Text("My Flights")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button {
                        onAddFlight()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(Color(.systemGroupedBackground))

                FlightListView(
                    flights: flights,
                    selectedFlight: $selectedFlight,
                    onSelectFlight: onSelectFlight,
                    onDeleteFlight: onDeleteFlight
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Add Flight Sheet (Flighty-style)

private struct AddFlightSheet: View {
    let airports: [Airport]
    let existingFlights: [Flight]  // For auto-fill from similar flights
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
    @FocusState private var isFlightNumberFocused: Bool

    // Manual entry state (only used when showManualEntry = true)
    @State private var manualAirline = ""
    @State private var manualOriginCode = ""
    @State private var manualDestinationCode = ""

    private var canSearch: Bool {
        flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Centered title with balanced side controls
                HStack(spacing: 12) {
                    Color.clear
                        .frame(width: 36, height: 36)

                    Text("Add Flight")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(Color(.systemGroupedBackground))

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
                                .focused($isFlightNumberFocused)
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

                        HStack(spacing: 8) {
                            DateChip(title: "Today", isSelected: Calendar.current.isDateInToday(selectedDate)) {
                                selectedDate = Date()
                                searchResult = nil
                            }

                            DateChip(title: "Tomorrow", isSelected: Calendar.current.isDateInTomorrow(selectedDate)) {
                                selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                                searchResult = nil
                            }

                            // Custom date picker with white text + blue background when selected
                            let isCustomDate = !Calendar.current.isDateInToday(selectedDate) && !Calendar.current.isDateInTomorrow(selectedDate)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .labelsHidden()
                                .onChange(of: selectedDate) { _, _ in
                                    searchResult = nil
                                }
                                .tint(isCustomDate ? .white : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(isCustomDate ? Color.blue : Color(.systemGray5), in: Capsule())
                                .frame(maxWidth: .infinity)
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
                            FlightDetailView(flight: flight, isPreview: true)
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
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            }
            .sheet(isPresented: $showManualEntry) {
                ManualFlightEntrySheet(
                    airports: airports,
                    existingFlights: existingFlights,
                    initialFlightNumber: flightNumber,
                    initialDate: selectedDate,
                    onSave: onSave
                )
            }
        }
    }

    private func searchFlight() async {
        // Hide keyboard when searching
        isFlightNumberFocused = false

        isSearching = true
        searchError = nil
        searchResult = nil
        
        let normalizedFlightNumber = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")

        do {
            let result = try await FlightLookupService.lookup(
                flightNumber: normalizedFlightNumber,
                date: selectedDate
            )
            searchResult = result
        } catch {
            // API lookup failed - try to find similar flight from existing flights
            if let similarFlight = findSimilarExistingFlight(flightNumber: normalizedFlightNumber) {
                // Create result from existing flight data
                searchResult = createResultFromExistingFlight(similarFlight, date: selectedDate)
                searchError = "Flight details auto-filled from previous \(similarFlight.flightNumber) flight"
            } else {
                searchError = error.localizedDescription
            }
        }

        isSearching = false
    }
    
    // Find existing flight with same flight number (ignoring spaces)
    private func findSimilarExistingFlight(flightNumber: String) -> Flight? {
        let normalized = flightNumber.uppercased().replacingOccurrences(of: " ", with: "")
        return existingFlights.first { flight in
            flight.flightNumber.uppercased().replacingOccurrences(of: " ", with: "") == normalized
        }
    }
    
    // Create a FlightLookupResult from an existing flight
    private func createResultFromExistingFlight(_ flight: Flight, date: Date) -> FlightLookupResult {
        FlightLookupResult(
            flightNumber: flight.flightNumber,
            airline: flight.airline,
            airlineIATA: flight.airlineIATA,
            originIATACode: flight.origin.iataCode,
            destinationIATACode: flight.destination.iataCode,
            originName: flight.origin.name,
            destinationName: flight.destination.name,
            originLatitude: flight.origin.latitude,
            originLongitude: flight.origin.longitude,
            destinationLatitude: flight.destination.latitude,
            destinationLongitude: flight.destination.longitude,
            originTimezone: flight.origin.timezone,
            destinationTimezone: flight.destination.timezone,
            scheduledDeparture: date,  // Use the selected date
            revisedDeparture: nil,
            estimatedDeparture: nil,
            actualDeparture: nil,
            runwayDeparture: nil,
            runwayArrival: nil,
            revisedArrival: nil,
            estimatedArrival: nil,
            predictedArrival: nil,
            scheduledArrival: date.addingTimeInterval(flight.scheduledArrival?.timeIntervalSince(flight.scheduledDeparture) ?? 7200),
            actualArrival: nil,
            departureGate: nil,
            departureTerminal: flight.departureTerminal,
            departureRunway: nil,
            departureCheckInDesk: nil,
            arrivalGate: nil,
            arrivalTerminal: flight.arrivalTerminal,
            arrivalRunway: nil,
            baggageClaim: nil,
            aircraftModel: flight.aircraftModel,
            aircraftImageUrl: flight.aircraftImageUrl,
            aircraftAge: flight.aircraftAge,
            tailNumber: nil,  // Different aircraft likely
            aircraftTypeName: flight.aircraftTypeName,
            aircraftModelCode: flight.aircraftModelCode,
            aircraftSeatCount: flight.aircraftSeatCount,
            aircraftEngineCount: flight.aircraftEngineCount,
            aircraftEngineType: flight.aircraftEngineType,
            aircraftIsActive: flight.aircraftIsActive,
            aircraftIsFreighter: flight.aircraftIsFreighter,
            aircraftDataVerified: flight.aircraftDataVerified,
            aircraftManufacturedYear: flight.aircraftManufacturedYear,
            aircraftRegistrationDate: flight.aircraftRegistrationDate,
            distanceKm: flight.distanceKm,
            distanceNm: flight.distanceNm,
            distanceMiles: flight.distanceMiles,
            callSign: nil,
            status: .onTime
        )
    }

    private func addFlightFromResult(_ result: FlightLookupResult) {
        onSave(FlightDraft(
            flightNumber: result.flightNumber,
            airline: result.airline,
            airlineIATA: result.airlineIATA,
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
            revisedDeparture: result.revisedDeparture,
            estimatedDeparture: result.estimatedDeparture,
            actualDeparture: result.actualDeparture,
            runwayDeparture: result.runwayDeparture,
            runwayArrival: result.runwayArrival,
            revisedArrival: result.revisedArrival,
            estimatedArrival: result.estimatedArrival,
            predictedArrival: result.predictedArrival,
            scheduledArrival: result.scheduledArrival,
            actualArrival: result.actualArrival,
            departureGate: result.departureGate,
            departureTerminal: result.departureTerminal,
            departureRunway: result.departureRunway,
            departureCheckInDesk: result.departureCheckInDesk,
            arrivalGate: result.arrivalGate,
            arrivalTerminal: result.arrivalTerminal,
            arrivalRunway: result.arrivalRunway,
            baggageClaim: result.baggageClaim,
            aircraftModel: result.aircraftModel,
            aircraftImageUrl: result.aircraftImageUrl,
            aircraftAge: result.aircraftAge,
            aircraftTypeName: result.aircraftTypeName,
            aircraftModelCode: result.aircraftModelCode,
            aircraftSeatCount: result.aircraftSeatCount,
            aircraftEngineCount: result.aircraftEngineCount,
            aircraftEngineType: result.aircraftEngineType,
            aircraftIsActive: result.aircraftIsActive,
            aircraftIsFreighter: result.aircraftIsFreighter,
            aircraftDataVerified: result.aircraftDataVerified,
            aircraftManufacturedYear: result.aircraftManufacturedYear,
            aircraftRegistrationDate: result.aircraftRegistrationDate,
            tailNumber: result.tailNumber,
            distanceKm: result.distanceKm,
            distanceNm: result.distanceNm,
            distanceMiles: result.distanceMiles,
            callSign: result.callSign,
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
            airlineIATA: result.airlineIATA,
            origin: origin,
            destination: destination,
            scheduledDeparture: result.scheduledDeparture,
            revisedDeparture: result.revisedDeparture,
            estimatedDeparture: result.estimatedDeparture,
            actualDeparture: result.actualDeparture,
            runwayDeparture: result.runwayDeparture,
            runwayArrival: result.runwayArrival,
            revisedArrival: result.revisedArrival,
            estimatedArrival: result.estimatedArrival,
            predictedArrival: result.predictedArrival,
            scheduledArrival: result.scheduledArrival,
            actualArrival: result.actualArrival,
            departureGate: result.departureGate,
            departureTerminal: result.departureTerminal,
            departureRunway: result.departureRunway,
            departureCheckInDesk: result.departureCheckInDesk,
            arrivalGate: result.arrivalGate,
            arrivalTerminal: result.arrivalTerminal,
            arrivalRunway: result.arrivalRunway,
            baggageClaim: result.baggageClaim,
            aircraftModel: result.aircraftModel,
            aircraftImageUrl: result.aircraftImageUrl,
            aircraftAge: result.aircraftAge,
            aircraftTypeName: result.aircraftTypeName,
            aircraftModelCode: result.aircraftModelCode,
            aircraftSeatCount: result.aircraftSeatCount,
            aircraftEngineCount: result.aircraftEngineCount,
            aircraftEngineType: result.aircraftEngineType,
            aircraftIsActive: result.aircraftIsActive,
            aircraftIsFreighter: result.aircraftIsFreighter,
            aircraftDataVerified: result.aircraftDataVerified,
            aircraftManufacturedYear: result.aircraftManufacturedYear,
            tailNumber: result.tailNumber,
            distanceKm: result.distanceKm,
            distanceNm: result.distanceNm,
            distanceMiles: result.distanceMiles,
            callSign: result.callSign,
            flightStatus: result.status,
            aircraftRegistrationDate: result.aircraftRegistrationDate
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

    private var arrivalDayOffset: Int {
        guard let arrival = result.scheduledArrival else { return 0 }

        var depCalendar = Calendar.current
        if let tz = result.originTimezone, let zone = TimeZone(identifier: tz) {
            depCalendar.timeZone = zone
        }

        var arrCalendar = Calendar.current
        if let tz = result.destinationTimezone, let zone = TimeZone(identifier: tz) {
            arrCalendar.timeZone = zone
        }

        let depStart = depCalendar.startOfDay(for: result.scheduledDeparture)
        let arrStart = arrCalendar.startOfDay(for: arrival)
        return Calendar.current.dateComponents([.day], from: depStart, to: arrStart).day ?? 0
    }

    private var arrivalDayOffsetSuffix: String {
        guard arrivalDayOffset > 0 else { return "" }
        return " +\(arrivalDayOffset)"
    }

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
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.originIATACode)
                        .font(.system(size: 24, weight: .bold))
                    if let name = result.originName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "airplane")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.destinationIATACode)
                        .font(.system(size: 24, weight: .bold))
                    if let name = result.destinationName {
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
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
                        Text("\(arrival.formatted(.dateTime.hour().minute()))\(arrivalDayOffsetSuffix)")
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
    let existingFlights: [Flight]  // For auto-fill
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

    init(airports: [Airport], existingFlights: [Flight], initialFlightNumber: String, initialDate: Date, onSave: @escaping (FlightDraft) -> Void) {
        self.airports = airports
        self.existingFlights = existingFlights
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
                ToolbarItem(placement: .principal) {
                    Button {
                        autoFillFromExisting()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "wand.and.stars")
                            Text("Auto-fill")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                    }
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
    
    private func autoFillFromExisting() {
        let normalized = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
        
        guard let existingFlight = existingFlights.first(where: { flight in
            flight.flightNumber.uppercased().replacingOccurrences(of: " ", with: "") == normalized
        }) else {
            validationMessage = "No existing flight found with number \(flightNumber)"
            return
        }
        
        // Auto-fill fields from existing flight
        airline = existingFlight.airline
        originCode = existingFlight.origin.iataCode
        destinationCode = existingFlight.destination.iataCode
        
        // Keep the current selected date but use similar duration
        if let existingArrival = existingFlight.scheduledArrival {
            let duration = existingArrival.timeIntervalSince(existingFlight.scheduledDeparture)
            scheduledArrival = scheduledDeparture.addingTimeInterval(duration)
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
            airlineIATA: nil,
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
            revisedDeparture: nil,
            estimatedDeparture: nil,
            actualDeparture: nil,
            runwayDeparture: nil,
            runwayArrival: nil,
            revisedArrival: nil,
            estimatedArrival: nil,
            predictedArrival: nil,
            scheduledArrival: scheduledArrival,
            actualArrival: nil,
            departureGate: nil,
            departureTerminal: nil,
            departureRunway: nil,
            departureCheckInDesk: nil,
            arrivalGate: nil,
            arrivalTerminal: nil,
            arrivalRunway: nil,
            baggageClaim: nil,
            aircraftModel: nil,
            aircraftImageUrl: nil,
            aircraftAge: nil,
            aircraftTypeName: nil,
            aircraftModelCode: nil,
            aircraftSeatCount: nil,
            aircraftEngineCount: nil,
            aircraftEngineType: nil,
            aircraftIsActive: nil,
            aircraftIsFreighter: nil,
            aircraftDataVerified: nil,
            aircraftManufacturedYear: nil,
            aircraftRegistrationDate: nil,
            tailNumber: nil,
            distanceKm: nil,
            distanceNm: nil,
            distanceMiles: nil,
            callSign: nil,
            flightStatus: .onTime
        ))
        dismiss()
    }
}

// MARK: - Flight Draft

private struct FlightDraft {
    let flightNumber: String
    let airline: String
    let airlineIATA: String?
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
    let tailNumber: String?
    let distanceKm: Double?
    let distanceNm: Double?
    let distanceMiles: Double?
    let callSign: String?
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
