// Packages/WeatherFun/Sources/WeatherFun/WeatherView.swift
import SwiftUI
import SpriteKit

public struct WeatherView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = WeatherViewModel()
    @State private var showSettings = false

    public init() {}

    public var body: some View {
        ZStack {
            // SpriteKit scene
            SpriteView(scene: makeScene(), options: [.allowsTransparency])
                .ignoresSafeArea()

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
                HStack {
                    // Home button
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

                    // Settings gear — triple tap
                    Text("⚙️")
                        .font(.system(size: 24))
                        .padding(10)
                        .background(Circle().fill(.white.opacity(0.3)))
                        .onTapGesture(count: 3) {
                            showSettings = true
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 10)
                }
                Spacer()
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(viewModel: viewModel)
                .weatherSheetDetents()
                .weatherDragIndicator()
        }
    }

    private func makeScene() -> WeatherScene {
        let scene = WeatherScene()
        scene.viewModel = viewModel
        scene.audioManager = WeatherAudioManager()
        scene.size = UIScreen.main.bounds.size
        scene.scaleMode = .resizeFill
        return scene
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
                Text("Weather Location")
                    .font(.system(size: 24, weight: .bold, design: .rounded))

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
                    Text("Save")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 48)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color(r: 80, g: 160, b: 255)))
                }

                Spacer()
            }
            .padding(.top, 24)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { editingZip = viewModel.zipCode }
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
