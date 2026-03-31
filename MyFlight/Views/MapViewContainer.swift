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
    @AppStorage("transitColorBus") private var busColor: String = "orange"
    @AppStorage("transitColorFerry") private var ferryColor: String = "teal"
    @AppStorage("transitColorTrain") private var trainColor: String = "purple"
    @AppStorage("flightColorSelected") private var flightColorSelected: String = "blue"
    @AppStorage("flightColorUnselected") private var flightColorUnselected: String = "gray"
    @AppStorage("routeLineThickness") private var lineThickness: Double = 4.0
    @AppStorage("routeLineStyle") private var lineStyle: String = "dashed"
    @AppStorage("routeLineOpacity") private var lineOpacity: Double = 0.6
    @AppStorage("showFlightDots") private var showFlightDots: Bool = true
    @AppStorage("showTransitDots") private var showTransitDots: Bool = true
    
    private var strokeStyle: StrokeStyle {
        let width = CGFloat(lineThickness * 0.4) // Unselected is thinner
        switch lineStyle {
        case "solid": return StrokeStyle(lineWidth: width)
        case "dotted": return StrokeStyle(lineWidth: width, dash: [2, 4])
        default: return StrokeStyle(lineWidth: width, dash: [8, 6])
        }
    }
    
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
                    let selectedColor = colorFromString(flightColorSelected)
                    let unselectedColor = colorFromString(flightColorUnselected)

                    // Highlighted route for selected flight - solid line
                    if isSelected {
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        selectedColor.opacity(0.9),
                                        selectedColor.opacity(0.7)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: CGFloat(lineThickness)
                            )
                    } else {
                        // Unselected routes - use consistent color regardless of status
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                colorScheme == .light ? 
                                    unselectedColor.opacity(lineOpacity) : 
                                    unselectedColor.opacity(lineOpacity * 0.6),
                                style: strokeStyle
                            )
                    }
                    
                    // Origin airport marker
                    if showFlightDots {
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
                    }

                    // Destination airport marker
                    if showFlightDots {
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

                    // Highlighted route for selected transit - solid line with transit color
                    if isSelected {
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                transitColor,
                                lineWidth: CGFloat(lineThickness)
                            )
                    } else {
                        // Unselected transit routes - use opacity from settings
                        MapPolyline(coordinates: pathCoordinates)
                            .stroke(
                                transitColor.opacity(lineOpacity),
                                style: strokeStyle
                            )
                    }

                    // Origin transit marker - only when selected
                    if isSelected {
                        Annotation("", coordinate: transit.originCoordinate) {
                            TransitMarker(
                                name: shortenName(transit.originName),
                                transitType: transit.transitType,
                                isOrigin: true,
                                isSelected: isSelected,
                                color: transitColor
                            )
                        }
                    } else if showTransitDots {
                        // Small dot for unselected transit origin - smaller and matching outer ring
                        let dotSize: CGFloat = 4
                        Annotation("", coordinate: transit.originCoordinate) {
                            Circle()
                                .fill(transitColor.opacity(0.7))
                                .frame(width: dotSize, height: dotSize)
                                .overlay(
                                    Circle()
                                        .stroke(transitColor.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 0.5)
                        }
                    }

                    // Destination transit marker - only when selected
                    if isSelected {
                        Annotation("", coordinate: transit.destinationCoordinate) {
                            TransitMarker(
                                name: shortenName(transit.destinationName),
                                transitType: transit.transitType,
                                isOrigin: false,
                                isSelected: isSelected,
                                color: transitColor
                            )
                        }
                    } else if showTransitDots {
                        // Small dot for unselected transit destination - smaller and matching outer ring
                        let dotSize: CGFloat = 4
                        Annotation("", coordinate: transit.destinationCoordinate) {
                            Circle()
                                .fill(transitColor.opacity(0.7))
                                .frame(width: dotSize, height: dotSize)
                                .overlay(
                                    Circle()
                                        .stroke(transitColor.opacity(0.5), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.1), radius: 0.5)
                        }
                    }
                }
            }
            .mapStyle(mapStyle)
            .mapControls { }  // Hide all map controls (compass, scale, Apple logo)
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
        case .bus: return colorFromString(busColor)
        case .ferry: return colorFromString(ferryColor)
        case .train: return colorFromString(trainColor)
        }
    }
    
    private func colorFromString(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "teal": return .teal
        case "purple": return .purple
        case "blue": return .blue
        case "cyan": return .cyan
        case "green": return .green
        case "yellow": return .yellow
        case "pink": return .pink
        case "red": return .red
        case "indigo": return .indigo
        default: return .gray
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
        // Scale dot size based on visit count: 4-8pt (smaller and more subtle)
        if let airport = airport {
            let size = min(8, 4 + Double(airport.visitCount) * 0.5)
            return size
        }
        return 4
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
                            .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                            .frame(width: dotSize, height: dotSize)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 0.5, x: 0, y: 0)
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
    let color: Color

    var body: some View {
        Group {
            if isSelected {
                ZStack {
                    Circle()
                        .fill(isOrigin ? color : color.opacity(0.8))
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
