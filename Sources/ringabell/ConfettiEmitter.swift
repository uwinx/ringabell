import AppKit
import QuartzCore

enum ConfettiEmitter {

    // MARK: - Particle physics

    private static let initialVelocity: CGFloat  = 300
    private static let velocitySpread: CGFloat    = 150
    private static let gravity: CGFloat           = -150
    private static let particleLifetime: Float    = 5.0
    private static let lifetimeVariance: Float    = 1.5
    private static let baseBirthRate: Float       = 6.0
    private static let particleScale: CGFloat     = 0.6
    private static let scaleVariance: CGFloat     = 0.3
    private static let fadeRate: Float            = -0.2
    private static let spinSpeed: CGFloat         = 3.0
    private static let spinVariance: CGFloat      = 6.0
    private static let emissionSpread: CGFloat    = .pi / 4

    // MARK: - Public API

    static func makeLayer(
        screenSize: CGSize,
        colors: [NSColor],
        density: Double
    ) -> CAEmitterLayer {
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: screenSize.width / 2, y: screenSize.height + 10)
        emitter.emitterSize = CGSize(width: screenSize.width, height: 1)
        emitter.emitterShape = .line
        emitter.renderMode = .oldestLast
        emitter.emitterCells = colors.flatMap { color in
            Shape.allCases.map { makeCell(color: color, shape: $0, density: density) }
        }
        return emitter
    }

    static func stopEmission(layer: CAEmitterLayer, after duration: Double) {
        let burst = min(duration * 0.4, 1.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + burst) { [weak layer] in
            layer?.birthRate = 0
        }
    }

    // MARK: - Cell factory

    private static func makeCell(
        color: NSColor,
        shape: Shape,
        density: Double
    ) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents = shape.image
        cell.color = color.cgColor
        cell.birthRate = baseBirthRate * Float(density)
        cell.lifetime = particleLifetime
        cell.lifetimeRange = lifetimeVariance
        cell.velocity = initialVelocity
        cell.velocityRange = velocitySpread
        cell.emissionLongitude = -.pi / 2
        cell.emissionRange = emissionSpread
        cell.yAcceleration = gravity
        cell.spin = spinSpeed
        cell.spinRange = spinVariance
        cell.scale = particleScale
        cell.scaleRange = scaleVariance
        cell.alphaSpeed = fadeRate
        return cell
    }

    // MARK: - Shape rendering

    private enum Shape: CaseIterable {
        case rectangle, circle, triangle

        var image: CGImage { Self.cache[self]! }

        private static let cache: [Shape: CGImage] = {
            let size = CGSize(width: 12, height: 12)
            return Dictionary(uniqueKeysWithValues: allCases.compactMap { shape in
                render(shape, size: size).map { (shape, $0) }
            })
        }()

        private static func render(_ shape: Shape, size: CGSize) -> CGImage? {
            let image = NSImage(size: size, flipped: false) { rect in
                NSColor.white.setFill()
                switch shape {
                case .rectangle:
                    NSBezierPath(rect: rect.insetBy(dx: 1, dy: 2)).fill()
                case .circle:
                    NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
                case .triangle:
                    let path = NSBezierPath()
                    path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
                    path.line(to: CGPoint(x: rect.minX, y: rect.minY))
                    path.line(to: CGPoint(x: rect.maxX, y: rect.minY))
                    path.close()
                    path.fill()
                }
                return true
            }
            var rect = CGRect(origin: .zero, size: size)
            return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        }
    }
}
