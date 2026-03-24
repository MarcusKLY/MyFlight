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
    @Binding var position: MapCameraPosition
    @Binding var selectedFlight: Flight?
    let mapStyleMode: FlightMapStyleMode
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                ForEach(flights) { flight in
                    // Draw geodesic paths
                    let pathCoordinates = generateGeodesicPath(
                        from: flight.origin.coordinate,
                        to: flight.destination.coordinate,
                        steps: 150
                    )

                    let routeIntensity = routeIntensity(for: flight)
                    let isSelected = selectedFlight?.id == flight.id
                    let selectionBoost = isSelected ? 1.25 : 1.0

                    // Subtle glow pass behind the main route.
                    MapPolyline(coordinates: pathCoordinates)
                        .stroke(
                            Color.cyan.opacity(min(0.5, 0.15 * routeIntensity * selectionBoost)),
                            lineWidth: isSelected ? 10 : 7
                        )

                    MapPolyline(coordinates: pathCoordinates)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.blue.opacity(min(1.0, 0.35 + 0.45 * routeIntensity * selectionBoost)),
                                    Color.cyan.opacity(min(1.0, 0.25 + 0.45 * routeIntensity * selectionBoost))
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: isSelected ? 4 : 3
                        )
                    
                    // Origin airport marker
                    Annotation("", coordinate: flight.origin.coordinate) {
                        AirportMarker(
                            iataCode: flight.origin.iataCode,
                            isOrigin: true,
                            isSelected: isSelected
                        )
                    }
                    
                    // Destination airport marker
                    Annotation("", coordinate: flight.destination.coordinate) {
                        AirportMarker(
                            iataCode: flight.destination.iataCode,
                            isOrigin: false,
                            isSelected: isSelected
                        )
                    }
                }
            }
            .mapStyle(mapStyle)
            .ignoresSafeArea()
        }
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
}

struct AirportMarker: View {
    let iataCode: String
    let isOrigin: Bool
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isOrigin ? Color.green : Color.red)
                    .frame(width: 32, height: 32)
                    .shadow(radius: isSelected ? 8 : 4)
                
                Text(iataCode)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Text(iataCode)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.primary)
                .background(Color.white.opacity(0.8))
                .cornerRadius(3)
                .padding(.horizontal, 4)
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
        position: .constant(.automatic),
        selectedFlight: .constant(nil),
        mapStyleMode: .mutedStandard
    )
}
