//
//  EditTransitSheet.swift
//  MyFlight
//
//  Created by Copilot on 2026-03-28.
//

import SwiftUI
import SwiftData

struct EditTransitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transit: TransitSegment

    // Editable fields
    @State private var operatorName: String = ""
    @State private var routeNumber: String = ""
    @State private var originName: String = ""
    @State private var destinationName: String = ""
    @State private var scheduledDeparture: Date = Date()
    @State private var scheduledArrival: Date = Date()
    @State private var notes: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // Transit Info
                Section {
                    TextField("Operator", text: $operatorName)
                    TextField("Route Number", text: $routeNumber)
                } header: {
                    Label("Transit Details", systemImage: transit.transitType.icon)
                }

                // Route Info
                Section {
                    TextField("Origin", text: $originName)
                    TextField("Destination", text: $destinationName)
                } header: {
                    Label("Route", systemImage: "arrow.right")
                }

                // Schedule
                Section {
                    DatePicker("Departure", selection: $scheduledDeparture, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Arrival", selection: $scheduledArrival, displayedComponents: [.date, .hourAndMinute])
                } header: {
                    Label("Schedule", systemImage: "clock")
                }

                // Notes
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Label("Notes", systemImage: "note.text")
                }
            }
            .navigationTitle("Edit Transit")
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
        operatorName = transit.operatorName
        routeNumber = transit.routeNumber
        originName = transit.originName
        destinationName = transit.destinationName
        scheduledDeparture = transit.scheduledDeparture
        scheduledArrival = transit.scheduledArrival
        notes = transit.notes ?? ""
    }

    private func saveChanges() {
        transit.operatorName = operatorName
        transit.routeNumber = routeNumber
        transit.originName = originName
        transit.destinationName = destinationName
        transit.scheduledDeparture = scheduledDeparture
        transit.scheduledArrival = scheduledArrival
        transit.notes = notes.isEmpty ? nil : notes
    }
}
