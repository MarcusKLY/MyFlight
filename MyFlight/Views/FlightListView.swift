//
//  FlightListView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import SwiftUI
import MapKit

struct FlightListView: View {
    let flights: [Flight]
    @Binding var selectedFlight: Flight?
    @Binding var mapPosition: MapCameraPosition
    let onDeleteFlight: (Flight) -> Void
    let onCycleStatus: (Flight) -> Void

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
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Flight History")
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            List {
                Section("Upcoming Flights") {
                    if upcomingFlights.isEmpty {
                        Text("No upcoming flights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(upcomingFlights) { flight in
                            tappableItem(for: flight)
                        }
                    }
                }

                Section("Past Flights") {
                    if pastFlights.isEmpty {
                        Text("No past flights")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(pastFlights) { flight in
                            tappableItem(for: flight)
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
        .background(Color(.systemBackground))
    }

    private func tappableItem(for flight: Flight) -> some View {
        FlightListItemView(flight: flight)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    selectedFlight = flight
                    // Calculate region that encompasses both airports.
                    let midLat = (flight.origin.coordinate.latitude + flight.destination.coordinate.latitude) / 2
                    let midLon = (flight.origin.coordinate.longitude + flight.destination.coordinate.longitude) / 2
                    let midpoint = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)

                    // Calculate appropriate zoom level.
                    let latDelta = abs(flight.destination.coordinate.latitude - flight.origin.coordinate.latitude) * 1.5
                    let lonDelta = abs(flight.destination.coordinate.longitude - flight.origin.coordinate.longitude) * 1.5

                    let region = MKCoordinateRegion(
                        center: midpoint,
                        span: MKCoordinateSpan(latitudeDelta: max(latDelta, 10), longitudeDelta: max(lonDelta, 10))
                    )

                    mapPosition = .region(region)
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    onDeleteFlight(flight)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    onCycleStatus(flight)
                } label: {
                    Label("Cycle Status", systemImage: "arrow.triangle.2.circlepath")
                }
                .tint(.blue)
            }
    }
}

struct FlightListItemView: View {
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
                Text(flight.dateFormatted)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.origin.iataCode)
                        .font(.system(size: 14, weight: .bold))
                    Text(flight.origin.name)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack(spacing: 2) {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Flight")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.destination.iataCode)
                        .font(.system(size: 14, weight: .bold))
                    Text(flight.destination.name)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }

            HStack(spacing: 8) {
                Text(flight.flightStatus.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.15))
                    .foregroundColor(statusColor)
                    .clipShape(Capsule())

                if let gate = flight.arrivalGate, !gate.isEmpty {
                    Text("Gate \(gate)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let baggage = flight.baggageClaim, !baggage.isEmpty {
                    Text("Bags \(baggage)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 8)
    }

    private var statusColor: Color {
        switch flight.flightStatus {
        case .onTime:
            return .green
        case .delayed:
            return .orange
        case .cancelled:
            return .red
        }
    }
}

#Preview {
    FlightListView(
        flights: [],
        selectedFlight: .constant(nil),
        mapPosition: .constant(.automatic),
        onDeleteFlight: { _ in },
        onCycleStatus: { _ in }
    )
}
