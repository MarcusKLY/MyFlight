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
                                Color.white.opacity(0.22),
                                lineWidth: 1.5
                            )
                    }
                    
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

                    Text(iataCode)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(4)
                }
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 8, height: 8)
                    .shadow(color: Color.black.opacity(0.15), radius: 1, x: 0, y: 0)
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
        position: .constant(.automatic),
        selectedFlight: .constant(nil),
        mapStyleMode: .mutedStandard
    )
}
