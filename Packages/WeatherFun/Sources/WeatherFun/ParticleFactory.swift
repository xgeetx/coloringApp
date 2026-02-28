// Packages/WeatherFun/Sources/WeatherFun/ParticleFactory.swift
import SpriteKit

enum ParticleFactory {

    // MARK: - Rain

    static func makeRain(sceneSize: CGSize, intensity: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = lerp(20, 300, t: intensity)
        emitter.particleLifetime = 1.5
        emitter.particleLifetimeRange = 0.5

        // White-blue raindrop
        emitter.particleColor = UIColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.7)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = lerp(0.3, 0.8, t: intensity)
        emitter.particleScale = 0.05
        emitter.particleScaleRange = 0.02

        // Fall downward with slight angle
        emitter.emissionAngle = -.pi / 2  // straight down
        emitter.emissionAngleRange = 0.2
        emitter.particleSpeed = lerp(300, 600, t: intensity)
        emitter.particleSpeedRange = 100

        // Emit across top of screen
        emitter.position = CGPoint(x: 0, y: sceneSize.height / 2 + 50)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width * 1.2, dy: 0)

        // Raindrop shape: thin vertical rect
        emitter.particleTexture = makeTexture(width: 3, height: 12, cornerRadius: 1)

        return emitter
    }

    // MARK: - Snow

    static func makeSnow(sceneSize: CGSize, intensity: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = lerp(10, 150, t: intensity)
        emitter.particleLifetime = 4.0
        emitter.particleLifetimeRange = 1.5

        emitter.particleColor = .white
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = lerp(0.5, 1.0, t: intensity)
        emitter.particleScale = lerp(0.08, 0.15, t: intensity)
        emitter.particleScaleRange = 0.04

        // Gentle drift down
        emitter.emissionAngle = -.pi / 2
        emitter.emissionAngleRange = 0.6
        emitter.particleSpeed = lerp(40, 120, t: intensity)
        emitter.particleSpeedRange = 30

        emitter.position = CGPoint(x: 0, y: sceneSize.height / 2 + 50)
        emitter.particlePositionRange = CGVector(dx: sceneSize.width * 1.2, dy: 0)

        // Small circle for snowflake
        emitter.particleTexture = makeTexture(width: 8, height: 8, oval: true)

        return emitter
    }

    // MARK: - Sun Rays (visible at high sunny intensity)

    static func makeSunRays(sceneSize: CGSize, intensity: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = lerp(0, 15, t: max(0, intensity - 0.3) / 0.7)
        emitter.particleLifetime = 2.0
        emitter.particleLifetimeRange = 0.5

        emitter.particleColor = UIColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 0.3)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleAlpha = lerp(0.0, 0.4, t: intensity)
        emitter.particleAlphaSpeed = -0.15
        emitter.particleScale = 0.5
        emitter.particleScaleRange = 0.3

        // Radiate from top-right corner
        emitter.position = CGPoint(x: sceneSize.width * 0.35, y: sceneSize.height * 0.4)
        emitter.emissionAngle = -.pi * 0.6
        emitter.emissionAngleRange = .pi * 0.4
        emitter.particleSpeed = 50
        emitter.particleSpeedRange = 20

        // Elongated ray shape
        emitter.particleTexture = makeTexture(width: 4, height: 40, cornerRadius: 2)

        return emitter
    }

    // MARK: - Helpers

    static func lerp(_ a: CGFloat, _ b: CGFloat, t: CGFloat) -> CGFloat {
        a + (b - a) * t.weatherClamped(0, 1)
    }

    private static func makeTexture(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 0, oval: Bool = false) -> SKTexture {
        let sz = CGSize(width: width, height: height)
        UIGraphicsBeginImageContextWithOptions(sz, false, 0)
        UIColor.white.setFill()
        if oval {
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: sz)).fill()
        } else {
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: sz), cornerRadius: cornerRadius).fill()
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return SKTexture(image: img)
    }
}

extension CGFloat {
    func weatherClamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        Swift.min(Swift.max(self, lo), hi)
    }
}
