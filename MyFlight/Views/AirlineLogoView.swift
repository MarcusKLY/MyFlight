//
//  AirlineLogoView.swift
//  MyFlight
//
//  Created by Kam Long Yin on 2026-03-25.
//

import SwiftUI

/// Displays an airline logo fetched from a public CDN based on the airline's IATA code.
/// Falls back to displaying the airline's IATA code or a placeholder icon if no logo is available.
struct AirlineLogoView: View {
    let airlineIATA: String?
    let airlineName: String
    let size: CGFloat

    init(airlineIATA: String?, airlineName: String, size: CGFloat = 40) {
        self.airlineIATA = airlineIATA
        self.airlineName = airlineName
        self.size = size
    }

    private var logoURL: URL? {
        guard let iata = airlineIATA?.uppercased(), !iata.isEmpty else { return nil }
        // Using Kiwi.com's publicly available airline logo CDN
        return URL(string: "https://images.kiwi.com/airlines/64/\(iata).png")
    }

    var body: some View {
        if let url = logoURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    placeholderView
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size, height: size)
                case .failure:
                    fallbackView
                @unknown default:
                    placeholderView
                }
            }
            .frame(width: size, height: size)
        } else {
            fallbackView
        }
    }

    private var placeholderView: some View {
        ProgressView()
            .frame(width: size, height: size)
    }

    private var fallbackView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
            if let iata = airlineIATA, !iata.isEmpty {
                Text(iata)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: size * 0.6))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 20) {
        AirlineLogoView(airlineIATA: "CX", airlineName: "Cathay Pacific", size: 60)
        AirlineLogoView(airlineIATA: "KL", airlineName: "KLM", size: 60)
        AirlineLogoView(airlineIATA: "AY", airlineName: "Finnair", size: 60)
        AirlineLogoView(airlineIATA: nil, airlineName: "Unknown Airline", size: 60)
    }
    .padding()
}
