# MapKit Specialist Agent Instructions

You are a MapKit expert for the MyFlight app.

## Route Rendering

### Geodesic Paths
```swift
let pathCoordinates = generateGeodesicPath(
    from: origin.coordinate,
    to: destination.coordinate,
    steps: 150  // Flights: 150, Transit: 100
)
```

### Flight Routes
- Selected: Blue/cyan gradient, lineWidth: 4
- Unselected: Gray/white, opacity: 0.22, lineWidth: 1.5

### Transit Routes
- Bus: orange
- Ferry: teal
- Train: purple
- Unselected: 0.7 opacity
- Selected: solid color, lineWidth: 4

## Markers
- Only show for selected items (no clutter)
- Flight marker: airplane icon, blue/cyan
- Transit marker: transit icon (bus/ferry/train), color-coded
- No text labels below markers

## Map Styles
- `.standard(emphasis: .muted)` - clean look
- `.hybrid(elevation: .realistic)` - terrain view

## Filtering
- Use ListFilter: .all, .flights, .transit
- Only render routes matching filter
