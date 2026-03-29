//
//  TransitDetailView.swift
//  MyFlight
//
//  Created by Copilot on 27/3/2026.
//

import SwiftUI
import SwiftData

struct TransitDetailView: View {
    let transit: TransitSegment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showCalendarAlert = false
    @State private var calendarMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header with back button and title
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)

                    Text(transit.displayName)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)

                    // 3-dot menu
                    Menu {
                        Button {
                            showEditSheet = true
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button {
                            addToCalendar()
                        } label: {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 36, height: 36)
                    }
                    .foregroundStyle(.blue)
                    .accessibilityLabel("More options")
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

                        if let notes = transit.notes, !notes.isEmpty {
                            Divider()
                            notesSection(notes)
                                .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showEditSheet) {
            EditTransitSheet(transit: transit)
        }
        .alert("Delete Transit", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTransit()
            }
        } message: {
            Text("Are you sure you want to delete this \(transit.transitType.rawValue.lowercased()) trip? This action cannot be undone.")
        }
        .alert("Calendar", isPresented: $showCalendarAlert) {
            Button("OK") { }
        } message: {
            Text(calendarMessage)
        }
    }
    
    private func deleteTransit() {
        modelContext.delete(transit)
        dismiss()
    }
    
    private func addToCalendar() {
        Task {
            let result = await CalendarService.addTransitToCalendar(transit)
            await MainActor.run {
                switch result {
                case .success:
                    calendarMessage = "Transit added to calendar successfully"
                case .failure(let error):
                    calendarMessage = error.localizedDescription ?? "Failed to add to calendar"
                }
                showCalendarAlert = true
            }
        }
    }

    // MARK: - Route Header

    private var routeHeader: some View {
        VStack(spacing: 12) {
            // Date row
            Text(transit.departureDateFormatted)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            // Operator row with transit icon
            HStack(spacing: 8) {
                TransitTypeIcon(type: transit.transitType, size: 28)
                Text(transit.operatorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Route visualization
            HStack(alignment: .center, spacing: 0) {
                VStack(spacing: 4) {
                    Text(originDisplayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                    Text(transit.originName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 6) {
                    Image(systemName: transit.transitType.icon)
                        .font(.title2)
                        .foregroundStyle(transitTypeColor)
                    Text(transit.durationFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Text(destinationDisplayName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                    Text(transit.destinationName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
            }

            statusBadge

            if let depDelay = transit.departureDelayMinutes, let arrDelay = transit.arrivalDelayMinutes {
                HStack(spacing: 10) {
                    delayPill(text: "Dep \(depDelay >= 0 ? "+\(depDelay)m" : "\(depDelay)m")", isDelayed: depDelay > 0)
                    delayPill(text: "Arr \(arrDelay >= 0 ? "+\(arrDelay)m" : "\(arrDelay)m")", isDelayed: arrDelay > 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            } else if let depDelay = transit.departureDelayMinutes {
                delayPill(text: "Dep \(depDelay >= 0 ? "+\(depDelay)m" : "\(depDelay)m")", isDelayed: depDelay > 0)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            } else if let arrDelay = transit.arrivalDelayMinutes {
                delayPill(text: "Arr \(arrDelay >= 0 ? "+\(arrDelay)m" : "\(arrDelay)m")", isDelayed: arrDelay > 0)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
            }
        }
        .padding(.top, 20)
    }

    private var originDisplayName: String {
        extractCityName(from: transit.originName)
    }

    private var destinationDisplayName: String {
        extractCityName(from: transit.destinationName)
    }

    private func extractCityName(from fullName: String) -> String {
        // Extract city from "City Bus Station" or "City, Country"
        let parts = fullName.components(separatedBy: ",")
        if let first = parts.first?.trimmingCharacters(in: .whitespaces) {
            // Remove common suffixes
            let suffixes = ["Bus Station", "Train Station", "Ferry Terminal", "Terminal", "Station", "Port"]
            var name = first
            for suffix in suffixes {
                if name.hasSuffix(suffix) {
                    name = String(name.dropLast(suffix.count)).trimmingCharacters(in: .whitespaces)
                }
            }
            return name.isEmpty ? first : name
        }
        return fullName
    }

    private var transitTypeColor: Color {
        switch transit.transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }

    private var statusBadge: some View {
        Text(transit.transitStatus.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch transit.transitStatus {
        case .scheduled: return .gray
        case .departed, .enRoute: return .blue
        case .arrived: return .green
        case .delayed: return .orange
        case .cancelled: return .red
        }
    }

    private func delayPill(text: String, isDelayed: Bool) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isDelayed ? Color.orange.opacity(0.15) : Color.green.opacity(0.15))
            .foregroundStyle(isDelayed ? .orange : .green)
            .clipShape(Capsule())
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Progress")
            TransitLiveProgressBar(transit: transit)
        }
    }

    // MARK: - Timeline Section

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
                icon: transit.transitType.icon,
                title: "Departure",
                location: originDisplayName
            )

            timelineEvent(
                icon: "calendar.badge.clock",
                label: "Scheduled",
                time: transit.formattedDeparture(),
                style: .scheduled
            )

            if let estimated = transit.estimatedDeparture,
               !Calendar.current.isDate(estimated, equalTo: transit.scheduledDeparture, toGranularity: .minute) {
                timelineConnector()
                timelineEvent(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "Estimated",
                    time: formatTime(estimated),
                    style: estimated > transit.scheduledDeparture ? .delayed : .onTime
                )
            }

            if let actual = transit.actualDeparture {
                timelineConnector()
                timelineEvent(
                    icon: "checkmark.circle.fill",
                    label: "Departed",
                    time: formatTime(actual),
                    style: actual > transit.scheduledDeparture ? .delayed : .actual
                )
            }

            Spacer(minLength: 0)
        }
    }

    private var arrivalTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            timelineHeader(
                icon: "mappin.circle.fill",
                title: "Arrival",
                location: destinationDisplayName
            )

            timelineEvent(
                icon: "calendar.badge.clock",
                label: "Scheduled",
                time: transit.formattedArrival(),
                style: .scheduled
            )

            if let estimated = transit.estimatedArrival,
               !Calendar.current.isDate(estimated, equalTo: transit.scheduledArrival, toGranularity: .minute) {
                timelineConnector()
                timelineEvent(
                    icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                    label: "Estimated",
                    time: formatTime(estimated),
                    style: estimated > transit.scheduledArrival ? .delayed : .onTime
                )
            }

            if let actual = transit.actualArrival {
                timelineConnector()
                timelineEvent(
                    icon: "checkmark.circle.fill",
                    label: "Arrived",
                    time: formatTime(actual),
                    style: actual > transit.scheduledArrival ? .delayed : .actual
                )
            }

            Spacer(minLength: 0)
        }
    }

    private func timelineHeader(icon: String, title: String, location: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(transitTypeColor)
            Text("\(title) · \(location)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.bottom, 6)
    }

    private enum TimelineStyle {
        case scheduled, onTime, delayed, actual
    }

    private func timelineEvent(icon: String, label: String, time: String, style: TimelineStyle) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(timelineIconColor(for: style))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(time)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(timelineTextColor(for: style))
            }
        }
        .padding(.vertical, 4)
    }

    private func timelineConnector() -> some View {
        Rectangle()
            .fill(Color.gray.opacity(0.3))
            .frame(width: 2, height: 12)
            .padding(.leading, 7)
    }

    private func timelineIconColor(for style: TimelineStyle) -> Color {
        switch style {
        case .scheduled: return .gray
        case .onTime: return .blue
        case .delayed: return .orange
        case .actual: return .green
        }
    }

    private func timelineTextColor(for style: TimelineStyle) -> Color {
        switch style {
        case .scheduled: return .primary
        case .onTime: return .blue
        case .delayed: return .orange
        case .actual: return .green
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Notes")
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
    }
}

// MARK: - Transit Live Progress Bar

struct TransitLiveProgressBar: View {
    let transit: TransitSegment

    private var progress: Double {
        transit.progress ?? 0
    }

    private var isInTransit: Bool {
        guard let p = transit.progress else { return false }
        return p > 0 && p < 1
    }

    private var transitTypeColor: Color {
        switch transit.transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    // Progress fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [transitTypeColor, transitTypeColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 6)

                    // Transit icon indicator
                    if isInTransit {
                        Image(systemName: transit.transitType.icon)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(transitTypeColor)
                            .offset(x: max(0, min(geo.size.width - 14, geo.size.width * progress - 7)))
                    }
                }
            }
            .frame(height: 20)

            // Time labels
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Departure")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(transit.formattedDeparture())
                        .font(.caption)
                        .fontWeight(.medium)
                }

                Spacer()

                if isInTransit {
                    VStack(spacing: 2) {
                        Text(progressPercentageText)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(transitTypeColor)
                        Text(remainingTimeText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Arrival")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(transit.formattedArrival())
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }

    private var progressPercentageText: String {
        "\(Int(progress * 100))%"
    }

    private var remainingTimeText: String {
        let remaining = transit.effectiveArrival.timeIntervalSinceNow
        guard remaining > 0 else { return "Arriving" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }
}
