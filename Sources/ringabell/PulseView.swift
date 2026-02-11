import AppKit
import QuartzCore

@MainActor
final class PulseView: NSView {
    private let pulseColor: NSColor

    init(frame: NSRect, color: NSColor) {
        self.pulseColor = color
        super.init(frame: frame)
        let root = CALayer()
        root.frame = bounds
        layer = root
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    func animate(duration: Double, completion: @escaping () -> Void) {
        let flash = CALayer()
        flash.frame = bounds
        flash.backgroundColor = pulseColor.withAlphaComponent(0.15).cgColor
        flash.opacity = 0
        layer?.addSublayer(flash)

        let anim = CAKeyframeAnimation(keyPath: "opacity")
        anim.values = [0.0, 1.0, 0.0]
        anim.keyTimes = [0.0, 0.2, 1.0]
        anim.duration = duration
        anim.isRemovedOnCompletion = false
        anim.fillMode = .forwards

        CATransaction.begin()
        CATransaction.setCompletionBlock(completion)
        flash.add(anim, forKey: "pulse")
        CATransaction.commit()
    }
}
