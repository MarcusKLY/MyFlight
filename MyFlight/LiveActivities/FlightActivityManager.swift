//
//  FlightActivityManager.swift
//  MyFlight
//
//  Created by Kam Long Yin on 24/3/2026.
//

import Foundation
import ActivityKit

enum FlightActivityManager {
    @discardableResult
    static func startActivity(for flight: Flight) -> Activity<FlightStatusAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return nil
        }

        let attributes = FlightStatusAttributes(
            flightNumber: flight.flightNumber,
            originCode: flight.origin.iataCode,
            destinationCode: flight.destination.iataCode,
            scheduledArrival: flight.scheduledDeparture.addingTimeInterval(2.5 * 60 * 60)
        )

        let initialState = FlightStatusAttributes.ContentState(
            progress: 0,
            statusText: flight.flightStatus.rawValue,
            minutesToArrival: 150
        )

        do {
            return try Activity.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
        } catch {
            return nil
        }
    }

    static func update(_ activity: Activity<FlightStatusAttributes>, progress: Double, minutesToArrival: Int, status: FlightStatus) {
        let updatedState = FlightStatusAttributes.ContentState(
            progress: min(max(progress, 0), 1),
            statusText: status.rawValue,
            minutesToArrival: max(0, minutesToArrival)
        )

        Task {
            await activity.update(.init(state: updatedState, staleDate: nil))
        }
    }
}
