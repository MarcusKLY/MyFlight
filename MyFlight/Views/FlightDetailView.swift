//
//  FlightDetailView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 2026-03-23.
//

import SwiftUI
import SwiftData

struct FlightDetailView: View {
    let flight: Flight

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var isRefreshing = false
    @State private var isFlipped = false

    // Keep both card faces the same size to prevent layout jumps when flipping.
    private let aircraftHeroHeight: CGFloat = 190
    private let sideViewVerticalPadding: CGFloat = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Centered title with balanced side controls
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)

                    Text(flight.flightNumber)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button {
                        Task { await refreshFlight() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: 36, height: 36)
                        }
                    }
                    .foregroundStyle(.blue)
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh flight status")
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .background(Color(.systemGroupedBackground))

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
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Route Header

    private var flightDateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        if let tz = flight.origin.timezone, let zone = TimeZone(identifier: tz) {
            formatter.timeZone = zone
        }
        return formatter.string(from: flight.scheduledDeparture)
    }

    private var arrivalDayOffset: Int {
        guard let scheduledArrival = flight.scheduledArrival else { return 0 }
        return dayOffset(
            departure: flight.scheduledDeparture,
            departureTimezone: flight.origin.timezone,
            arrival: scheduledArrival,
            arrivalTimezone: flight.destination.timezone
        )
    }

    private var arrivalDayOffsetSuffix: String? {
        guard arrivalDayOffset > 0 else { return nil }
        return "+\(arrivalDayOffset)"
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
        if flight.computedFlightStatus == .arrived {
            if let delay = flight.arrivalDelayMinutes, delay > 0 {
                return "Arrived Late"
            }
            return "Arrived"
        }

        if flight.computedFlightStatus == .enRoute {
            return "En Route"
        }

        switch flight.computedFlightStatus {
        case .onTime: return "On Time"
        case .delayed: return "Delayed"
        case .cancelled: return "Cancelled"
        case .departed: return "Departed"
        case .expected: return "Expected"
        default: return flight.computedFlightStatus.rawValue
        }
    }

    private var statusColor: Color {
        if flight.computedFlightStatus == .arrived {
            if let delay = flight.arrivalDelayMinutes, delay > 0 {
                return Color.orange
            }
            return Color.green
        }

        switch flight.computedFlightStatus {
        case .onTime: return Color.green
        case .delayed: return Color.orange
        case .cancelled: return Color.red
        case .enRoute: return Color.blue
        case .departed: return Color.blue
        case .expected: return Color.secondary
        default: return Color.secondary
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
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Timeline")

            HStack(alignment: .top, spacing: 16) {
                departureTimeline
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

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

            let events = departureTimelineEvents
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                if index > 0 { timelineConnector() }
                timelineEvent(
                    icon: event.icon,
                    label: event.label,
                    date: event.date,
                    timezone: event.timezone,
                    style: event.style,
                    delayMinutes: event.delayMinutes
                )
            }

            Spacer(minLength: 0)
        }
    }

    private var arrivalTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineHeader(
                icon: "airplane.arrival",
                title: "Arrival",
                iata: flight.destination.iataCode,
                timezone: flight.destination.timezone,
                dayOffsetSuffix: arrivalDayOffsetSuffix
            )

            let events = arrivalTimelineEvents
            if events.isEmpty {
                Text("—")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            } else {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    if index > 0 { timelineConnector() }
                    timelineEvent(
                        icon: event.icon,
                        label: event.label,
                        date: event.date,
                        timezone: event.timezone,
                        style: event.style,
                        delayMinutes: event.delayMinutes
                    )
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func timelineHeader(icon: String, title: String, iata: String, timezone: String?, dayOffsetSuffix: String? = nil) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            Text("\(title) · \(iata)\(dayOffsetSuffix.map { " \($0)" } ?? "")")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let tz = timezone {
                Text(abbreviatedTimezone(identifier: tz))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .padding(.bottom, 6)
    }

    private enum TimelineEventStyle {
        case scheduled, estimated, actual, delayed
    }

    private struct TimelineEventItem: Identifiable {
        let icon: String
        let label: String
        let date: Date
        let timezone: String?
        let style: TimelineEventStyle
        let delayMinutes: Int?
        let precedence: Int
        let dedupGroup: String?

        var id: String {
            "\(label)-\(date.timeIntervalSince1970)-\(icon)"
        }
    }

    private var departureTimelineEvents: [TimelineEventItem] {
        var events: [TimelineEventItem] = [
            TimelineEventItem(
                icon: "calendar.badge.clock",
                label: "Scheduled",
                date: flight.scheduledDeparture,
                timezone: flight.origin.timezone,
                style: .scheduled,
                delayMinutes: nil,
                precedence: 0,
                dedupGroup: nil
            )
        ]

        let confirmedGateOut = flight.actualDeparture ?? flight.revisedDeparture
        let forceGateOutConfirmation = (flight.computedFlightStatus == .enRoute || flight.computedFlightStatus == .arrived) &&
            (confirmedGateOut.map { isSameMinute($0, flight.scheduledDeparture) } ?? false)
        let hasActualDepartureEvent = confirmedGateOut != nil || flight.runwayDeparture != nil

        if !hasActualDepartureEvent,
           let estimated = flight.estimatedDeparture {
            events.append(
                TimelineEventItem(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "Estimated",
                    date: estimated,
                    timezone: flight.origin.timezone,
                    style: .estimated,
                    delayMinutes: minuteDelta(estimated, from: flight.scheduledDeparture),
                    precedence: 1,
                    dedupGroup: nil
                )
            )
        }

        if let gateOut = confirmedGateOut {
            events.append(
                TimelineEventItem(
                    icon: "door.left.hand.open",
                    label: "Gate Out",
                    date: gateOut,
                    timezone: flight.origin.timezone,
                    style: gateOut > flight.scheduledDeparture ? .delayed : .actual,
                    delayMinutes: minuteDelta(gateOut, from: flight.scheduledDeparture),
                    precedence: 2,
                    dedupGroup: forceGateOutConfirmation ? "gateout-confirmed" : nil
                )
            )
        }

        if let takeoff = flight.runwayDeparture {
            events.append(
                TimelineEventItem(
                    icon: "airplane.departure",
                    label: "Takeoff",
                    date: takeoff,
                    timezone: flight.origin.timezone,
                    style: takeoff > flight.scheduledDeparture ? .delayed : .actual,
                    delayMinutes: minuteDelta(takeoff, from: flight.scheduledDeparture),
                    precedence: 3,
                    dedupGroup: nil
                )
            )
        }

        return deduplicatedTimelineEvents(events)
    }

    private var arrivalTimelineEvents: [TimelineEventItem] {
        var events: [TimelineEventItem] = []

        if let scheduled = flight.scheduledArrival {
            events.append(
                TimelineEventItem(
                    icon: "calendar.badge.clock",
                    label: "Scheduled",
                    date: scheduled,
                    timezone: flight.destination.timezone,
                    style: .scheduled,
                    delayMinutes: nil,
                    precedence: 0,
                    dedupGroup: nil
                )
            )
        }

        let arrivedStatus = flight.computedFlightStatus == .arrived
        let fallbackGateIn = arrivedStatus && flight.actualArrival == nil && flight.runwayArrival == nil ? flight.revisedArrival : nil
        let confirmedLanding = flight.runwayArrival
        let confirmedGateIn = flight.actualArrival ?? fallbackGateIn
        let hasConfirmedArrivalEvent = confirmedLanding != nil || confirmedGateIn != nil

        let expectedArrival = (arrivedStatus ? flight.estimatedArrival : (flight.revisedArrival ?? flight.estimatedArrival))

        if !hasConfirmedArrivalEvent,
           let estimated = expectedArrival {
            let style: TimelineEventStyle
            if let scheduled = flight.scheduledArrival {
                style = estimated > scheduled ? .delayed : .estimated
            } else {
                style = .estimated
            }
            events.append(
                TimelineEventItem(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "Estimated",
                    date: estimated,
                    timezone: flight.destination.timezone,
                    style: style,
                    delayMinutes: flight.scheduledArrival.map { minuteDelta(estimated, from: $0) },
                    precedence: 1,
                    dedupGroup: nil
                )
            )
        }

        if !hasConfirmedArrivalEvent,
           let predicted = flight.predictedArrival {
            let style: TimelineEventStyle
            if let scheduled = flight.scheduledArrival {
                style = predicted > scheduled ? .delayed : .actual
            } else {
                style = .estimated
            }
            events.append(
                TimelineEventItem(
                    icon: "location.fill",
                    label: "Predicted",
                    date: predicted,
                    timezone: flight.destination.timezone,
                    style: style,
                    delayMinutes: flight.scheduledArrival.map { minuteDelta(predicted, from: $0) },
                    precedence: 1,
                    dedupGroup: nil
                )
            )
        }

        if let landing = confirmedLanding {
            let style: TimelineEventStyle
            if let scheduled = flight.scheduledArrival {
                style = landing > scheduled ? .delayed : .actual
            } else {
                style = .actual
            }
            events.append(
                TimelineEventItem(
                    icon: "airplane.arrival",
                    label: "Landing",
                    date: landing,
                    timezone: flight.destination.timezone,
                    style: style,
                    delayMinutes: flight.scheduledArrival.map { minuteDelta(landing, from: $0) },
                    precedence: 3,
                    dedupGroup: nil
                )
            )
        }

        if let gateIn = confirmedGateIn {
            let style: TimelineEventStyle
            if let scheduled = flight.scheduledArrival {
                style = gateIn > scheduled ? .delayed : .actual
            } else {
                style = .actual
            }
            events.append(
                TimelineEventItem(
                    icon: "door.right.hand.open",
                    label: "Gate In",
                    date: gateIn,
                    timezone: flight.destination.timezone,
                    style: style,
                    delayMinutes: flight.scheduledArrival.map { minuteDelta(gateIn, from: $0) },
                    precedence: 2,
                    dedupGroup: nil
                )
            )
        }

        return deduplicatedTimelineEvents(events)
    }

    private func deduplicatedTimelineEvents(_ events: [TimelineEventItem]) -> [TimelineEventItem] {
        var winners: [String: TimelineEventItem] = [:]
        var keyOrder: [String] = []

        for event in events {
            let key = dedupKey(for: event)
            if let existing = winners[key] {
                if event.precedence < existing.precedence {
                    winners[key] = event
                }
            } else {
                winners[key] = event
                keyOrder.append(key)
            }
        }

        return keyOrder.compactMap { winners[$0] }
    }

    private func dedupKey(for event: TimelineEventItem) -> String {
        let minuteBucket = Int(minuteFloor(event.date).timeIntervalSince1970)
        return "\(minuteBucket):\(event.dedupGroup ?? "default")"
    }

    private func minuteFloor(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
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

                Text(localTime(date: date, timezone: timezone))
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(eventColor(style))

                Text(deviceLocalTime(date))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .opacity(shouldShowDeviceLocalTime(for: timezone) ? 1 : 0)
            }

            Spacer()

            if let delta = delayMinutes {
                Text(delayLabel(delta))
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(delta > 0 ? .orange : .green)
            }
        }
        .frame(minHeight: 26, alignment: .top)
    }

    private func deviceLocalTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone = TimeZone.current
        return f.string(from: date)
    }

    private func shouldShowDeviceLocalTime(for airportTimezone: String?) -> Bool {
        guard let airportTimezone,
              let airportZone = TimeZone(identifier: airportTimezone) else {
            return true
        }
        return airportZone.identifier != TimeZone.current.identifier
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
        flight.aircraftModel != nil ||
        flight.aircraftImageUrl != nil ||
        flight.tailNumber != nil ||
        flight.callSign != nil ||
        flight.aircraftAge != nil ||
        flight.aircraftTypeName != nil ||
        flight.aircraftModelCode != nil ||
        flight.aircraftSeatCount != nil ||
        flight.aircraftEngineCount != nil ||
        flight.aircraftEngineType != nil ||
        flight.aircraftManufacturedYear != nil ||
        flight.aircraftIsActive != nil ||
        flight.aircraftIsFreighter != nil ||
        flight.aircraftDataVerified != nil
    }

    private var hasTailNumber: Bool {
        guard let tail = flight.tailNumber?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !tail.isEmpty
    }

    private var aircraftSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Aircraft")

            aircraftHeroImage
                .frame(maxWidth: .infinity)
                .frame(height: 190)
                .clipped()  // Ensures image never overflows

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "airplane.circle", label: "Type", value: flight.aircraftModel)
                    infoRow(icon: "tag", label: "Tail", value: flight.tailNumber)
                    infoRow(icon: "airplane", label: "Series", value: flight.aircraftTypeName)
                    infoRow(icon: "number", label: "Model Code", value: flight.aircraftModelCode)
                    infoRow(icon: "calendar", label: "Built", value: flight.aircraftManufacturedYear.map(String.init))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "hourglass", label: "Age", value: flight.aircraftAge)
                    infoRow(icon: "antenna.radiowaves.left.and.right", label: "Call Sign", value: flight.callSign)
                    infoRow(icon: "person.3", label: "Seats", value: flight.aircraftSeatCount.map(String.init))
                    infoRow(icon: "gearshape.2", label: "Engines", value: flight.aircraftEngineCount.map(String.init))
                    infoRow(icon: "fanblades", label: "Engine Type", value: flight.aircraftEngineType)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 8) {
                aircraftStatusBadge
            }
        }
    }

    @ViewBuilder
    private var aircraftStatusBadge: some View {
        if flight.aircraftIsActive != nil || flight.aircraftIsFreighter != nil || flight.aircraftDataVerified != nil {
            // Build status string from all three flags
            let statusParts: [String] = [
                (flight.aircraftIsActive == true) ? "Active" : "Inactive",
                (flight.aircraftIsFreighter == true) ? "Freighter" : "Passenger",
                (flight.aircraftDataVerified == true) ? "Verified" : "Unverified"
            ]
            let statusText = statusParts.joined(separator: " · ")

            Text(statusText)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.12), in: Capsule())
                .foregroundStyle(Color.blue)
        }
    }

    @ViewBuilder
    private func booleanPill(label: String, value: Bool?) -> some View {
        if let value {
            Text("\(label): \(value ? "Yes" : "No")")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background((value ? Color.green : Color.secondary).opacity(0.16), in: Capsule())
                .foregroundStyle(value ? Color.green : Color.secondary)
        }
    }

    private var aircraftHeroImage: some View {
        // Robust fuzzy matching: combine model, type, and code for best match
        let silhouetteName = AircraftImageMapper.getImageName(
            model: flight.aircraftModel,
            typeName: flight.aircraftTypeName,
            modelCode: flight.aircraftModelCode
        )

        return ZStack {
            // Back face: Silhouette (white PNG on card background)
            if isFlipped {
                ZStack {
                    Color.white
                    safeAircraftSilhouette(silhouetteName)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .padding(.vertical, sideViewVerticalPadding)
                        .padding(.horizontal, 8)
                }
            }

            // Front face: Remote photo or fallback silhouette
            if !isFlipped {
                if let imageUrl = flight.aircraftImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            // Loading state: show silhouette
                            ZStack {
                                Color.white
                                safeAircraftSilhouette(silhouetteName)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .padding(.vertical, sideViewVerticalPadding)
                                    .padding(.horizontal, 8)
                            }
                        case .success(let image):
                            // Success: show remote photo - crop to fill with proper constraints
                            GeometryReader { geometry in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geometry.size.width, height: geometry.size.height)
                                    .clipped()
                            }
                        case .failure:
                            // Failed to load: show silhouette fallback
                            ZStack {
                                Color.white
                                safeAircraftSilhouette(silhouetteName)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                    .padding(.vertical, sideViewVerticalPadding)
                                    .padding(.horizontal, 8)
                            }
                        @unknown default:
                            aircraftImagePlaceholder
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    // No URL: show silhouette only
                    ZStack {
                        Color.white
                        safeAircraftSilhouette(silhouetteName)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                            .padding(.vertical, sideViewVerticalPadding)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: aircraftHeroHeight)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .background(Color.black.opacity(0.04))
        .cornerRadius(14)
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
        .frame(maxWidth: .infinity, alignment: .center)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            anchor: .center,
            perspective: 1
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.6)) {
                isFlipped.toggle()
            }
        }
    }

    /// Bulletproof silhouette display: safely loads asset or falls back to SF Symbol
    @ViewBuilder
    private func safeAircraftSilhouette(_ assetName: String) -> some View {
        let _ = print("[safeAircraftSilhouette] Loading: '\(assetName)'")

        if assetName.isEmpty {
            let _ = print("[safeAircraftSilhouette] Empty asset name - using SF Symbol")
            Image(systemName: "airplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100, maxHeight: 100)
                .foregroundStyle(Color.secondary.opacity(0.5))
        } else if let uiImage = AircraftImageMapper.loadAircraftImage(assetName) {
            let _ = print("[safeAircraftSilhouette] ✅ Loaded: '\(assetName)'")
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 180)
        } else {
            let _ = print("[safeAircraftSilhouette] ❌ NOT found: '\(assetName)' - fallback to SF Symbol")
            Image(systemName: "airplane.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100, maxHeight: 100)
                .foregroundStyle(Color.secondary.opacity(0.5))
        }
    }

    private var aircraftImagePlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.secondary.opacity(0.12))
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary)
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

    private func dayOffset(departure: Date, departureTimezone: String?, arrival: Date, arrivalTimezone: String?) -> Int {
        var depCalendar = Calendar.current
        if let departureTimezone, let zone = TimeZone(identifier: departureTimezone) {
            depCalendar.timeZone = zone
        }

        var arrCalendar = Calendar.current
        if let arrivalTimezone, let zone = TimeZone(identifier: arrivalTimezone) {
            arrCalendar.timeZone = zone
        }

        let depStart = depCalendar.startOfDay(for: departure)
        let arrStart = arrCalendar.startOfDay(for: arrival)
        return Calendar.current.dateComponents([.day], from: depStart, to: arrStart).day ?? 0
    }

    private func isSameMinute(_ a: Date, _ b: Date) -> Bool {
        Calendar.current.isDate(a, equalTo: b, toGranularity: .minute)
    }

    // MARK: - Refresh

    @MainActor
    private func refreshFlight() async {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let freshResult = try? await FlightLookupService.lookup(
            flightNumber: flight.flightNumber,
            date: flight.scheduledDeparture
        ) else {
            return
        }

        // Update dynamic flight status
        flight.flightStatus = freshResult.status

        // Departure times
        flight.revisedDeparture = freshResult.revisedDeparture
        flight.estimatedDeparture = freshResult.estimatedDeparture
        flight.actualDeparture = freshResult.actualDeparture
        flight.runwayDeparture = freshResult.runwayDeparture

        // Arrival times
        flight.revisedArrival = freshResult.revisedArrival
        flight.estimatedArrival = freshResult.estimatedArrival
        flight.predictedArrival = freshResult.predictedArrival
        flight.runwayArrival = freshResult.runwayArrival
        flight.actualArrival = freshResult.actualArrival

        // Gates, terminals, runways - preserve existing if API returns nil
        flight.departureGate = freshResult.departureGate ?? flight.departureGate
        flight.departureTerminal = freshResult.departureTerminal ?? flight.departureTerminal
        flight.departureRunway = freshResult.departureRunway ?? flight.departureRunway
        flight.departureCheckInDesk = freshResult.departureCheckInDesk ?? flight.departureCheckInDesk
        flight.arrivalGate = freshResult.arrivalGate ?? flight.arrivalGate
        flight.arrivalTerminal = freshResult.arrivalTerminal ?? flight.arrivalTerminal
        flight.arrivalRunway = freshResult.arrivalRunway ?? flight.arrivalRunway
        flight.baggageClaim = freshResult.baggageClaim ?? flight.baggageClaim

        // Smart merge: Only update aircraft data if we have new data AND cached is nil
        if flight.aircraftAge == nil, let freshAge = freshResult.aircraftAge {
            flight.aircraftAge = freshAge
        }
        if flight.aircraftTypeName == nil, let freshTypeName = freshResult.aircraftTypeName {
            flight.aircraftTypeName = freshTypeName
        }
        if flight.aircraftModelCode == nil, let freshModelCode = freshResult.aircraftModelCode {
            flight.aircraftModelCode = freshModelCode
        }
        if flight.aircraftSeatCount == nil, let freshSeatCount = freshResult.aircraftSeatCount {
            flight.aircraftSeatCount = freshSeatCount
        }
        if flight.aircraftEngineCount == nil, let freshEngineCount = freshResult.aircraftEngineCount {
            flight.aircraftEngineCount = freshEngineCount
        }
        if flight.aircraftEngineType == nil, let freshEngineType = freshResult.aircraftEngineType {
            flight.aircraftEngineType = freshEngineType
        }
        if flight.aircraftIsActive == nil, let freshIsActive = freshResult.aircraftIsActive {
            flight.aircraftIsActive = freshIsActive
        }
        if flight.aircraftIsFreighter == nil, let freshIsFreighter = freshResult.aircraftIsFreighter {
            flight.aircraftIsFreighter = freshIsFreighter
        }
        if flight.aircraftDataVerified == nil, let freshDataVerified = freshResult.aircraftDataVerified {
            flight.aircraftDataVerified = freshDataVerified
        }
        if flight.aircraftManufacturedYear == nil, let freshManufacturedYear = freshResult.aircraftManufacturedYear {
            flight.aircraftManufacturedYear = freshManufacturedYear
        }
        if flight.aircraftRegistrationDate == nil, let freshRegistrationDate = freshResult.aircraftRegistrationDate {
            flight.aircraftRegistrationDate = freshRegistrationDate
        }

        try? modelContext.save()
    }
}

// MARK: - Live Progress Bar

struct LiveProgressBar: View {
    let flight: Flight

    private var arrivalDayOffset: Int {
        guard let scheduledArrival = flight.scheduledArrival else { return 0 }

        var depCalendar = Calendar.current
        if let tz = flight.origin.timezone, let zone = TimeZone(identifier: tz) {
            depCalendar.timeZone = zone
        }

        var arrCalendar = Calendar.current
        if let tz = flight.destination.timezone, let zone = TimeZone(identifier: tz) {
            arrCalendar.timeZone = zone
        }

        let depStart = depCalendar.startOfDay(for: flight.scheduledDeparture)
        let arrStart = arrCalendar.startOfDay(for: scheduledArrival)
        return Calendar.current.dateComponents([.day], from: depStart, to: arrStart).day ?? 0
    }

    private var arrivalDayOffsetSuffix: String {
        guard arrivalDayOffset > 0 else { return "" }
        return " +\(arrivalDayOffset)"
    }

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
                        Text("\(localTime(date: arrTime, timezone: flight.destination.timezone))\(arrivalDayOffsetSuffix)")
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

