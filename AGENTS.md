# MyFlight Custom Agents Configuration

This file defines custom agents for the MyFlight project.

## Available Agents

### SwiftUI Polish Agent
**Description**: Expert in SwiftUI animations, transitions, and UI polish
**Focus**: Make the app feel like Flighty - smooth, fast, minimal
**Use for**:
- Polishing animations and transitions
- Adding haptic feedback
- Sheet presentation timing
- Gesture handling

**Key patterns**:
- Spring animations: `.spring(response: 0.3, dampingFraction: 0.7)`
- Transitions: `.scale.combined(with: .opacity)`
- Haptic: `UIImpactFeedbackGenerator(style: .medium)`

---

### SwiftData Expert Agent  
**Description**: Specialist in SwiftData models, queries, and data management
**Focus**: Build robust data layer with computed properties and smart queries
**Use for**:
- Creating or modifying data models
- Writing efficient queries
- Data migrations
- Relationship management

**Key patterns**:
- Enum storage with computed properties
- Primary keys: `@Attribute(.unique) var id: UUID`
- Computed properties for derived state
- Models own business logic

---

### MapKit Specialist Agent
**Description**: Expert in MapKit features, geodesic paths, and custom annotations
**Focus**: Advanced map visualizations and route rendering
**Use for**:
- Custom map annotations and markers
- Geodesic path calculations
- Camera positioning and animation
- Route overlays and filtering

**Key patterns**:
- Geodesic paths: `generateGeodesicPath(from:to:steps:)`
- Flight routes: blue/cyan, 150 steps
- Transit routes: orange/teal/purple, 100 steps, 0.7 opacity
- Markers only show for selected items
- Filter-aware rendering

---

### Flight API Integration Agent
**Description**: Expert in API integration with offline-first design
**Focus**: Integrate flight tracking APIs without breaking offline experience
**Use for**:
- Adding live flight status
- Real-time position tracking
- Delay predictions
- Push notifications for status changes

**Key patterns**:
- Silent failures - no error alerts
- Use SwiftData as cache layer
- APIs enhance, don't require
- Graceful offline fallback

---

### iOS Testing Agent
**Description**: Specialist in XCTest, SwiftUI previews, and UI testing
**Focus**: Write comprehensive tests for models, UI, and edge cases
**Use for**:
- Unit tests for computed properties
- SwiftUI preview tests
- Navigation and interaction tests
- Performance testing

**Key patterns**:
- In-memory SwiftData for tests
- Model logic testing
- Navigation flow testing
- Edge case coverage
