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

        // Try to load sprite sheet from bundle
        if let textures = loadSpriteSheet(named: config.spriteSheet, frameCount: config.frameCount) {
            sprite = SKSpriteNode(texture: textures.first)
            let animate = SKAction.animate(with: textures, timePerFrame: config.timePerFrame)
            sprite.run(SKAction.repeatForever(animate))
        } else {
            // Fallback: colored circle with emoji
            sprite = makePlaceholderSprite(for: weather)
        }

        // Play character sound effect
        audioManager?.playCharacterSound(for: weather)

        // Start offscreen left, move to offscreen right
        let startX = -sceneSize.width / 2 - 80
        let endX = sceneSize.width / 2 + 80
        let groundY = -sceneSize.height * 0.3

        sprite.position = CGPoint(x: startX, y: groundY)
        sprite.setScale(0.5)
        sprite.zPosition = 5
        layer.addChild(sprite)

        let move = SKAction.moveTo(x: endX, duration: config.crossDuration)
        move.timingMode = .easeInEaseOut

        sprite.run(SKAction.sequence([
            move,
            SKAction.removeFromParent(),
            SKAction.run { [weak self] in
                self?.isAnimating = false
            }
        ]))
    }

    // MARK: - Sprite Sheet Loading

    private func loadSpriteSheet(named name: String, frameCount: Int) -> [SKTexture]? {
        guard let image = UIImage(named: name, in: Bundle.module, compatibleWith: nil) else {
            return nil
        }

        let texture = SKTexture(image: image)
        let imgWidth = image.size.width
        let imgHeight = image.size.height

        // Detect layout: if wider than tall, assume horizontal strip;
        // if roughly square or taller, assume grid (use top row)
        let aspect = imgWidth / imgHeight
        let isHorizontalStrip = aspect > 2.0

        if isHorizontalStrip {
            // Horizontal strip: divide into frameCount equal columns
            let frameWidth = 1.0 / CGFloat(frameCount)
            var textures: [SKTexture] = []
            for i in 0..<frameCount {
                let rect = CGRect(x: CGFloat(i) * frameWidth, y: 0, width: frameWidth, height: 1.0)
                textures.append(SKTexture(rect: rect, in: texture))
            }
            return textures
        } else {
            // Grid layout (DALL-E often produces 2 rows): use top row
            // Estimate columns from aspect ratio
            let cols = max(frameCount, Int(round(aspect * 2)))
            let rows = 2
            let frameW = 1.0 / CGFloat(cols)
            let frameH = 1.0 / CGFloat(rows)
            var textures: [SKTexture] = []
            for i in 0..<min(frameCount, cols) {
                // Top row: y starts at 0 in SpriteKit texture coords (bottom-left origin)
                // But SKTexture rect y=0 is top, so top row is y=0
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
