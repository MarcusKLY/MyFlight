//
//  FlightDetailView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import SwiftUI

struct FlightDetailView: View {
    let flight: Flight

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    routeHeader
                        .padding(.bottom, 20)

                    Divider()

                    timingsSection
                        .padding(.vertical, 16)

                    Divider()

                    if hasGateOrTerminalInfo {
                        gatesSection
                            .padding(.vertical, 16)
                        Divider()
                    }

                    if hasAircraftInfo {
                        aircraftSection
                            .padding(.vertical, 16)
                        Divider()
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle(flight.flightNumber)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Route Header

    private var routeHeader: some View {
        VStack(spacing: 12) {
            Text(flight.airline)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 4) {
                    Text(flight.origin.iataCode)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(cityName(for: flight.origin))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Image(systemName: "airplane")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    if let duration = flight.durationFormatted {
                        Text(duration)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(flight.destination.iataCode)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                    Text(cityName(for: flight.destination))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            statusBadge
        }
        .padding(.top, 20)
    }

    private var statusBadge: some View {
        Text(flight.flightStatus.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    // MARK: - Timings Section

    private var timingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Times")

            HStack(alignment: .top) {
                timingColumn(
                    title: "Departure",
                    airport: flight.origin,
                    scheduled: flight.scheduledDeparture,
                    actual: flight.actualDeparture
                )

                Spacer()

                if let scheduledArrival = flight.scheduledArrival {
                    timingColumn(
                        title: "Arrival",
                        airport: flight.destination,
                        scheduled: scheduledArrival,
                        actual: flight.actualArrival
                    )
                }
            }
        }
    }

    private func timingColumn(title: String, airport: Airport, scheduled: Date, actual: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(localTime(date: scheduled, timezone: airport.timezone))
                .font(.system(size: 28, weight: .semibold, design: .rounded))

            Text(localDate(date: scheduled, timezone: airport.timezone))
                .font(.caption)
                .foregroundStyle(.secondary)

            if let tz = airport.timezone {
                Text(abbreviatedTimezone(identifier: tz))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if let actual {
                let isDelayed = actual > scheduled
                HStack(spacing: 4) {
                    Image(systemName: isDelayed ? "clock.badge.exclamationmark" : "checkmark.circle")
                        .font(.caption2)
                    Text("Actual: \(localTime(date: actual, timezone: airport.timezone))")
                        .font(.caption2)
                }
                .foregroundStyle(isDelayed ? Color.orange : Color.green)
            }
        }
    }

    // MARK: - Gates & Terminal Section

    private var hasGateOrTerminalInfo: Bool {
        flight.departureGate != nil || flight.departureTerminal != nil ||
        flight.arrivalGate != nil || flight.arrivalTerminal != nil ||
        flight.baggageClaim != nil
    }

    private var gatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Gates & Terminals")

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "airplane.departure", label: "Dep Terminal", value: flight.departureTerminal)
                    infoRow(icon: "door.left.hand.open", label: "Dep Gate", value: flight.departureGate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "airplane.arrival", label: "Arr Terminal", value: flight.arrivalTerminal)
                    infoRow(icon: "door.right.hand.open", label: "Arr Gate", value: flight.arrivalGate)
                    infoRow(icon: "suitcase.rolling", label: "Baggage", value: flight.baggageClaim)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Aircraft Section

    private var hasAircraftInfo: Bool {
        flight.aircraftModel != nil || flight.tailNumber != nil
    }

    private var aircraftSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Aircraft")

            HStack(alignment: .top, spacing: 0) {
                infoRow(icon: "airplane.circle", label: "Type", value: flight.aircraftModel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                infoRow(icon: "tag", label: "Tail", value: flight.tailNumber)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func infoRow(icon: String, label: String, value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    private var statusColor: Color {
        switch flight.flightStatus {
        case .onTime: return .green
        case .delayed: return .orange
        case .cancelled: return .red
        }
    }

    private func cityName(for airport: Airport) -> String {
        let words = airport.name.components(separatedBy: " ")
        guard words.count > 1 else { return airport.name }
        return words.prefix(2).joined(separator: " ")
    }

    private func localTime(date: Date, timezone: String?) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        if let tz = timezone, let zone = TimeZone(identifier: tz) {
            f.timeZone = zone
        }
        return f.string(from: date)
    }

    private func localDate(date: Date, timezone: String?) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        if let tz = timezone, let zone = TimeZone(identifier: tz) {
            f.timeZone = zone
        }
        return f.string(from: date)
    }

    private func abbreviatedTimezone(identifier: String) -> String {
        guard let zone = TimeZone(identifier: identifier) else { return identifier }
        return zone.abbreviation() ?? identifier
    }
}

#Preview {
    let origin = Airport(iataCode: "HKG", name: "Hong Kong International", latitude: 22.308, longitude: 113.918, timezone: "Asia/Hong_Kong")
    let destination = Airport(iataCode: "HEL", name: "Helsinki-Vantaa", latitude: 60.317, longitude: 25.046, timezone: "Europe/Helsinki")
    let now = Date()
    let flight = Flight(
        flightNumber: "CX886",
        airline: "Cathay Pacific",
        origin: origin,
        destination: destination,
        scheduledDeparture: now,
        actualDeparture: now.addingTimeInterval(600),
        scheduledArrival: now.addingTimeInterval(10 * 3600),
        actualArrival: now.addingTimeInterval(10 * 3600 - 300),
        departureGate: "B36",
        departureTerminal: "1",
        arrivalGate: "A8",
        arrivalTerminal: "2",
        baggageClaim: "12",
        aircraftModel: "Boeing 777-300ER",
        tailNumber: "B-KPZ",
        flightStatus: .onTime
    )
    return FlightDetailView(flight: flight)
}
