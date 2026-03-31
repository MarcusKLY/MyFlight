//
//  AddTransitSheet.swift
//  MyFlight
//
//  Created by Copilot on 27/3/2026.
//

import SwiftUI
import MapKit

struct AddTransitSheet: View {
    let onSave: (TransitSegment) -> Void

    @Environment(\.dismiss) private var dismiss

    // Transit type
    @State private var transitType: TransitType = .bus

    // Basic info
    @State private var operatorName = ""
    @State private var routeNumber = ""

    // Origin
    @State private var originName = ""
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var showOriginSearch = false

    // Destination
    @State private var destinationName = ""
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var showDestinationSearch = false

    // Times
    @State private var departureDate = Date()
    @State private var arrivalDate = Date().addingTimeInterval(3600)

    // Notes
    @State private var notes = ""

    private var canSave: Bool {
        !operatorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !originName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !destinationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        originCoordinate != nil &&
        destinationCoordinate != nil &&
        arrivalDate > departureDate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)

                    Text("Add Transit")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button(action: saveTransit) {
                        Text("Save")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 50, height: 36)
                    }
                    .foregroundStyle(canSave ? .blue : .gray)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(Color(.systemGroupedBackground))

                ScrollView {
                    VStack(spacing: 24) {
                        // Transit Type Picker
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("TYPE")

                            Picker("Transit Type", selection: $transitType) {
                                ForEach(TransitType.allCases) { type in
                                    Label(type.rawValue, systemImage: type.icon)
                                        .tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        // Operator & Route
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("OPERATOR")

                            TextField("e.g. FlixBus, SNCF, Brittany Ferries", text: $operatorName)
                                .font(.system(size: 17))
                                .padding()
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))

                            TextField("Route Number (optional)", text: $routeNumber)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .padding()
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Origin
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("FROM")

                            Button {
                                showOriginSearch = true
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(transitTypeColor)
                                    Text(originName.isEmpty ? "Search location..." : originName)
                                        .foregroundStyle(originName.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        // Destination
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("TO")

                            Button {
                                showDestinationSearch = true
                            } label: {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(transitTypeColor)
                                    Text(destinationName.isEmpty ? "Search location..." : destinationName)
                                        .foregroundStyle(destinationName.isEmpty ? .secondary : .primary)
                                    Spacer()
                                    Image(systemName: "magnifyingglass")
                                        .foregroundStyle(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }

                        // Departure Time
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("DEPARTURE")

                            DatePicker(
                                "Departure",
                                selection: $departureDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity)
                            .onChange(of: departureDate) { _, newValue in
                                if arrivalDate <= newValue {
                                    arrivalDate = newValue.addingTimeInterval(3600)
                                }
                            }
                        }

                        // Arrival Time
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("ARRIVAL")

                            DatePicker(
                                "Arrival",
                                selection: $arrivalDate,
                                in: departureDate...,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            .frame(maxWidth: .infinity)

                            if arrivalDate > departureDate {
                                Text("Duration: \(durationText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Notes
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("NOTES (OPTIONAL)")

                            TextField("Booking reference, seat number, etc.", text: $notes, axis: .vertical)
                                .font(.system(size: 15))
                                .lineLimit(3...6)
                                .padding()
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                        }

                        Spacer(minLength: 40)
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showOriginSearch) {
                LocationSearchSheet(
                    title: "Departure Location",
                    transitType: transitType
                ) { name, coordinate in
                    originName = name
                    originCoordinate = coordinate
                }
            }
            .sheet(isPresented: $showDestinationSearch) {
                LocationSearchSheet(
                    title: "Arrival Location",
                    transitType: transitType
                ) { name, coordinate in
                    destinationName = name
                    destinationCoordinate = coordinate
                }
            }
        }
    }

    private var transitTypeColor: Color {
        switch transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }

    private var durationText: String {
        let interval = arrivalDate.timeIntervalSince(departureDate)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.secondary)
    }

    private func saveTransit() {
        guard let origin = originCoordinate, let destination = destinationCoordinate else { return }

        let transit = TransitSegment(
            transitType: transitType,
            routeNumber: routeNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            operatorName: operatorName.trimmingCharacters(in: .whitespacesAndNewlines),
            originName: originName,
            originLatitude: origin.latitude,
            originLongitude: origin.longitude,
            destinationName: destinationName,
            destinationLatitude: destination.latitude,
            destinationLongitude: destination.longitude,
            scheduledDeparture: departureDate,
            scheduledArrival: arrivalDate,
            notes: notes.isEmpty ? nil : notes
        )

        onSave(transit)
        dismiss()
    }
}

// MARK: - Location Search Sheet

struct LocationSearchSheet: View {
    let title: String
    let transitType: TransitType
    let onSelect: (String, CLLocationCoordinate2D) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search for a location...", text: $searchText)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .onSubmit {
                            Task { await search() }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                .padding()

                // Results
                if isSearching {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if searchResults.isEmpty && !searchText.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "mappin.slash",
                        description: Text("Try a different search term")
                    )
                } else {
                    List(searchResults, id: \.self) { item in
                        Button {
                            selectLocation(item)
                        } label: {
                            HStack {
                                Image(systemName: iconForMapItem(item))
                                    .foregroundStyle(transitTypeColor)
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name ?? "Unknown")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.primary)

                                    if let address = formatAddress(item) {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onChange(of: searchText) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                await search()
            }
        }
    }

    private var transitTypeColor: Color {
        switch transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }

    private func search() async {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        defer { isSearching = false }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        
        // Don't restrict to POI categories - allow searching for any location
        // Users may want to search for cities, addresses, landmarks, etc.
        request.resultTypes = [.address, .pointOfInterest]

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            searchResults = response.mapItems
        } catch {
            searchResults = []
        }
    }

    private func selectLocation(_ item: MKMapItem) {
        let name = item.name ?? "Unknown Location"
        let coordinate = item.placemark.coordinate
        onSelect(name, coordinate)
        dismiss()
    }

    private func iconForMapItem(_ item: MKMapItem) -> String {
        if let category = item.pointOfInterestCategory {
            switch category {
            case .publicTransport:
                return transitType.icon
            case .marina:
                return "ferry.fill"
            default:
                return "mappin.circle.fill"
            }
        }
        return "mappin.circle.fill"
    }

    private func formatAddress(_ item: MKMapItem) -> String? {
        let placemark = item.placemark
        var parts: [String] = []

        if let locality = placemark.locality {
            parts.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            parts.append(administrativeArea)
        }
        if let country = placemark.country, parts.isEmpty {
            parts.append(country)
        }

        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}
