//
//  GeodesicPath.swift
//  MyFlight
//
//  Created by Kam Long Yin on 23/3/2026.
//

import MapKit

/// Generates an array of coordinates representing a geodesic (great circle) path between two points
func generateGeodesicPath(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D,
    steps: Int = 100
) -> [CLLocationCoordinate2D] {
    let points = [origin, destination]
    let polyline = MKGeodesicPolyline(coordinates: points, count: points.count)

    var coordinates = Array(repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
    polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))

    if coordinates.isEmpty {
        return points
    }

    if coordinates.count <= steps {
        return coordinates
    }

    // Downsample while always keeping the final destination point.
    let strideSize = max(1, coordinates.count / steps)
    var sampled: [CLLocationCoordinate2D] = []
    var index = 0

    while index < coordinates.count {
        sampled.append(coordinates[index])
        index += strideSize
    }

    if let last = sampled.last,
       (last.latitude != destination.latitude || last.longitude != destination.longitude) {
        sampled.append(destination)
    }

    return sampled
}
