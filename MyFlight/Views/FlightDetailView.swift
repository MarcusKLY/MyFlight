//
//  FlightDetailView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 2026-03-23.
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

                    progressSection
                        .padding(.vertical, 16)

                    Divider()

                    timelineSection
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
            // Date row
            Text(flightDateFormatted)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            // Airline row with logo
            HStack(spacing: 8) {
                AirlineLogoView(airlineIATA: flight.airlineIATA, airlineName: flight.airline, size: 28)
                Text(flight.airline)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
                    if let distance = distanceFormatted {
                        Text(distance)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
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

            if let depDelay = flight.departureDelayMinutes, let arrDelay = flight.arrivalDelayMinutes {
                HStack(spacing: 10) {
                    delayPill(icon: depDelay >= 0 ? "airplane.departure" : "arrow.down.left", text: "Dep \(depDelay >= 0 ? "+\(depDelay)m" : "-\(-depDelay)m")", isDelayed: depDelay > 0)
                    delayPill(icon: arrDelay >= 0 ? "airplane.arrival" : "arrow.down.right", text: "Arr \(arrDelay >= 0 ? "+\(arrDelay)m" : "-\(-arrDelay)m")", isDelayed: arrDelay > 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            } else if let depDelay = flight.departureDelayMinutes {
                delayPill(icon: depDelay >= 0 ? "airplane.departure" : "arrow.down.left", text: "Dep \(depDelay >= 0 ? "+\(depDelay)m" : "-\(-depDelay)m")", isDelayed: depDelay > 0)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            } else if let arrDelay = flight.arrivalDelayMinutes {
                delayPill(icon: arrDelay >= 0 ? "airplane.arrival" : "arrow.down.right", text: "Arr \(arrDelay >= 0 ? "+\(arrDelay)m" : "-\(-arrDelay)m")", isDelayed: arrDelay > 0)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 20)
    }

    private var flightDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        if let tz = flight.origin.timezone, let zone = TimeZone(identifier: tz) {
            formatter.timeZone = zone
        }
        return formatter.string(from: flight.scheduledDeparture)
    }

    private var distanceFormatted: String? {
        if let km = flight.distanceKm {
            let kmInt = Int(km)
            if let nm = flight.distanceNm {
                return "\(kmInt) km (\(Int(nm)) nm)"
            }
            return "\(kmInt) km"
        }
        return nil
    }

    private var statusBadge: some View {
        Text(flightStatusText)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var flightStatusText: String {
        if let actualArrival = flight.actualArrival {
            if let scheduledArrival = flight.scheduledArrival, actualArrival > scheduledArrival {
                return "Arrived Late"
            }
            return "Arrived"
        }

        switch flight.flightStatus {
        case .onTime: return "On Time"
        case .delayed: return "Delayed"
        case .arrived: return "Arrived"
        case .cancelled: return "Cancelled"
        case .enRoute: return "En Route"
        case .departed: return "Departed"
        case .expected: return "Expected"
        }
    }

    private var statusColor: Color {
        if let actualArrival = flight.actualArrival {
            if let scheduledArrival = flight.scheduledArrival, actualArrival > scheduledArrival {
                return Color.orange
            }
            return Color.green
        }

        switch flight.flightStatus {
        case .onTime: return Color.green
        case .delayed: return Color.orange
        case .arrived: return Color.green
        case .cancelled: return Color.red
        case .enRoute: return Color.blue
        case .departed: return Color.blue
        case .expected: return Color.secondary
        }
    }

    // MARK: - Live Progress Bar

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Flight Progress")
            LiveProgressBar(flight: flight)
        }
    }

    // MARK: - Granular Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Timeline")

            HStack(alignment: .top, spacing: 16) {
                departureTimeline
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .frame(height: 160)

                arrivalTimeline
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var departureTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineHeader(
                icon: "airplane.departure",
                title: "Departure",
                iata: flight.origin.iataCode,
                timezone: flight.origin.timezone
            )

            timelineEvent(
                icon: "calendar.badge.clock",
                label: "Scheduled",
                date: flight.scheduledDeparture,
                timezone: flight.origin.timezone,
                style: .scheduled,
                delayMinutes: nil
            )

            if let est = flight.estimatedDeparture, !isSameMinute(est, flight.scheduledDeparture) {
                timelineConnector()
                timelineEvent(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "Estimated",
                    date: est,
                    timezone: flight.origin.timezone,
                    style: .estimated,
                    delayMinutes: minuteDelta(est, from: flight.scheduledDeparture)
                )
            }

            let departureActual = flight.actualDeparture ?? flight.runwayDeparture
            if let dep = departureActual, !isSameMinute(dep, flight.scheduledDeparture) {
                timelineConnector()
                timelineEvent(
                    icon: "door.left.hand.open",
                    label: "Gate Out",
                    date: dep,
                    timezone: flight.origin.timezone,
                    style: dep > flight.scheduledDeparture ? .delayed : .actual,
                    delayMinutes: minuteDelta(dep, from: flight.scheduledDeparture)
                )
            }

            if let takeoff = flight.runwayDeparture ?? flight.actualDeparture, !isSameMinute(takeoff, flight.scheduledDeparture) {
                timelineConnector()
                timelineEvent(
                    icon: "airplane.departure",
                    label: flight.runwayDeparture != nil ? "Takeoff" : "Takeoff (actual)",
                    date: takeoff,
                    timezone: flight.origin.timezone,
                    style: takeoff > flight.scheduledDeparture ? .delayed : .actual,
                    delayMinutes: minuteDelta(takeoff, from: flight.scheduledDeparture)
                )
            }
        }
    }

    private var arrivalTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineHeader(
                icon: "airplane.arrival",
                title: "Arrival",
                iata: flight.destination.iataCode,
                timezone: flight.destination.timezone
            )

            if let scheduled = flight.scheduledArrival {
                timelineEvent(
                    icon: "calendar.badge.clock",
                    label: "Scheduled",
                    date: scheduled,
                    timezone: flight.destination.timezone,
                    style: .scheduled,
                    delayMinutes: nil
                )
                timelineConnector()
            }

            if let est = flight.estimatedArrival, let scheduled = flight.scheduledArrival, !isSameMinute(est, scheduled) {
                timelineEvent(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "Estimated",
                    date: est,
                    timezone: flight.destination.timezone,
                    style: .estimated,
                    delayMinutes: minuteDelta(est, from: scheduled)
                )
                timelineConnector()
            }

            // Show predicted arrival for in-flight flights (more accurate than estimated)
            if let predicted = flight.predictedArrival,
               let scheduled = flight.scheduledArrival,
               !isSameMinute(predicted, scheduled),
               flight.estimatedArrival == nil || !isSameMinute(predicted, flight.estimatedArrival!),
               flight.runwayArrival == nil && flight.actualArrival == nil {
                timelineEvent(
                    icon: "location.fill",
                    label: "Predicted",
                    date: predicted,
                    timezone: flight.destination.timezone,
                    style: predicted > scheduled ? .delayed : .actual,
                    delayMinutes: minuteDelta(predicted, from: scheduled)
                )
                timelineConnector()
            }

            let arrivalLanding = flight.runwayArrival ?? flight.actualArrival
            if let landing = arrivalLanding {
                timelineEvent(
                    icon: "airplane.arrival",
                    label: flight.runwayArrival != nil ? "Landing" : "Landing (actual)",
                    date: landing,
                    timezone: flight.destination.timezone,
                    style: flight.scheduledArrival.map { landing > $0 ? .delayed : .actual } ?? .actual,
                    delayMinutes: flight.scheduledArrival.map { minuteDelta(landing, from: $0) }
                )

                if let actual = flight.actualArrival, !isSameMinute(actual, landing) {
                    timelineConnector()
                } else if flight.actualArrival == nil, flight.runwayArrival != nil {
                    timelineConnector()
                }
            }

            if let gateIn = flight.actualArrival {
                let scheduled = flight.scheduledArrival
                let showGateIn = flight.runwayArrival.map { !isSameMinute($0, gateIn) } ?? true
                if showGateIn {
                    if flight.runwayArrival != nil { timelineConnector() }
                    timelineEvent(
                        icon: "door.right.hand.open",
                        label: "Gate In",
                        date: gateIn,
                        timezone: flight.destination.timezone,
                        style: scheduled.map { gateIn > $0 ? .delayed : .actual } ?? .actual,
                        delayMinutes: scheduled.map { minuteDelta(gateIn, from: $0) } ?? nil
                    )
                    timelineConnector()
                }
            }

            if flight.scheduledArrival == nil && flight.estimatedArrival == nil && flight.predictedArrival == nil && flight.runwayArrival == nil && flight.actualArrival == nil {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }

    private func timelineHeader(icon: String, title: String, iata: String, timezone: String?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text("\(title) · \(iata)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            if let tz = timezone {
                Text(abbreviatedTimezone(identifier: tz))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.bottom, 8)
    }

    private enum TimelineEventStyle {
        case scheduled, estimated, actual, delayed
    }

    private func timelineEvent(
        icon: String,
        label: String,
        date: Date,
        timezone: String?,
        style: TimelineEventStyle,
        delayMinutes: Int?
    ) -> some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .fill(eventColor(style).opacity(0.15))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(eventColor(style))
            }
            .frame(width: 26, height: 26)
            .background(Color(.systemBackground))
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    // Airport time
                    Text(localTime(date: date, timezone: timezone))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(eventColor(style))

                    // Device local time (for reference)
                    Text("(\(deviceLocalTime(date)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let delta = delayMinutes {
                        Text(delayLabel(delta))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(delta > 0 ? .orange : .green)
                    }
                }
            }
        }
    }

    private func deviceLocalTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    private func timelineConnector() -> some View {
        HStack {
            Spacer().frame(width: 11)
            Rectangle()
                .fill(Color.secondary.opacity(0.25))
                .frame(width: 2, height: 10)
        }
    }

    private func delayPill(icon: String, text: String, isDelayed: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isDelayed ? Color.red : Color.green).opacity(0.15))
        .foregroundStyle(isDelayed ? .red : .green)
        .clipShape(Capsule())
    }

    private func eventColor(_ style: TimelineEventStyle) -> Color {
        switch style {
        case .scheduled: return .secondary
        case .estimated: return .blue
        case .actual: return .green
        case .delayed: return .red
        }
    }

    private func delayLabel(_ minutes: Int) -> String {
        if minutes > 0 { return "+\(minutes)m" }
        return "\(minutes)m"
    }

    // MARK: - Gates & Terminal Section

    private var hasGateOrTerminalInfo: Bool {
        flight.departureGate != nil || flight.departureTerminal != nil ||
        flight.arrivalGate != nil || flight.arrivalTerminal != nil ||
        flight.baggageClaim != nil || flight.departureCheckInDesk != nil ||
        flight.departureRunway != nil || flight.arrivalRunway != nil
    }

    private var gatesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Gates & Terminals")

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "airplane.departure", label: "Dep Terminal", value: flight.departureTerminal)
                    infoRow(icon: "door.left.hand.open", label: "Dep Gate", value: flight.departureGate)
                    infoRow(icon: "checklist", label: "Check-in", value: flight.departureCheckInDesk)
                    infoRow(icon: "road.lanes", label: "Dep Runway", value: flight.departureRunway)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "airplane.arrival", label: "Arr Terminal", value: flight.arrivalTerminal)
                    infoRow(icon: "door.right.hand.open", label: "Arr Gate", value: flight.arrivalGate)
                    infoRow(icon: "suitcase.rolling", label: "Baggage", value: flight.baggageClaim)
                    infoRow(icon: "road.lanes", label: "Arr Runway", value: flight.arrivalRunway)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Aircraft Section

    private var hasAircraftInfo: Bool {
        flight.aircraftModel != nil || flight.tailNumber != nil || flight.callSign != nil
    }

    private var aircraftSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Aircraft")

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "airplane.circle", label: "Type", value: flight.aircraftModel)
                    infoRow(icon: "tag", label: "Tail", value: flight.tailNumber)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "antenna.radiowaves.left.and.right", label: "Call Sign", value: flight.callSign)
                }
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

    private func minuteDelta(_ date: Date, from reference: Date) -> Int {
        Int(date.timeIntervalSince(reference) / 60)
    }

    private func isSameMinute(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, equalTo: b, toGranularity: .minute)
    }
}

// MARK: - Live Progress Bar

struct LiveProgressBar: View {
    let flight: Flight

    private var progress: Double {
        flight.flightProgress ?? progressFromScheduled
    }

    private var progressFromScheduled: Double {
        // For arrived flights, always show 100%
        if flight.runwayArrival != nil || flight.actualArrival != nil {
            return 1.0
        }

        guard let arrival = flight.predictedArrival ?? flight.estimatedArrival ?? flight.scheduledArrival else { return 0 }
        let departure = flight.runwayDeparture ?? flight.actualDeparture ?? flight.scheduledDeparture
        let now = Date()
        guard now >= departure else { return 0 }
        guard now <= arrival else { return 1 }
        let total = arrival.timeIntervalSince(departure)
        guard total > 0 else { return 0 }
        return now.timeIntervalSince(departure) / total
    }

    private var isInFlight: Bool {
        // Check if flight has landed
        if flight.runwayArrival != nil || flight.actualArrival != nil {
            return false
        }
        let departure = flight.runwayDeparture ?? flight.actualDeparture ?? flight.scheduledDeparture
        let arrival = flight.predictedArrival ?? flight.estimatedArrival ?? flight.scheduledArrival ?? Date.distantFuture
        let now = Date()
        return now >= departure && now <= arrival
    }

    private var statusText: String {
        let p = progress
        if p <= 0 {
            let dep = flight.estimatedDeparture ?? flight.scheduledDeparture
            let mins = Int(dep.timeIntervalSinceNow / 60)
            if mins > 0 { return "Departs in \(mins)m" }
            return "Not departed"
        }
        if p >= 1 { return "Arrived" }
        if let arrival = flight.predictedArrival ?? flight.runwayArrival ?? flight.actualArrival ?? flight.estimatedArrival ?? flight.scheduledArrival {
            let minsLeft = Int(arrival.timeIntervalSinceNow / 60)
            if minsLeft > 0 { return "Arrives in \(minsLeft)m" }
        }
        return String(format: "%.0f%% complete", p * 100)
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 6)

                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(6, geo.size.width * progress), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: progress)

                    // Airplane icon
                    let iconOffset = max(0, min(geo.size.width - 20, geo.size.width * progress - 10))
                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.blue)
                        .offset(x: iconOffset, y: -12)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
                .padding(.top, 16)
            }
            .frame(height: 36)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.origin.iataCode)
                        .font(.caption2)
                        .fontWeight(.bold)
                    let depTime = (flight.runwayDeparture ?? flight.actualDeparture) ?? flight.scheduledDeparture
                    let isDeparted = flight.runwayDeparture != nil || flight.actualDeparture != nil
                    Text(localTime(date: depTime, timezone: flight.origin.timezone))
                        .font(.caption2)
                        .foregroundStyle(isDeparted ? .blue : .secondary)
                        .fontWeight(isDeparted ? .semibold : .regular)
                }

                Spacer()

                Text(statusText)
                    .font(.caption2)
                    .foregroundStyle(isInFlight ? .blue : .secondary)
                    .fontWeight(isInFlight ? .semibold : .regular)

                Spacer()

                if let arrival = flight.scheduledArrival {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(flight.destination.iataCode)
                            .font(.caption2)
                            .fontWeight(.bold)
                        let arrTime = (flight.runwayArrival ?? flight.actualArrival) ?? flight.scheduledArrival ?? arrival
                        let hasArrived = flight.runwayArrival != nil || flight.actualArrival != nil
                        Text(localTime(date: arrTime, timezone: flight.destination.timezone))
                            .font(.caption2)
                            .foregroundStyle(hasArrived ? .green : .secondary)
                            .fontWeight(hasArrived ? .semibold : .regular)
                    }
                }
            }
        }
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
        scheduledDeparture: now.addingTimeInterval(-3 * 3600),
        estimatedDeparture: now.addingTimeInterval(-3 * 3600 + 900),
        actualDeparture: now.addingTimeInterval(-3 * 3600 + 1320),
        runwayDeparture: now.addingTimeInterval(-3 * 3600 + 2280),
        runwayArrival: now.addingTimeInterval(7 * 3600 - 1200),
        estimatedArrival: now.addingTimeInterval(7 * 3600 - 300),
        scheduledArrival: now.addingTimeInterval(7 * 3600),
        actualArrival: nil,
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

