// Packages/WeatherFun/Sources/WeatherFun/WeatherAudioManager.swift
import AVFoundation

class WeatherAudioManager {
    // MARK: - Players
    private var ambientPlayer: AVAudioPlayer?
    private var fadingOutPlayer: AVAudioPlayer?
    private var sfxPlayer: AVAudioPlayer?

    // MARK: - State
    private var currentWeatherType: WeatherType?
    private var crossfadeTimer: Timer?

    // MARK: - Init
    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Update (called per frame)

    func update(weather: WeatherType, intensity: CGFloat) {
        // Switch ambient loop if weather changed
        if weather != currentWeatherType {
            switchAmbient(to: weather)
            currentWeatherType = weather
        }

        // Scale volume with intensity
        let config = AudioConfig.config(for: weather)
        let volume = config.minVolume + (config.maxVolume - config.minVolume) * Float(intensity)
        ambientPlayer?.volume = volume
    }

    // MARK: - Character SFX

    func playCharacterSound(for weather: WeatherType) {
        let config = AudioConfig.config(for: weather)
        guard let file = config.characterSoundFile,
              let ext = config.characterSoundExtension,
              let url = Bundle.module.url(forResource: file, withExtension: ext) else {
            return
        }
        sfxPlayer = try? AVAudioPlayer(contentsOf: url)
        sfxPlayer?.volume = 0.8
        sfxPlayer?.play()
    }

    // MARK: - Ambient Crossfade

    private func switchAmbient(to weather: WeatherType) {
        let config = AudioConfig.config(for: weather)
        guard let url = Bundle.module.url(forResource: config.ambientFile, withExtension: config.ambientExtension) else {
            ambientPlayer?.stop()
            ambientPlayer = nil
            return
        }

        // Fade out old
        if let old = ambientPlayer {
            fadingOutPlayer = old
            crossfadeTimer?.invalidate()
            let fadeSteps = 30
            var step = 0
            crossfadeTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
                step += 1
                let progress = Float(step) / Float(fadeSteps)
                self?.fadingOutPlayer?.volume *= (1.0 - progress * 0.1)
                if step >= fadeSteps {
                    timer.invalidate()
                    self?.fadingOutPlayer?.stop()
                    self?.fadingOutPlayer = nil
                }
            }
        }

        // Start new
        ambientPlayer = try? AVAudioPlayer(contentsOf: url)
        ambientPlayer?.numberOfLoops = -1
        ambientPlayer?.volume = config.minVolume
        ambientPlayer?.play()
    }

    // MARK: - Cleanup

    func stop() {
        crossfadeTimer?.invalidate()
        ambientPlayer?.stop()
        fadingOutPlayer?.stop()
        sfxPlayer?.stop()
    }
}
