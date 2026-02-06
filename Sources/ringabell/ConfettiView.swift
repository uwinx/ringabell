import AppKit
import QuartzCore

@MainActor
final class ConfettiView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        let root = CALayer()
        root.frame = bounds
        layer = root
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func addEmitter(_ emitter: CAEmitterLayer) {
        layer?.addSublayer(emitter)
    }
}
