//
//  FlightStatusAttributes.swift
//  MyFlightLiveActivity
//
//  Created by Kam Long Yin on 24/3/2026.
//

import Foundation
import ActivityKit

struct FlightStatusAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var progress: Double
        var statusText: String
        var minutesToArrival: Int
    }

    var flightNumber: String
    var originCode: String
    var destinationCode: String
    var scheduledArrival: Date
}
