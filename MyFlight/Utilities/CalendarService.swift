import Foundation
import EventKit

enum CalendarService {
    static let eventStore = EKEventStore()
    
    /// Request calendar access permission
    static func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestFullAccessToEvents()
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }
    
    /// Add flight to calendar
    static func addFlightToCalendar(_ flight: Flight) async -> Result<Void, CalendarError> {
        let hasAccess = await requestAccess()
        guard hasAccess else {
            return .failure(.accessDenied)
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(flight.airline) \(flight.flightNumber)"
        event.startDate = flight.effectiveDeparture
        event.endDate = flight.effectiveArrival
        event.location = "\(flight.origin.name) → \(flight.destination.name)"
        
        var notes = "Flight: \(flight.flightNumber)\n"
        notes += "Route: \(flight.origin.iataCode) → \(flight.destination.iataCode)\n"
        
        if let aircraft = flight.aircraftModel {
            notes += "Aircraft: \(aircraft)\n"
        }
        if let tailNumber = flight.tailNumber {
            notes += "Registration: \(tailNumber)\n"
        }
        if let gate = flight.departureGate {
            notes += "Departure Gate: \(gate)\n"
        }
        if let terminal = flight.departureTerminal {
            notes += "Terminal: \(terminal)\n"
        }
        if let seatNumber = flight.seatNumber {
            notes += "Seat: \(seatNumber)"
            if let seatClass = flight.seatClass {
                notes += " (\(seatClass.rawValue))"
            }
            notes += "\n"
        }
        
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add travel time alerts
        event.addAlarm(EKAlarm(relativeOffset: -3600)) // 1 hour before
        event.addAlarm(EKAlarm(relativeOffset: -7200)) // 2 hours before
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return .success(())
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    /// Add transit to calendar
    static func addTransitToCalendar(_ transit: TransitSegment) async -> Result<Void, CalendarError> {
        let hasAccess = await requestAccess()
        guard hasAccess else {
            return .failure(.accessDenied)
        }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(transit.transitType.icon) \(transit.operatorName) \(transit.routeNumber)"
        event.startDate = transit.effectiveDeparture
        event.endDate = transit.effectiveArrival
        event.location = "\(transit.originName) → \(transit.destinationName)"
        
        var notes = "\(transit.transitType.rawValue): \(transit.routeNumber)\n"
        notes += "Operator: \(transit.operatorName)\n"
        notes += "Route: \(transit.originName) → \(transit.destinationName)\n"
        
        if let transitNotes = transit.notes, !transitNotes.isEmpty {
            notes += "\nNotes: \(transitNotes)\n"
        }
        
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alert 30 minutes before
        event.addAlarm(EKAlarm(relativeOffset: -1800))
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return .success(())
        } catch {
            return .failure(.saveFailed(error.localizedDescription))
        }
    }
    
    enum CalendarError: LocalizedError {
        case accessDenied
        case saveFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return "Calendar access denied. Please enable in Settings > MyFlight > Calendars"
            case .saveFailed(let message):
                return "Failed to save event: \(message)"
            }
        }
    }
}
