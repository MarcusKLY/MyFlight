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
import ActivityKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Flight.scheduledDeparture, order: .reverse) private var flights: [Flight]
    @Query(sort: \Airport.iataCode) private var airports: [Airport]

    @State private var selectedFlight: Flight?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var showFlightList = false
    @State private var showAddFlightSheet = false
    @State private var showFlightDetail = false
    @State private var mapStyleMode: FlightMapStyleMode = .mutedStandard
    @State private var activeLiveActivity: Activity<FlightStatusAttributes>?
    @State private var liveActivityProgress: Double = 0
    
    var body: some View {
        ZStack {
            MapViewContainer(
                flights: flights,
                position: $mapPosition,
                selectedFlight: $selectedFlight,
                mapStyleMode: mapStyleMode
            )
                .ignoresSafeArea()
            
            VStack {
                HStack {
                    Text("My Flights")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()

                    Button(action: { mapStyleMode.toggle() }) {
                        Image(systemName: mapStyleMode == .mutedStandard ? "map" : "globe.americas")
                            .font(.headline)
                            .padding(8)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }

                    Button(action: { showAddFlightSheet = true }) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .padding(8)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                    
                    Button(action: { showFlightList.toggle() }) {
                        Image(systemName: "list.bullet")
                            .font(.headline)
                            .padding(8)
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .clipShape(Circle())
                            .shadow(radius: 4)
                    }
                }
                .padding()

                if let selectedFlight {
                    HStack(spacing: 10) {
                        Button {
                            startLiveActivity(for: selectedFlight)
                        } label: {
                            Label("Start Live", systemImage: "dot.radiowaves.left.and.right")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }

                        Button {
                            advanceLiveActivity(for: selectedFlight)
                        } label: {
                            Label("Advance", systemImage: "forward.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                        .disabled(activeLiveActivity == nil)

                        Spacer()

                        Button {
                            showFlightDetail = true
                        } label: {
                            Label("Details", systemImage: "info.circle")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.9))
                                .foregroundColor(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
            }
            
            // Bottom sheet for flight list
            if showFlightList {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 4)
                        .padding(.top, 8)
                    
                    FlightListView(
                        flights: flights,
                        selectedFlight: $selectedFlight,
                        mapPosition: $mapPosition,
                        onDeleteFlight: { flight in
                            modelContext.delete(flight)
                            try? modelContext.save()
                            if selectedFlight?.id == flight.id {
                                selectedFlight = nil
                            }
                        },
                        onCycleStatus: { flight in
                            let next: FlightStatus
                            switch flight.flightStatus {
                            case .onTime:
                                next = .delayed
                            case .delayed:
                                next = .cancelled
                            case .cancelled:
                                next = .onTime
                            }
                            flight.flightStatus = next
                            try? modelContext.save()
                        }
                    )
                }
                .frame(maxHeight: .infinity, alignment: .bottom)
                .background(Color(.systemBackground))
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .shadow(radius: 10)
                .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: selectedFlight) { oldValue, newValue in
            if newValue != nil {
                showFlightList = false
            }
        }
        .sheet(isPresented: $showFlightDetail) {
            if let selectedFlight {
                FlightDetailView(flight: selectedFlight)
            }
        }
        .sheet(isPresented: $showAddFlightSheet) {
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
                    actualDeparture: draft.actualDeparture,
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
            }
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
            // Enrich existing airport with freshly fetched data when available.
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

    private func startLiveActivity(for flight: Flight) {
        liveActivityProgress = 0.1
        activeLiveActivity = FlightActivityManager.startActivity(for: flight)
    }

    private func advanceLiveActivity(for flight: Flight) {
        guard let activity = activeLiveActivity else {
            return
        }
        liveActivityProgress = min(1.0, liveActivityProgress + 0.2)
        let minutes = Int(max(0, (1.0 - liveActivityProgress) * 150))
        FlightActivityManager.update(
            activity,
            progress: liveActivityProgress,
            minutesToArrival: minutes,
            status: flight.flightStatus
        )
    }
}

private struct AddFlightSheet: View {
    let airports: [Airport]
    let onSave: (FlightDraft) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var flightNumber = ""
    @State private var airline = ""
    @State private var originCode = ""
    @State private var destinationCode = ""
    @State private var originName = ""
    @State private var destinationName = ""
    @State private var originLatitude: Double?
    @State private var originLongitude: Double?
    @State private var destinationLatitude: Double?
    @State private var destinationLongitude: Double?
    @State private var originTimezone: String?
    @State private var destinationTimezone: String?
    @State private var scheduledDeparture = Date()
    @State private var includeActualDeparture = false
    @State private var actualDeparture = Date()
    @State private var scheduledArrival: Date?
    @State private var actualArrival: Date?
    @State private var departureGate = ""
    @State private var departureTerminal = ""
    @State private var arrivalGate = ""
    @State private var arrivalTerminal = ""
    @State private var baggageClaim = ""
    @State private var aircraftModel = ""
    @State private var tailNumber = ""
    @State private var flightStatus: FlightStatus = .onTime
    @State private var validationMessage: String?
    @State private var isLookingUp = false

    private var matchedOrigin: Airport? {
        airports.first(where: { $0.iataCode.uppercased() == normalizedOriginCode })
    }

    private var matchedDestination: Airport? {
        airports.first(where: { $0.iataCode.uppercased() == normalizedDestinationCode })
    }

    private var normalizedOriginCode: String {
        originCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var normalizedDestinationCode: String {
        destinationCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private var canSave: Bool {
        !flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !airline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        normalizedOriginCode.count == 3 &&
        normalizedDestinationCode.count == 3 &&
        normalizedOriginCode != normalizedDestinationCode
    }

    private var showValidationAlert: Binding<Bool> {
        Binding(
            get: { validationMessage != nil },
            set: { newValue in
                if !newValue {
                    validationMessage = nil
                }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Flight") {
                    TextField("Flight Number", text: $flightNumber)
                    TextField("Airline", text: $airline)
                    Picker("Status", selection: $flightStatus) {
                        ForEach(FlightStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    Button {
                        Task {
                            await lookupFlight()
                        }
                    } label: {
                        if isLookingUp {
                            HStack {
                                ProgressView()
                                Text("Looking up flight...")
                            }
                        } else {
                            Label("Auto Fill from Flight Number + Date", systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(isLookingUp || flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section("Route") {
                    TextField("Origin IATA (e.g. HKG)", text: $originCode)
                        .textInputAutocapitalization(.characters)
                    if let matchedOrigin {
                        Text(matchedOrigin.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    TextField("Destination IATA (e.g. HEL)", text: $destinationCode)
                        .textInputAutocapitalization(.characters)
                    if let matchedDestination {
                        Text(matchedDestination.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Timing") {
                    DatePicker("Scheduled Departure", selection: $scheduledDeparture)
                    Toggle("Set Actual Departure", isOn: $includeActualDeparture)
                    if includeActualDeparture {
                        DatePicker("Actual Departure", selection: $actualDeparture)
                    }
                    if let arrival = scheduledArrival {
                        LabeledContent("Scheduled Arrival") {
                            Text("\(arrival, style: .date) \(arrival, style: .time)")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Departure") {
                    TextField("Departure Gate", text: $departureGate)
                    TextField("Departure Terminal", text: $departureTerminal)
                }

                Section("Arrival") {
                    TextField("Arrival Gate", text: $arrivalGate)
                    TextField("Arrival Terminal", text: $arrivalTerminal)
                    TextField("Baggage Claim", text: $baggageClaim)
                }

                Section("Aircraft") {
                    TextField("Aircraft Type (e.g. Boeing 777)", text: $aircraftModel)
                    TextField("Tail Number", text: $tailNumber)
                }
            }
            .navigationTitle("Add Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard normalizedOriginCode.count == 3,
                              normalizedDestinationCode.count == 3 else {
                            validationMessage = "Origin and destination must be valid 3-letter IATA codes."
                            return
                        }

                        guard normalizedOriginCode != normalizedDestinationCode else {
                            validationMessage = "Origin and destination must be different airports."
                            return
                        }

                        guard !flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                              !airline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            validationMessage = "Flight number and airline are required."
                            return
                        }

                        onSave(
                            FlightDraft(
                                flightNumber: flightNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                                airline: airline.trimmingCharacters(in: .whitespacesAndNewlines),
                                originCode: normalizedOriginCode,
                                destinationCode: normalizedDestinationCode,
                                originName: matchedOrigin?.name ?? originName.nilIfEmpty,
                                destinationName: matchedDestination?.name ?? destinationName.nilIfEmpty,
                                originLatitude: originLatitude,
                                originLongitude: originLongitude,
                                destinationLatitude: destinationLatitude,
                                destinationLongitude: destinationLongitude,
                                originTimezone: originTimezone,
                                destinationTimezone: destinationTimezone,
                                scheduledDeparture: scheduledDeparture,
                                actualDeparture: includeActualDeparture ? actualDeparture : nil,
                                scheduledArrival: scheduledArrival,
                                actualArrival: actualArrival,
                                departureGate: departureGate.nilIfEmpty,
                                departureTerminal: departureTerminal.nilIfEmpty,
                                arrivalGate: arrivalGate.nilIfEmpty,
                                arrivalTerminal: arrivalTerminal.nilIfEmpty,
                                baggageClaim: baggageClaim.nilIfEmpty,
                                aircraftModel: aircraftModel.nilIfEmpty,
                                tailNumber: tailNumber.nilIfEmpty,
                                flightStatus: flightStatus
                            )
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .alert("Cannot Save Flight", isPresented: showValidationAlert, presenting: validationMessage) { _ in
                Button("OK") {
                    validationMessage = nil
                }
            } message: { message in
                Text(message)
            }
            .onAppear {
                if originCode.isEmpty, let first = airports.first {
                    originCode = first.iataCode
                }
                if destinationCode.isEmpty {
                    destinationCode = airports.dropFirst().first?.iataCode ?? airports.first?.iataCode ?? ""
                }
            }
        }
    }

    private func lookupFlight() async {
        isLookingUp = true
        defer { isLookingUp = false }

        do {
            let result = try await FlightLookupService.lookup(
                flightNumber: flightNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                date: scheduledDeparture
            )

            flightNumber = result.flightNumber
            airline = result.airline
            originCode = result.originIATACode
            destinationCode = result.destinationIATACode
            originLatitude = result.originLatitude
            originLongitude = result.originLongitude
            destinationLatitude = result.destinationLatitude
            destinationLongitude = result.destinationLongitude
            originTimezone = result.originTimezone
            destinationTimezone = result.destinationTimezone
            scheduledDeparture = result.scheduledDeparture
            actualDeparture = result.actualDeparture ?? actualDeparture
            includeActualDeparture = result.actualDeparture != nil
            scheduledArrival = result.scheduledArrival
            actualArrival = result.actualArrival
            departureGate = result.departureGate ?? ""
            departureTerminal = result.departureTerminal ?? ""
            arrivalGate = result.arrivalGate ?? ""
            arrivalTerminal = result.arrivalTerminal ?? ""
            baggageClaim = result.baggageClaim ?? ""
            aircraftModel = result.aircraftModel ?? ""
            tailNumber = result.tailNumber ?? ""
            flightStatus = result.status

            if matchedOrigin == nil {
                originName = result.originName ?? result.originIATACode
            }
            if matchedDestination == nil {
                destinationName = result.destinationName ?? result.destinationIATACode
            }
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}

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
    let flightStatus: FlightStatus
}

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
