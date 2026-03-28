//
//  TransitListItemView.swift
//  MyFlight
//
//  Created by Copilot on 27/3/2026.
//

import SwiftUI

// MARK: - Transit List Item View

struct TransitListItemView: View {
    let transit: TransitSegment
    let isSelected: Bool
    let isUpcoming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: Transit icon, operator, and date
            HStack {
                HStack(spacing: 8) {
                    TransitTypeIcon(type: transit.transitType, size: 28)
                        .frame(height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(transit.operatorName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        if !transit.routeNumber.isEmpty {
                            Text(transit.routeNumber)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 32, alignment: .center)

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

            // Route row with visual progress line
            HStack(spacing: 0) {
                // Origin
                VStack(alignment: .leading, spacing: 2) {
                    Text(originShortName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Dep: \(transit.formattedDeparture())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        if let actual = transit.actualDeparture,
                           !Calendar.current.isDate(actual, equalTo: transit.scheduledDeparture, toGranularity: .minute) {
                            Text("Act: \(transit.formattedDeparture(actual: true))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 80, alignment: .leading)

                // Progress line
                TransitProgressLine(
                    progress: currentProgress,
                    isInTransit: isInTransit,
                    duration: transit.durationFormatted,
                    transitType: transit.transitType,
                    status: transit.transitStatus,
                    isDelayed: (transit.arrivalDelayMinutes ?? 0) > 0
                )

                // Destination
                VStack(alignment: .trailing, spacing: 2) {
                    Text(destinationShortName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Arr: \(transit.formattedArrival())")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)

                        if let actual = transit.actualArrival,
                           !Calendar.current.isDate(actual, equalTo: transit.scheduledArrival, toGranularity: .minute) {
                            Text("Act: \(transit.formattedArrival(actual: true))")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }
                .frame(width: 80, alignment: .trailing)
            }

            // Status badges row
            HStack(spacing: 8) {
                TransitStatusBadge(status: transit.transitStatus)

                if let delay = transit.departureDelayMinutes, delay > 0 {
                    DelayBadge(minutes: delay)
                }

                if let arrivalDelay = transit.arrivalDelayMinutes, arrivalDelay > 0 {
                    DelayBadge(minutes: arrivalDelay)
                }

                Spacer()

                Text(transit.durationFormatted)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.orange.opacity(0.08) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
    }

    // MARK: - Computed Properties

    private var currentProgress: Double {
        if isInTransit {
            return transit.progress ?? 0
        } else if !isUpcoming {
            return 1.0
        } else {
            return 0.0
        }
    }

    private var isInTransit: Bool {
        guard let progress = transit.progress else { return false }
        return progress > 0 && progress < 1
    }

    private var originShortName: String {
        shortenLocationName(transit.originName)
    }

    private var destinationShortName: String {
        shortenLocationName(transit.destinationName)
    }

    private func shortenLocationName(_ name: String) -> String {
        // Extract city name or first meaningful part
        let parts = name.components(separatedBy: ",")
        if let first = parts.first?.trimmingCharacters(in: .whitespaces) {
            // Limit to reasonable length
            if first.count > 12 {
                return String(first.prefix(10)) + "…"
            }
            return first
        }
        return name
    }

    private var smartDateFormat: String {
        let calendar = Calendar.current
        let now = Date()
        let transitDate = transit.scheduledDeparture

        if calendar.isDateInToday(transitDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(transitDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(transitDate) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: now, to: transitDate).day ?? 0
            if days > 0 && days <= 7 {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                return formatter.string(from: transitDate)
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: transitDate)
            }
        }
    }

    private var countdownText: String? {
        let interval = transit.scheduledDeparture.timeIntervalSinceNow
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
        let hours = transit.scheduledDeparture.timeIntervalSinceNow / 3600

        if hours < 2 {
            return LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
        } else if hours < 12 {
            return LinearGradient(colors: [.orange, .yellow], startPoint: .leading, endPoint: .trailing)
        } else {
            return LinearGradient(colors: [.orange, .teal], startPoint: .leading, endPoint: .trailing)
        }
    }
}

// MARK: - Transit Type Icon

struct TransitTypeIcon: View {
    let type: TransitType
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: size, height: size)

            Image(systemName: type.icon)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(iconColor)
        }
    }

    private var iconColor: Color {
        switch type {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }
}

// MARK: - Transit Progress Line

struct TransitProgressLine: View {
    let progress: Double
    let isInTransit: Bool
    let duration: String?
    let transitType: TransitType
    let status: TransitStatus
    let isDelayed: Bool

    private var lineGradient: LinearGradient {
        if isInTransit {
            return transitTypeGradient
        }
        if status == .arrived {
            return LinearGradient(
                colors: isDelayed ? [.orange, .red] : [.green, .green.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        if status == .departed || status == .enRoute {
            return transitTypeGradient
        }
        if status == .delayed {
            return LinearGradient(colors: [.orange, .red], startPoint: .leading, endPoint: .trailing)
        }
        return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
    }

    private var transitTypeGradient: LinearGradient {
        switch transitType {
        case .bus:
            return LinearGradient(colors: [.orange, .orange.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        case .ferry:
            return LinearGradient(colors: [.teal, .cyan], startPoint: .leading, endPoint: .trailing)
        case .train:
            return LinearGradient(colors: [.purple, .purple.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
        }
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

                // Transit indicator (only when in transit)
                if isInTransit {
                    GeometryReader { geo in
                        Image(systemName: transitType.icon)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(transitIconColor)
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

    private var transitIconColor: Color {
        switch transitType {
        case .bus: return .orange
        case .ferry: return .teal
        case .train: return .purple
        }
    }
}

// MARK: - Transit Status Badge

struct TransitStatusBadge: View {
    let status: TransitStatus

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
        case .scheduled:
            return LinearGradient(
                colors: [Color.gray, Color.gray.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .departed, .enRoute:
            return LinearGradient(
                colors: [Color.blue, Color.cyan],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .arrived:
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
        case .cancelled:
            return LinearGradient(
                colors: [Color.red, Color.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}
