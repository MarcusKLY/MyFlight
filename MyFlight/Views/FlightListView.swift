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
    let onSelectFlight: (Flight) -> Void
    let onDeleteFlight: (Flight) -> Void

    // Haptic feedback
    private let selectionHaptic = UIImpactFeedbackGenerator(style: .medium)
    private let deleteHaptic = UINotificationFeedbackGenerator()

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
        Group {
            if flights.isEmpty {
                // Beautiful empty state (UX Upgrade 3)
                EmptyFlightsView()
            } else {
                flightList
            }
        }
        .onAppear {
            selectionHaptic.prepare()
            deleteHaptic.prepare()
        }
    }

    private var flightList: some View {
        List {
            // Upcoming Flights Section
            Section {
                if upcomingFlights.isEmpty {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.secondary)
                        Text("No upcoming flights")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(upcomingFlights) { flight in
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
                    }
                }
            } header: {
                SectionHeader(title: "Upcoming", count: upcomingFlights.count, icon: "airplane.departure")
            }

            // Past Flights Section
            Section {
                if pastFlights.isEmpty {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                        Text("No past flights")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(pastFlights) { flight in
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
                    }
                }
            } header: {
                SectionHeader(title: "Past Flights", count: pastFlights.count, icon: "airplane.arrival")
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    let count: Int
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            if count > 0 {
                Text("\(count)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue, in: Capsule())
            }

            Spacer()
        }
    }
}

// MARK: - Empty State View (UX Upgrade 3)

struct EmptyFlightsView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Flights Yet", systemImage: "airplane.departure")
        } description: {
            Text("Your flight journey starts here. Tap the + button to add your first flight and start tracking your adventures.")
        } actions: {
            Text("Swipe up to explore the map")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .symbolEffect(.pulse.byLayer, options: .repeating)
    }
}

// MARK: - Flight List Item View (Enhanced)

struct FlightListItemView: View {
    let flight: Flight
    let isSelected: Bool
    let isUpcoming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Airline logo, flight number, and date
            HStack {
                HStack(spacing: 8) {
                    AirlineLogoView(airlineIATA: flight.airlineIATA, airlineName: flight.airline, size: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.airline)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        Text(flight.flightNumber)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(smartDateFormat)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    if isUpcoming, let countdown = countdownText {
                        Text(countdown)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(countdownGradient)
                    }
                }
            }

            // Route row with visual flight line
            HStack(spacing: 0) {
                // Origin
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.origin.iataCode)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Sch: \(flight.formattedDeparture())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        if let actual = flight.actualDeparture, !Calendar.current.isDate(actual, equalTo: flight.scheduledDeparture, toGranularity: .minute) {
                            Text("Act: \(flight.formattedDeparture(actual: true))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 80, alignment: .leading)

                // Flight progress line
                FlightProgressLine(
                    progress: currentProgress,
                    isInFlight: isInFlight,
                    duration: flight.durationFormatted,
                    status: flight.flightStatus,
                    isDelayed: (flight.arrivalDelayMinutes ?? 0) > 0
                )

                // Destination
                VStack(alignment: .trailing, spacing: 2) {
                    Text(flight.destination.iataCode)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Sch: \(flight.formattedArrival())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        if let actual = flight.actualArrival, let scheduled = flight.scheduledArrival, !Calendar.current.isDate(actual, equalTo: scheduled, toGranularity: .minute) {
                            Text("Act: \(flight.formattedArrival(actual: true))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }

            // Status badges row
            HStack(spacing: 8) {
                StatusBadge(status: flight.flightStatus)

                if let delay = flight.departureDelayMinutes, delay > 0 {
                    DelayBadge(minutes: delay)
                }

                if let arrivalDelay = flight.arrivalDelayMinutes, arrivalDelay > 0 {
                    DelayBadge(minutes: arrivalDelay)
                }

                if let gate = flight.departureGate, !gate.isEmpty {
                    InfoChip(icon: "door.left.hand.open", text: "Gate \(gate)")
                }

                if let terminal = flight.departureTerminal, !terminal.isEmpty {
                    InfoChip(icon: "building.2", text: "T\(terminal)")
                }

                Spacer()

                if let aircraft = flight.aircraftModel, !aircraft.isEmpty {
                    Text(aircraft)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }

    // Computed progress - no timer needed
    private var currentProgress: Double {
        if isInFlight {
            return flight.flightProgress ?? 0
        } else if !isUpcoming {
            return 1.0 // Past flight
        } else {
            return 0.0 // Future flight
        }
    }

    private var isInFlight: Bool {
        guard let progress = flight.flightProgress else { return false }
        return progress > 0 && progress < 1
    }

    // Smart date formatting - relative for recent/near dates
    private var smartDateFormat: String {
        let calendar = Calendar.current
        let now = Date()
        let flightDate = flight.scheduledDeparture

        if calendar.isDateInToday(flightDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(flightDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(flightDate) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: flightDate).day ?? 0
            if days > 0 && days <= 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE" // Day name
                return formatter.string(from: flightDate)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: flightDate)
            }
        }
    }

    private var countdownText: String? {
        let interval = flight.scheduledDeparture.timeIntervalSinceNow
        guard interval > 0 else { return nil }

        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60

        if hours > 48 {
            let days = hours / 24
            return "in \(days)d"
        } else if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "in \(minutes)m"
        } else {
            return "now"
        }
    }

    private var countdownGradient: LinearGradient {
        let hours = flight.scheduledDeparture.timeIntervalSinceNow / 3600

        if hours < 2 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if hours < 12 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Flight Progress Line

struct FlightProgressLine: View {
    let progress: Double
    let isInFlight: Bool
    let duration: String?
    let status: FlightStatus
    let isDelayed: Bool

    private var lineGradient: LinearGradient {
        if isInFlight {
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        }
        if status == .arrived {
            return LinearGradient(colors: isDelayed ? [.orange, .red] : [.green, .green.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
        if status == .departed || status == .enRoute {
            return LinearGradient(colors: [.blue.opacity(0.6), .blue.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
        }
        if status == .delayed {
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 3)

                // Progress fill
                GeometryReader { geo in
                    Capsule()
                        .fill(lineGradient)
                        .frame(width: geo.size.width * progress, height: 3)
                }
                .frame(height: 3)

                // Airplane indicator (only when in flight)
                if isInFlight {
                    GeometryReader { geo in
                        Image(systemName: "airplane")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.blue)
                            .offset(x: max(0, min(geo.size.width - 12, geo.size.width * progress - 6)))
                    }
                    .frame(height: 12)
                }
            }
            .frame(height: 12)

            // Duration label
            if let duration {
                Text(duration)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Status Badge with Gradient

struct StatusBadge: View {
    let status: FlightStatus

    var body: some View {
        Text(status.rawValue)
            .font(.system(size: 10, weight: .bold))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusGradient, in: Capsule())
            .foregroundColor(.white)
    }

    private var statusGradient: LinearGradient {
        switch status {
        case .onTime:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .delayed:
            return LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arrived:
            return LinearGradient(
                colors: [Color.green, Color.green.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cancelled:
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .enRoute:
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .departed:
            return LinearGradient(
                colors: [Color.blue, Color.blue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .expected:
            return LinearGradient(
                colors: [Color.gray, Color.gray.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Delay Badge

struct DelayBadge: View {
    let minutes: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 9))
            Text("+\(minutes)m")
                .font(.system(size: 10, weight: .bold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15), in: Capsule())
        .foregroundColor(.orange)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

// MARK: - Info Chip

struct InfoChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundColor(.secondary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview {
    FlightListView(
        flights: [],
        selectedFlight: .constant(nil),
        onSelectFlight: { _ in },
        onDeleteFlight: { _ in }
    )
}
