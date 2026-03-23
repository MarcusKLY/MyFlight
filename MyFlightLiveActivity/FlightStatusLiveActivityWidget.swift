//
//  FlightStatusLiveActivityWidget.swift
//  MyFlightLiveActivity
//
//  Created by Kam Long Yin on 24/3/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FlightStatusLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FlightStatusAttributes.self) { context in
            LockScreenFlightStatusView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.08))
                .activitySystemActionForegroundColor(.blue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.attributes.flightNumber)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.minutesToArrival)m")
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(context.attributes.originCode) to \(context.attributes.destinationCode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: context.state.progress)
                        Text(context.state.statusText)
                            .font(.caption)
                    }
                }
            } compactLeading: {
                Text(context.attributes.flightNumber)
                    .font(.caption2)
            } compactTrailing: {
                Text("\(context.state.minutesToArrival)m")
                    .font(.caption2)
            } minimal: {
                Image(systemName: "airplane")
            }
            .widgetURL(URL(string: "myflight://activity"))
            .keylineTint(.blue)
        }
    }
}

private struct LockScreenFlightStatusView: View {
    let context: ActivityViewContext<FlightStatusAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.flightNumber)
                        .font(.headline)
                    Text("\(context.attributes.originCode) to \(context.attributes.destinationCode)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(context.state.minutesToArrival)m")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            ProgressView(value: context.state.progress)

            Text(context.state.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
