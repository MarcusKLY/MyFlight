//
//  MapViewContainer.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import SwiftUI
import MapKit

enum FlightMapStyleMode {
    case mutedStandard
    case realisticHybrid

    mutating func toggle() {
        self = self == .mutedStandard ? .realisticHybrid : .mutedStandard
    }
}

struct MapViewContainer: View {
    let flights: [Flight]
    let transitSegments: [TransitSegment]
    @Binding var position: MapCameraPosition
    @Binding var selectedFlight: Flight?
    @Binding var selectedTransit: TransitSegment?
    let mapStyleMode: FlightMapStyleMode
    let filter: ListFilter
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                // MARK: - Flight Routes
                ForEach(visibleFlights) { flight in
                    // Draw geodesic paths
                    let pathCoordinates = generateGeodesicPath(
                        from: flight.origin.coordinate,
                        to: flight.destination.coordinate,
                        steps: 150
                    )

                    let isSelected = selectedFlight?.id == flight.id

                    // Background polyline: all flights as muted grey/white
                    MapPolyline(coordinates: pathCoordinates)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(isSelected ? 0.0 : 0.8),
                                    Color.gray.opacity(isSelected ? 0.0 : 0.45)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isSelected ? 0 : 2
                        )

                    // Highlighted route for selected flight only.
                    if isSelected {
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue.opacity(0.9),
                                        Color.cyan.opacity(0.8)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 4
                            )
                    } else {
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                colorScheme == .light ? 
                                    Color.gray.opacity(0.5) : 
                                    Color.white.opacity(0.22),
                                lineWidth: 1.5
                            )
                    }
                    
                    // Origin airport marker
                    Annotation("", coordinate: flight.origin.coordinate) {
                        AirportMarker(
                            iataCode: flight.origin.iataCode,
                            isOrigin: true,
                            isSelected: isSelected,
                            airport: flight.origin,
                            selectedFlightOriginCode: selectedFlight?.origin.iataCode,
                            selectedFlightDestCode: selectedFlight?.destination.iataCode
                        )
                        .zIndex(isSelected ? 100 : 0)
                    }

                    // Destination airport marker
                    Annotation("", coordinate: flight.destination.coordinate) {
                        AirportMarker(
                            iataCode: flight.destination.iataCode,
                            isOrigin: false,
                            isSelected: isSelected,
                            airport: flight.destination,
                            selectedFlightOriginCode: selectedFlight?.origin.iataCode,
                            selectedFlightDestCode: selectedFlight?.destination.iataCode
                        )
                        .zIndex(isSelected ? 100 : 0)
                    }
                }

                // MARK: - Transit Routes
                ForEach(visibleTransit) { transit in
                    let pathCoordinates = generateGeodesicPath(
                        from: transit.originCoordinate,
                        to: transit.destinationCoordinate,
                        steps: 100
                    )

                    let isSelected = selectedTransit?.id == transit.id
                    let transitColor = transitTypeColor(for: transit.transitType)

                    // Background polyline: all transit as more visible
                    if !isSelected {
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                transitColor.opacity(0.7),
                                lineWidth: 2
                            )
                    }

                    // Highlighted route for selected transit - solid orange
                    if isSelected {
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                Color.orange,
                                lineWidth: 4
                            )
                    }

                    // Origin transit marker - only when selected
                    if isSelected {
                        Annotation("", coordinate: transit.originCoordinate) {
                            TransitMarker(
                                name: shortenName(transit.originName),
                                transitType: transit.transitType,
                                isOrigin: true,
                                isSelected: isSelected
                            )
                        }
                    }

                    // Destination transit marker - only when selected
                    if isSelected {
                        Annotation("", coordinate: transit.destinationCoordinate) {
                            TransitMarker(
                                name: shortenName(transit.destinationName),
                                transitType: transit.transitType,
                                isOrigin: false,
                                isSelected: isSelected
                            )
                        }
                    }
                }
            }
            .mapStyle(mapStyle)
            .ignoresSafeArea()
        }
    }

    private var visibleFlights: [Flight] {
        // Always include selectedFlight even if filter is .transit, otherwise keep current filter
        if filter == .transit, let selected = selectedFlight {
            return [selected]
        }
        return filter == .transit ? [] : flights
    }

    private var visibleTransit: [TransitSegment] {
        // Always include selectedTransit even if filter is .flights, otherwise keep current filter
        if filter == .flights, let selected = selectedTransit {
            return [selected]
        }
        return filter == .flights ? [] : transitSegments
    }

    private var mapStyle: MapStyle {
        switch mapStyleMode {
        case .mutedStandard:
            return .standard(emphasis: .muted)
        case .realisticHybrid:
            return .hybrid(elevation: .realistic)
        }
    }

    private func routeIntensity(for flight: Flight) -> Double {
        if flight.scheduledDeparture >= Date() {
            return 1.0
        }

        let elapsedDays = Calendar.current.dateComponents([.day], from: flight.scheduledDeparture, to: Date()).day ?? 0
        if elapsedDays >= 30 {
            return 0.25
        }

        let remaining = max(0.0, Double(30 - elapsedDays) / 30.0)
        return 0.25 + (remaining * 0.75)
    }

    private func transitTypeColor(for type: TransitType) -> Color {
        switch type {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }

    private func shortenName(_ name: String) -> String {
        let parts = name.components(separatedBy: ",")
        if let first = parts.first?.trimmingCharacters(in: .whitespaces) {
            if first.count > 8 {
                return String(first.prefix(6)) + "…"
            }
            return first
        }
        return name
    }
}

struct AirportMarker: View {
    let iataCode: String
    let isOrigin: Bool
    let isSelected: Bool
    let airport: Airport?  // For accessing visit count
    let selectedFlightOriginCode: String?  // To check if this airport is part of selected flight
    let selectedFlightDestCode: String?

    var dotSize: Double {
        // Scale dot size based on visit count: 6-12pt (reduced from 8-16pt)
        if let airport = airport {
            let size = min(12, 6 + Double(airport.visitCount) * 1.0)
            return size
        }
        return 6
    }

    private var isPartOfSelectedFlight: Bool {
        // Check if this airport is either origin or destination of the selected flight
        if let selectedOrigin = selectedFlightOriginCode, let selectedDest = selectedFlightDestCode {
            return airport?.iataCode == selectedOrigin || airport?.iataCode == selectedDest
        }
        return false
    }

    var body: some View {
        Group {
            if isSelected {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(isOrigin ? Color.green : Color.red)
                            .frame(width: 32, height: 32)
                            .shadow(radius: 6)

                        Text(iataCode)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            } else if !isPartOfSelectedFlight {
                // Only show grey dot if this airport is NOT part of the selected flight
                Circle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: dotSize, height: dotSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1.5)
                            .frame(width: dotSize, height: dotSize)
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 0)
            }
        }
    }
}

// MARK: - Transit Marker

struct TransitMarker: View {
    let name: String
    let transitType: TransitType
    let isOrigin: Bool
    let isSelected: Bool

    private var markerColor: Color {
        switch transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }

    var body: some View {
        Group {
            if isSelected {
                ZStack {
                    Circle()
                        .fill(isOrigin ? markerColor : markerColor.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .shadow(radius: 6)

                    Image(systemName: transitType.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct FlightInfoCard: View {
    let flight: Flight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(flight.airline)
                        .font(.headline)
                    Text(flight.flightNumber)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(flight.dateFormatted)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .center, spacing: 4) {
                    Text(flight.origin.iataCode)
                        .font(.system(size: 16, weight: .bold))
                    Text(flight.origin.name)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Image(systemName: "arrow.right")
                    .foregroundColor(.blue)
                
                VStack(alignment: .center, spacing: 4) {
                    Text(flight.destination.iataCode)
                        .font(.system(size: 16, weight: .bold))
                    Text(flight.destination.name)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

#Preview {
    MapViewContainer(
        flights: [],
        transitSegments: [],
        position: .constant(.automatic),
        selectedFlight: .constant(nil),
        selectedTransit: .constant(nil),
        mapStyleMode: .mutedStandard,
        filter: .all
    )
}
