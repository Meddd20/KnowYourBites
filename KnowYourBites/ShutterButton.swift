//
//  ShutterButton.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 10/09/25.
//

import Foundation
import UIKit

final class ShutterButton: UIControl {
    private let core = UIView()
    private let innerRing = CAShapeLayer()

    var diameter: CGFloat = 100 { didSet { setNeedsLayout() } }
    var ringWidth: CGFloat = 4   { didSet { setNeedsLayout() } }

    /// spacing between outer edge and the white ring
    var ringGap: CGFloat = 4     { didSet { setNeedsLayout() } }

    /// spacing between ring and filled core
    var coreGap: CGFloat = 4     { didSet { setNeedsLayout() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        setup()
    }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = .clear

        core.backgroundColor = .white
        core.isUserInteractionEnabled = false
        addSubview(core)

        innerRing.fillColor = UIColor.clear.cgColor
        innerRing.strokeColor = UIColor.white.cgColor
        innerRing.lineWidth = ringWidth
        layer.addSublayer(innerRing)

        addTarget(self, action: #selector(down), for: [.touchDown, .touchDragEnter])
        addTarget(self, action: #selector(up), for: [.touchCancel, .touchDragExit, .touchUpInside, .touchUpOutside])
    }

    override var intrinsicContentSize: CGSize { CGSize(width: diameter, height: diameter) }

    override func layoutSubviews() {
        super.layoutSubviews()
        let size = CGSize(width: diameter, height: diameter)
        let origin = CGPoint(x: (bounds.width - size.width)/2, y: (bounds.height - size.height)/2)
        let circleFrame = CGRect(origin: origin, size: size)

        // draw the ring
        let innerRect = circleFrame.insetBy(dx: ringWidth + ringGap, dy: ringWidth + ringGap)
        innerRing.path = UIBezierPath(ovalIn: innerRect).cgPath
        innerRing.lineWidth = ringWidth

        // draw the core circle
        let coreInset = (ringWidth + ringGap) + ringWidth + coreGap
        let coreRect = circleFrame.insetBy(dx: coreInset, dy: coreInset)
        core.frame = coreRect
        core.layer.cornerRadius = coreRect.width/2
    }

    @objc private func down() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        UIView.animate(withDuration: 0.1) {
            self.core.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            self.alpha = 0.9
        }
    }

    @objc private func up() {
        UIView.animate(withDuration: 0.12) {
            self.transform = .identity
            self.alpha = 1.0
        }
        sendActions(for: .primaryActionTriggered)
    }
}
