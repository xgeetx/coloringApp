// Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
import SwiftUI
import SpriteKit

public struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WeatherViewModel()
    @State private var showSettings = false
    @State private var scene: WeatherScene?

    public init() {}

    public var body: some View {
        ZStack {
            // SpriteKit scene — created once
            if let scene = scene {
                SpriteView(scene: scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
            }

            // Invisible touch overlay — captures scribbling
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            viewModel.isTouching = true
                        }
                        .onEnded { _ in
                            viewModel.isTouching = false
                        }
                )

            // HUD overlay
            VStack {
                HStack(alignment: .top) {
                    // Home button — big and clear
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Text("🏠")
                                .font(.system(size: 32))
                            Text("Home")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color(r: 60, g: 60, b: 80))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(.white.opacity(0.85))
                        )
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    }
                    .padding(.leading, 16)
                    .padding(.top, 12)

                    Spacer()

                    // Weather badge — shows current weather type
                    weatherBadge
                        .padding(.top, 12)

                    Spacer()

                    // Settings — invisible triple-tap zone (parent only)
                    Color.clear
                        .frame(width: 60, height: 60)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 3) {
                            showSettings = true
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 12)
                }
                Spacer()
            }
        }
        .onAppear {
            if scene == nil {
                let s = WeatherScene()
                s.viewModel = viewModel
                s.audioManager = WeatherAudioManager()
                s.size = UIScreen.main.bounds.size
                s.scaleMode = .resizeFill
                scene = s
            }
            viewModel.onAppear()
        }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewModel: viewModel)
                .weatherSheetDetents()
                .weatherDragIndicator()
        }
    }

    private var weatherBadge: some View {
        let emoji: String
        let label: String
        switch viewModel.weatherType {
        case .sunny:  emoji = "☀️"; label = "Sunny"
        case .cloudy: emoji = "☁️"; label = "Cloudy"
        case .rainy:  emoji = "🌧️"; label = "Rainy"
        case .snowy:  emoji = "❄️"; label = "Snowy"
        }
        return HStack(spacing: 4) {
            Text(emoji).font(.system(size: 28))
            Text(label)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(Color(r: 60, g: 60, b: 80))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.white.opacity(0.85)))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

// MARK: - Settings Sheet

private struct SettingsSheet: View {
    @ObservedObject var viewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingZip: String = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Weather Settings")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

                // Zip code
                VStack(alignment: .leading, spacing: 8) {
                    Text("Zip Code")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                    TextField("Enter zip code", text: $editingZip)
                        .keyboardType(.numberPad)
                        .font(.system(size: 22, design: .rounded))
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray6)))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4)))

                    if let error = viewModel.zipError {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal, 32)

                Button {
                    viewModel.zipCode = editingZip
                    viewModel.fetchWeather()
                    if viewModel.zipError == nil {
                        dismiss()
                    }
                } label: {
                    Text("Save Location")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color(r: 80, g: 160, b: 255)))
                }

                // Weather override for testing
                VStack(spacing: 8) {
                    Text("Test Weather")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 12) {
                        weatherButton("☀️", type: .sunny)
                        weatherButton("☁️", type: .cloudy)
                        weatherButton("🌧️", type: .rainy)
                        weatherButton("❄️", type: .snowy)
                    }

                    if viewModel.weatherOverride != nil {
                        Button {
                            viewModel.weatherOverride = nil
                            viewModel.fetchWeather()
                        } label: {
                            Text("Use Real Weather")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { editingZip = viewModel.zipCode }
    }

    private func weatherButton(_ emoji: String, type: WeatherType) -> some View {
        let isActive = viewModel.weatherType == type
        return Button {
            viewModel.weatherOverride = type
            viewModel.weatherType = type
        } label: {
            Text(emoji)
                .font(.system(size: 36))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isActive ? Color.blue.opacity(0.2) : Color(.systemGray6))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - iOS 15/16 Sheet Helpers

private extension View {
    @ViewBuilder
    func weatherSheetDetents() -> some View {
        if #available(iOS 16, *) {
            self.presentationDetents([.medium])
        } else {
            self
        }
    }

    @ViewBuilder
    func weatherDragIndicator() -> some View {
        if #available(iOS 16, *) {
            self.presentationDragIndicator(.visible)
        } else {
            self
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
