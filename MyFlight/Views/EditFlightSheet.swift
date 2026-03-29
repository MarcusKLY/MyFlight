//
//  EditFlightSheet.swift
//  MyFlight
//
//  Created by Copilot on 2026-03-28.
//

import SwiftUI
import SwiftData

struct EditFlightSheet: View {
    @Environment(\.dismiss) private var dismiss
    let flight: Flight
    
    // Editable fields
    @State private var seatNumber: String = ""
    @State private var selectedSeatClass: SeatClass?
    @State private var selectedSeatPosition: SeatPosition?
    @State private var departureGate: String = ""
    @State private var departureTerminal: String = ""
    @State private var arrivalGate: String = ""
    @State private var arrivalTerminal: String = ""
    @State private var baggageClaim: String = ""
    
    // Time editing
    @State private var scheduledDeparture: Date = Date()
    @State private var scheduledArrival: Date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                // Schedule Times
                Section {
                    DatePicker("Departure", selection: $scheduledDeparture)
                    DatePicker("Arrival", selection: $scheduledArrival)
                } header: {
                    Label("Schedule", systemImage: "clock")
                }
                
                // Seat Information
                Section {
                    TextField("Seat Number", text: $seatNumber)
                        .textInputAutocapitalization(.characters)
                    
                    Picker("Class", selection: $selectedSeatClass) {
                        Text("Not specified").tag(nil as SeatClass?)
                        ForEach(SeatClass.allCases) { seatClass in
                            HStack {
                                Image(systemName: seatClass.icon)
                                Text(seatClass.rawValue)
                            }
                            .tag(seatClass as SeatClass?)
                        }
                    }
                    
                    Picker("Seat Position", selection: $selectedSeatPosition) {
                        Text("Not specified").tag(nil as SeatPosition?)
                        ForEach(SeatPosition.allCases) { position in
                            HStack {
                                Image(systemName: position.icon)
                                Text(position.rawValue)
                            }
                            .tag(position as SeatPosition?)
                        }
                    }
                } header: {
                    Label("Seat Information", systemImage: "chair")
                }
                
                // Departure Info
                Section {
                    TextField("Gate", text: $departureGate)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Terminal", text: $departureTerminal)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Label("Departure - \(flight.origin.iataCode)", systemImage: "airplane.departure")
                }
                
                // Arrival Info
                Section {
                    TextField("Gate", text: $arrivalGate)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Terminal", text: $arrivalTerminal)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("Baggage Claim", text: $baggageClaim)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Label("Arrival - \(flight.destination.iataCode)", systemImage: "airplane.arrival")
                }
            }
            .navigationTitle("Edit Flight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadCurrentValues()
            }
        }
    }
    
    private func loadCurrentValues() {
        seatNumber = flight.seatNumber ?? ""
        selectedSeatClass = flight.seatClass
        selectedSeatPosition = flight.seatPosition
        departureGate = flight.departureGate ?? ""
        departureTerminal = flight.departureTerminal ?? ""
        arrivalGate = flight.arrivalGate ?? ""
        arrivalTerminal = flight.arrivalTerminal ?? ""
        baggageClaim = flight.baggageClaim ?? ""
        scheduledDeparture = flight.scheduledDeparture
        scheduledArrival = flight.scheduledArrival ?? flight.scheduledDeparture.addingTimeInterval(3600)
    }
    
    private func saveChanges() {
        flight.seatNumber = seatNumber.isEmpty ? nil : seatNumber
        flight.seatClass = selectedSeatClass
        flight.seatPosition = selectedSeatPosition
        flight.departureGate = departureGate.isEmpty ? nil : departureGate
        flight.departureTerminal = departureTerminal.isEmpty ? nil : departureTerminal
        flight.arrivalGate = arrivalGate.isEmpty ? nil : arrivalGate
        flight.arrivalTerminal = arrivalTerminal.isEmpty ? nil : arrivalTerminal
        flight.baggageClaim = baggageClaim.isEmpty ? nil : baggageClaim
        flight.scheduledDeparture = scheduledDeparture
        flight.scheduledArrival = scheduledArrival
    }
}
