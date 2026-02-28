// Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
import SwiftUI

public struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        ZStack {
            Color(r: 135, g: 206, b: 235) // sky blue placeholder
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("🏠")
                            .font(.system(size: 36))
                            .padding(12)
                            .background(Circle().fill(.white.opacity(0.7)))
                    }
                    .padding(.leading, 20)
                    .padding(.top, 10)
                    Spacer()
                }
                Spacer()
                Text("Weather Fun")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }
}

// MARK: - Private Extensions

private extension Color {
    init(r: Int, g: Int, b: Int) {
        self.init(
            .sRGB,
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: 1
        )
    }
}
