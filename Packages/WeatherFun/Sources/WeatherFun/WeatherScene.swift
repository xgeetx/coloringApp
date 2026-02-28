// Packages/WeatherFun/Sources/WeatherFun/WeatherScene.swift
import SpriteKit

class WeatherScene: SKScene {

    // MARK: - References
    weak var viewModel: WeatherViewModel?
    var audioManager: WeatherAudioManager?

    // MARK: - Nodes
    private var skyTop: SKSpriteNode!
    private var skyBottom: SKSpriteNode!
    private var backgroundSprite: SKSpriteNode!
    private var tintOverlay: SKSpriteNode!
    var groundEffectsNode: SKNode!
    private var particleLayer: SKNode!
    private var characterLayer: SKNode!

    // MARK: - Sub-systems
    private var currentEmitter: SKEmitterNode?
    private var characterAnimator: CharacterAnimator!

    // MARK: - State
    private var currentWeatherType: WeatherType = .sunny
    private var currentIntensity: CGFloat = 0.0
    private var groundWeatherType: WeatherType?
    private var lastFlashTime: TimeInterval = 0

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .resizeFill

        setupSky()
        setupBackground()
        setupTintOverlay()

        // Container nodes for layered content
        groundEffectsNode = SKNode()
        groundEffectsNode.zPosition = 20
        addChild(groundEffectsNode)

        particleLayer = SKNode()
        particleLayer.zPosition = 30
        addChild(particleLayer)

        characterLayer = SKNode()
        characterLayer.zPosition = 40
        addChild(characterLayer)

        characterAnimator = CharacterAnimator(characterLayer: characterLayer)
        characterAnimator.audioManager = audioManager
    }

    // MARK: - Sky

    private func setupSky() {
        let halfH = UIScreen.main.bounds.height / 2

        skyTop = SKSpriteNode(color: .clear, size: CGSize(width: UIScreen.main.bounds.width, height: halfH))
        skyTop.position = CGPoint(x: 0, y: halfH / 2)
        skyTop.zPosition = -10
        addChild(skyTop)

        skyBottom = SKSpriteNode(color: .clear, size: CGSize(width: UIScreen.main.bounds.width, height: halfH))
        skyBottom.position = CGPoint(x: 0, y: -halfH / 2)
        skyBottom.zPosition = -10
        addChild(skyBottom)

        applySkyColors(for: .sunny, intensity: 0)
    }

    private func applySkyColors(for weather: WeatherType, intensity: CGFloat) {
        let config = SkyConfig.config(for: weather)
        let topC = UIColor(
            red: CGFloat(config.topColor.r) / 255,
            green: CGFloat(config.topColor.g) / 255,
            blue: CGFloat(config.topColor.b) / 255,
            alpha: 1
        )
        let botC = UIColor(
            red: CGFloat(config.bottomColor.r) / 255,
            green: CGFloat(config.bottomColor.g) / 255,
            blue: CGFloat(config.bottomColor.b) / 255,
            alpha: 1
        )
        skyTop.color = topC
        skyTop.colorBlendFactor = 1.0
        skyBottom.color = botC
        skyBottom.colorBlendFactor = 1.0
    }

    // MARK: - Background Image

    private func setupBackground() {
        // Try to load the DALL-E generated neighborhood image
        if let img = UIImage(named: "neighborhood_base", in: Bundle.module, compatibleWith: nil) {
            let texture = SKTexture(image: img)
            backgroundSprite = SKSpriteNode(texture: texture)
        } else {
            // Placeholder: green ground rectangle
            backgroundSprite = SKSpriteNode(color: UIColor(red: 0.4, green: 0.7, blue: 0.3, alpha: 1), size: CGSize(width: 800, height: 300))
        }
        backgroundSprite.position = CGPoint(x: 0, y: -size.height * 0.15)
        backgroundSprite.zPosition = 0
        backgroundSprite.setScale(min(size.width / backgroundSprite.size.width, 1.0))
        addChild(backgroundSprite)
    }

    // MARK: - Tint Overlay

    private func setupTintOverlay() {
        tintOverlay = SKSpriteNode(color: .clear, size: self.size)
        tintOverlay.zPosition = 50
        tintOverlay.alpha = 0
        addChild(tintOverlay)
    }

    private func updateTintOverlay(for weather: WeatherType, intensity: CGFloat) {
        let config = SkyConfig.config(for: weather)
        let tintC = UIColor(
            red: CGFloat(config.intenseTintColor.r) / 255,
            green: CGFloat(config.intenseTintColor.g) / 255,
            blue: CGFloat(config.intenseTintColor.b) / 255,
            alpha: 1
        )
        tintOverlay.color = tintC
        tintOverlay.colorBlendFactor = 1.0
        tintOverlay.alpha = config.intenseTintAlpha * intensity
    }

    // MARK: - Frame Update

    override func update(_ currentTime: TimeInterval) {
        guard let vm = viewModel else { return }

        let weather = vm.weatherType
        let intensity = vm.intensity

        // Update sky + particles if weather type changed
        if weather != currentWeatherType {
            applySkyColors(for: weather, intensity: intensity)
            updateParticleEmitter(for: weather, intensity: intensity)
            currentWeatherType = weather
        }

        // Update intensity-driven effects
        updateTintOverlay(for: weather, intensity: intensity)
        updateParticleIntensity(weather: weather, intensity: intensity)
        updateGroundEffects(weather: weather, intensity: intensity)
        updateLightningFlash(weather: weather, intensity: intensity, currentTime: currentTime)
        characterAnimator.update(currentTime: currentTime, weather: weather, intensity: intensity, sceneSize: size)
        audioManager?.update(weather: weather, intensity: intensity)
        currentIntensity = intensity
    }

    // MARK: - Particles

    private func updateParticleEmitter(for weather: WeatherType, intensity: CGFloat) {
        currentEmitter?.removeFromParent()
        currentEmitter = nil

        switch weather {
        case .rainy:
            let e = ParticleFactory.makeRain(sceneSize: size, intensity: intensity)
            particleLayer.addChild(e)
            currentEmitter = e
        case .snowy:
            let e = ParticleFactory.makeSnow(sceneSize: size, intensity: intensity)
            particleLayer.addChild(e)
            currentEmitter = e
        case .sunny:
            let e = ParticleFactory.makeSunRays(sceneSize: size, intensity: intensity)
            particleLayer.addChild(e)
            currentEmitter = e
        case .cloudy:
            break // no particles, just tint
        }
    }

    private func updateParticleIntensity(weather: WeatherType, intensity: CGFloat) {
        guard let emitter = currentEmitter else { return }
        switch weather {
        case .rainy:
            emitter.particleBirthRate = ParticleFactory.lerp(20, 300, t: intensity)
        case .snowy:
            emitter.particleBirthRate = ParticleFactory.lerp(10, 150, t: intensity)
            emitter.xAcceleration = intensity > IntensityThreshold.peakEffects ? 30 : 0
        case .sunny:
            emitter.particleBirthRate = ParticleFactory.lerp(0, 15, t: max(0, intensity - 0.3) / 0.7)
        case .cloudy:
            break
        }
    }

    // MARK: - Ground Effects

    private func updateGroundEffects(weather: WeatherType, intensity: CGFloat) {
        // Rebuild ground effects when weather type changes
        if weather != groundWeatherType {
            groundEffectsNode.removeAllChildren()
            groundWeatherType = weather
        }

        let groundY = -size.height * 0.35
        let show = intensity >= IntensityThreshold.groundEffects

        switch weather {
        case .rainy:
            if groundEffectsNode.children.isEmpty && show {
                // Add puddles
                let positions: [CGFloat] = [-size.width * 0.25, size.width * 0.1, size.width * 0.3]
                for (i, px) in positions.enumerated() {
                    let puddle: SKSpriteNode
                    if let img = UIImage(named: "puddle_overlay", in: Bundle.module, compatibleWith: nil) {
                        puddle = SKSpriteNode(texture: SKTexture(image: img))
                        puddle.setScale(0.15 + CGFloat(i) * 0.03)
                    } else {
                        puddle = SKSpriteNode(color: UIColor(red: 0.4, green: 0.5, blue: 0.8, alpha: 0.5), size: CGSize(width: 80, height: 30))
                    }
                    puddle.position = CGPoint(x: px, y: groundY + CGFloat(i) * 10)
                    puddle.alpha = 0
                    groundEffectsNode.addChild(puddle)
                }
            }
            // Fade puddles with intensity
            for child in groundEffectsNode.children {
                let target = show ? (intensity - IntensityThreshold.groundEffects) / (1.0 - IntensityThreshold.groundEffects) : 0
                child.alpha = target.weatherClamped(0, 0.8)
            }

        case .snowy:
            if groundEffectsNode.children.isEmpty && show {
                let snow: SKSpriteNode
                if let img = UIImage(named: "snow_ground_overlay", in: Bundle.module, compatibleWith: nil) {
                    snow = SKSpriteNode(texture: SKTexture(image: img))
                    snow.setScale(min(size.width / snow.size.width, 1.0))
                } else {
                    snow = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: 60))
                }
                snow.position = CGPoint(x: 0, y: groundY)
                snow.alpha = 0
                groundEffectsNode.addChild(snow)
            }
            for child in groundEffectsNode.children {
                let target = show ? (intensity - IntensityThreshold.groundEffects) / (1.0 - IntensityThreshold.groundEffects) : 0
                child.alpha = target.weatherClamped(0, 0.7)
            }

        case .sunny:
            if groundEffectsNode.children.isEmpty && intensity > IntensityThreshold.peakEffects {
                // Heat shimmer — semi-transparent wavy sprite
                let shimmer = SKSpriteNode(color: UIColor(white: 1.0, alpha: 0.15), size: CGSize(width: size.width * 0.6, height: 20))
                shimmer.position = CGPoint(x: 0, y: groundY + 30)
                shimmer.alpha = 0
                let wave = SKAction.sequence([
                    SKAction.moveBy(x: 0, y: 4, duration: 0.8),
                    SKAction.moveBy(x: 0, y: -4, duration: 0.8)
                ])
                shimmer.run(SKAction.repeatForever(wave))
                groundEffectsNode.addChild(shimmer)
            }
            for child in groundEffectsNode.children {
                child.alpha = intensity > IntensityThreshold.peakEffects ? 0.3 : 0
            }

        case .cloudy:
            groundEffectsNode.removeAllChildren()
        }
    }

    // MARK: - Lightning Flash

    private func updateLightningFlash(weather: WeatherType, intensity: CGFloat, currentTime: TimeInterval) {
        guard weather == .rainy, intensity > IntensityThreshold.peakEffects else { return }
        guard currentTime - lastFlashTime > 4.0 + Double.random(in: 0...3) else { return }

        lastFlashTime = currentTime
        let flash = SKSpriteNode(color: .white, size: size)
        flash.zPosition = 60
        flash.alpha = 0
        addChild(flash)
        flash.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.05),
            SKAction.fadeAlpha(to: 0, duration: 0.3),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Layout

    override func didChangeSize(_ oldSize: CGSize) {
        let w = size.width
        let h = size.height
        let halfH = h / 2

        skyTop?.size = CGSize(width: w, height: halfH)
        skyTop?.position = CGPoint(x: 0, y: halfH / 2)
        skyBottom?.size = CGSize(width: w, height: halfH)
        skyBottom?.position = CGPoint(x: 0, y: -halfH / 2)
        tintOverlay?.size = size

        if let bg = backgroundSprite, let tex = bg.texture {
            bg.setScale(min(w / tex.size().width, 1.0))
            bg.position = CGPoint(x: 0, y: -h * 0.15)
        }
    }
}
