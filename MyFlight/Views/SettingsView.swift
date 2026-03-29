//
//  SettingsView.swift
//  MyFlight
//
//  Created by Copilot on 28/3/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("transitColorBus") private var busColor: String = "orange"
    @AppStorage("transitColorFerry") private var ferryColor: String = "teal"
    @AppStorage("transitColorTrain") private var trainColor: String = "purple"
    @AppStorage("flightColorSelected") private var flightColorSelected: String = "blue"
    @AppStorage("flightColorUnselected") private var flightColorUnselected: String = "gray"
    @AppStorage("routeLineThickness") private var lineThickness: Double = 4.0
    @AppStorage("routeLineStyle") private var lineStyle: String = "dashed"
    
    private let availableColors = [
        ("orange", Color.orange),
        ("teal", Color.teal),
        ("purple", Color.purple),
        ("blue", Color.blue),
        ("cyan", Color.cyan),
        ("green", Color.green),
        ("yellow", Color.yellow),
        ("pink", Color.pink),
        ("red", Color.red),
        ("indigo", Color.indigo)
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Customize route line appearance on the map.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("Line Style") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Thickness: \(String(format: "%.1f", lineThickness)) pt")
                            .font(.subheadline)
                        Slider(value: $lineThickness, in: 1.0...6.0, step: 0.5)
                    }
                    
                    Picker("Line Style", selection: $lineStyle) {
                        Text("Solid").tag("solid")
                        Text("Dashed").tag("dashed")
                        Text("Dotted").tag("dotted")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Flight Route Colors") {
                    ColorPickerRow(label: "Selected Flight", icon: "airplane", selectedColor: $flightColorSelected, colors: availableColors)
                    ColorPickerRow(label: "Unselected Flight", icon: "airplane", selectedColor: $flightColorUnselected, colors: availableColors)
                }
                
                Section("Transit Line Colors") {
                    ColorPickerRow(label: "Bus", icon: "bus.fill", selectedColor: $busColor, colors: availableColors)
                    ColorPickerRow(label: "Ferry", icon: "ferry.fill", selectedColor: $ferryColor, colors: availableColors)
                    ColorPickerRow(label: "Train", icon: "tram.fill", selectedColor: $trainColor, colors: availableColors)
                }
                
                Section {
                    Button("Reset to Defaults") {
                        busColor = "orange"
                        ferryColor = "teal"
                        trainColor = "purple"
                        flightColorSelected = "blue"
                        flightColorUnselected = "gray"
                        lineThickness = 4.0
                        lineStyle = "dashed"
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct ColorPickerRow: View {
    let label: String
    let icon: String
    @Binding var selectedColor: String
    let colors: [(String, Color)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(colorFromString(selectedColor))
                Text(label)
                    .fontWeight(.medium)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.0) { colorName, color in
                        Button {
                            selectedColor = colorName
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(color.gradient)
                                    .frame(width: 44, height: 44)
                                
                                if selectedColor == colorName {
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                        .frame(width: 44, height: 44)
                                    Circle()
                                        .strokeBorder(color, lineWidth: 2)
                                        .frame(width: 52, height: 52)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func colorFromString(_ name: String) -> Color {
        switch name {
        case "orange": return .orange
        case "teal": return .teal
        case "purple": return .purple
        case "blue": return .blue
        case "cyan": return .cyan
        case "green": return .green
        case "yellow": return .yellow
        case "pink": return .pink
        case "red": return .red
        case "indigo": return .indigo
        default: return .gray
        }
    }
}

#Preview {
    SettingsView()
}
