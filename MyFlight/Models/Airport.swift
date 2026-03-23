//
//  Airport.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import Foundation
import MapKit
import SwiftData

@Model
final class Airport {
    @Attribute(.unique) var iataCode: String
    var name: String
    var latitude: Double
    var longitude: Double

    init(iataCode: String, name: String, latitude: Double, longitude: Double) {
        self.iataCode = iataCode
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}