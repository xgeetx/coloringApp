// Packages/WeatherFun/Sources/WeatherFun/CharacterAnimator.swift
import SpriteKit

class CharacterAnimator {

    // MARK: - State
    private var isAnimating = false
    private var lastTriggerTime: TimeInterval = 0
    private weak var characterLayer: SKNode?
    private var sceneSize: CGSize = .zero
    weak var audioManager: WeatherAudioManager?

    init(characterLayer: SKNode) {
        self.characterLayer = characterLayer
    }

    // MARK: - Update

    func update(currentTime: TimeInterval, weather: WeatherType, intensity: CGFloat, sceneSize: CGSize) {
        self.sceneSize = sceneSize

        guard intensity >= IntensityThreshold.characterTrigger,
              !isAnimating,
              currentTime - lastTriggerTime >= CharacterConfig.config(for: weather).cooldown else {
            return
        }

        triggerCharacter(weather: weather, currentTime: currentTime)
    }

    // MARK: - Trigger

    private func triggerCharacter(weather: WeatherType, currentTime: TimeInterval) {
        guard let layer = characterLayer else { return }
        isAnimating = true
        lastTriggerTime = currentTime

        let config = CharacterConfig.config(for: weather)
        let sprite: SKSpriteNode

        // Try sprite sheet first, fall back to emoji
        if let textures = loadSpriteSheet(named: config.spriteSheet, frameCount: config.frameCount), !textures.isEmpty {
            sprite = SKSpriteNode(texture: textures.first)
            applyFrameAnimation(sprite: sprite, textures: textures, weather: weather, config: config)
        } else {
            sprite = makePlaceholderSprite(for: weather)
        }

        // Play character sound effect
        audioManager?.playCharacterSound(for: weather)

        // Start offscreen left, move to offscreen right
        let startX = -sceneSize.width / 2 - 100
        let endX = sceneSize.width / 2 + 100
        let groundY = -sceneSize.height * 0.3

        sprite.position = CGPoint(x: startX, y: groundY)
        sprite.setScale(0.3)
        sprite.zPosition = 5
        layer.addChild(sprite)

        let cleanup = SKAction.sequence([
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in self?.isAnimating = false }
        ])

        switch weather {
        case .rainy:
            // Run most of the way, then jump over a puddle
            let runDist = endX - startX
            let jumpX = startX + runDist * 0.7

            let runToJump = SKAction.moveTo(x: jumpX, duration: config.crossDuration * 0.7)
            runToJump.timingMode = .easeIn

            let jumpUp = SKAction.moveBy(x: 40, y: 60, duration: 0.25)
            jumpUp.timingMode = .easeOut
            let jumpDown = SKAction.moveBy(x: 40, y: -60, duration: 0.2)
            jumpDown.timingMode = .easeIn

            let runOff = SKAction.moveTo(x: endX, duration: config.crossDuration * 0.3)
            runOff.timingMode = .easeOut

            sprite.run(SKAction.sequence([runToJump, jumpUp, jumpDown, runOff, cleanup]))

        case .sunny:
            // Skip across with a little hop at the end
            let runDist = endX - startX
            let twirlX = startX + runDist * 0.65

            let skipTo = SKAction.moveTo(x: twirlX, duration: config.crossDuration * 0.65)
            skipTo.timingMode = .easeIn

            // Little twirl-jump
            let hopUp = SKAction.moveBy(x: 20, y: 40, duration: 0.2)
            hopUp.timingMode = .easeOut
            let hopDown = SKAction.moveBy(x: 20, y: -40, duration: 0.2)
            hopDown.timingMode = .easeIn

            let skipOff = SKAction.moveTo(x: endX, duration: config.crossDuration * 0.35)
            skipOff.timingMode = .easeOut

            sprite.run(SKAction.sequence([skipTo, hopUp, hopDown, skipOff, cleanup]))

        case .cloudy:
            // Walk across, slow down in middle (looking up), then lean into wind
            let runDist = endX - startX
            let lookX = startX + runDist * 0.5
            let windX = startX + runDist * 0.7

            let walkToLook = SKAction.moveTo(x: lookX, duration: config.crossDuration * 0.5)
            walkToLook.timingMode = .easeIn

            // Pause briefly looking up
            let pause = SKAction.moveTo(x: windX, duration: config.crossDuration * 0.3)
            pause.timingMode = .linear

            let walkOff = SKAction.moveTo(x: endX, duration: config.crossDuration * 0.2)
            walkOff.timingMode = .easeOut

            sprite.run(SKAction.sequence([walkToLook, pause, walkOff, cleanup]))

        case .snowy:
            // Walk, pause to scoop snow, then continue (throw while walking off)
            let runDist = endX - startX
            let scoopX = startX + runDist * 0.55

            let walkToScoop = SKAction.moveTo(x: scoopX, duration: config.crossDuration * 0.55)
            walkToScoop.timingMode = .easeIn

            // Brief pause while scooping
            let scoop = SKAction.wait(forDuration: 0.4)

            let walkOff = SKAction.moveTo(x: endX, duration: config.crossDuration * 0.45)
            walkOff.timingMode = .easeOut

            sprite.run(SKAction.sequence([walkToScoop, scoop, walkOff, cleanup]))
        }
    }

    // MARK: - Frame Animation

    private func applyFrameAnimation(sprite: SKSpriteNode, textures: [SKTexture], weather: WeatherType, config: CharacterConfig) {
        guard textures.count >= 4 else {
            let animate = SKAction.animate(with: textures, timePerFrame: config.timePerFrame)
            sprite.run(SKAction.repeatForever(animate))
            return
        }

        // All weather types: run cycle (frames 0-1) for most of the journey,
        // then action frames (2-3) near the end
        let runCycle = SKAction.animate(with: [textures[0], textures[1]], timePerFrame: config.timePerFrame)
        let runLoop = SKAction.repeat(runCycle, count: 6)

        switch weather {
        case .rainy:
            // Run → jump → splash
            let jumpFrame = SKAction.animate(with: [textures[2]], timePerFrame: 0.3)
            let splashFrame = SKAction.animate(with: [textures[3]], timePerFrame: 0.5)
            sprite.run(SKAction.sequence([runLoop, jumpFrame, splashFrame]))

        case .sunny:
            // Skip → twirl → jump for joy
            let twirlFrame = SKAction.animate(with: [textures[2]], timePerFrame: 0.4)
            let jumpFrame = SKAction.animate(with: [textures[3]], timePerFrame: 0.4)
            sprite.run(SKAction.sequence([runLoop, twirlFrame, jumpFrame]))

        case .cloudy:
            // Walk → look up at sky → lean into wind
            let lookFrame = SKAction.animate(with: [textures[2]], timePerFrame: 0.5)
            let windFrame = SKAction.animate(with: [textures[3]], timePerFrame: 0.6)
            sprite.run(SKAction.sequence([runLoop, lookFrame, windFrame]))

        case .snowy:
            // Walk → scoop snow → throw snowball
            let scoopFrame = SKAction.animate(with: [textures[2]], timePerFrame: 0.4)
            let throwFrame = SKAction.animate(with: [textures[3]], timePerFrame: 0.5)
            sprite.run(SKAction.sequence([runLoop, scoopFrame, throwFrame]))
        }
    }

    // MARK: - Sprite Sheet Loading

    private func loadSpriteSheet(named name: String, frameCount: Int) -> [SKTexture]? {
        guard let image = UIImage(named: name, in: Bundle.module, compatibleWith: nil) else {
            return nil
        }

        let texture = SKTexture(image: image)
        let imgWidth = image.size.width
        let imgHeight = image.size.height

        // Detect layout: if wider than tall, assume horizontal strip
        let aspect = imgWidth / imgHeight
        let isHorizontalStrip = aspect > 2.0

        if isHorizontalStrip {
            let frameWidth = 1.0 / CGFloat(frameCount)
            var textures: [SKTexture] = []
            for i in 0..<frameCount {
                let rect = CGRect(x: CGFloat(i) * frameWidth, y: 0, width: frameWidth, height: 1.0)
                textures.append(SKTexture(rect: rect, in: texture))
            }
            return textures
        } else {
            // Grid layout: use top row
            let cols = max(frameCount, Int(round(aspect * 2)))
            let rows = 2
            let frameW = 1.0 / CGFloat(cols)
            let frameH = 1.0 / CGFloat(rows)
            var textures: [SKTexture] = []
            for i in 0..<min(frameCount, cols) {
                let rect = CGRect(x: CGFloat(i) * frameW, y: 0, width: frameW, height: frameH)
                textures.append(SKTexture(rect: rect, in: texture))
            }
            return textures.isEmpty ? nil : textures
        }
    }

    // MARK: - Placeholder

    private func makePlaceholderSprite(for weather: WeatherType) -> SKSpriteNode {
        let colors: [WeatherType: UIColor] = [
            .sunny: .yellow,
            .cloudy: .gray,
            .rainy: .blue,
            .snowy: .white
        ]
        let emoji: [WeatherType: String] = [
            .sunny: "😎",
            .cloudy: "🌂",
            .rainy: "🌧️",
            .snowy: "⛄"
        ]

        let size = CGSize(width: 80, height: 80)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        let ctx = UIGraphicsGetCurrentContext()!
        ctx.setFillColor((colors[weather] ?? .gray).cgColor)
        ctx.fillEllipse(in: CGRect(origin: .zero, size: size))

        let str = emoji[weather] ?? "?"
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40)]
        let strSize = (str as NSString).size(withAttributes: attrs)
        (str as NSString).draw(at: CGPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2), withAttributes: attrs)

        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return SKSpriteNode(texture: SKTexture(image: img))
    }
}
