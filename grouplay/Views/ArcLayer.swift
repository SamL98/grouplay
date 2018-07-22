//
//  ArcLayer.swift
//  grouplay
//
//  Created by Sam Lerner on 5/10/18.
//  Copyright © 2018 Sam Lerner. All rights reserved.
//

import UIKit

class ArcLayer: CAShapeLayer {
    
    var parentFrame: CGRect
    var timeLimit: Int! {
        didSet {
            self.counter = timeLimit
            self.initializePath()
        }
    }
    var counter: Int = 0
    
    init(frame: CGRect) {
        self.parentFrame = frame
        super.init()
        self.bounds = CGRect(x: 0.0, y: 0.0, width: frame.width, height: frame.height)
        self.position = CGPoint(x: frame.width/2, y: frame.height/2)
        fillColor = UIColor.clear.cgColor
        strokeColor = UIColor(red: 124.0/255.0, green: 222.0/255.0, blue: 117.0/255.0, alpha: 1.0).cgColor
        //strokeColor = UIColor.blue.cgColor
        lineWidth = 4.0
        lineCap = kCALineCapRound
        lineJoin = kCALineJoinRound
    }
    
    override init(layer: Any) {
        self.parentFrame = CGRect.zero
        super.init(layer: layer)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func initializePath() {
        path = createPath(timeLimit).cgPath
    }
    
    private func createPath(_ time: Int) -> UIBezierPath {
        if time < 0 { return UIBezierPath() }
        let center = CGPoint(x: self.parentFrame.width/2, y: self.parentFrame.height/2)
        
        let increment = 3.14/(Double(timeLimit)/2.0)
        let offset = Double(timeLimit-time)*(increment)
        let endAngle = CGFloat(-1.57 + offset)
        
        let arcPath = UIBezierPath()
        arcPath.addArc(withCenter: center, radius: self.parentFrame.width/2 - 7.5, startAngle: -CGFloat(1.57), endAngle: endAngle, clockwise: true)
        return arcPath
    }
    
    func animateArc() {
        counter -= 1
        guard counter > 0 else { return }
        let nextPath = createPath(counter).cgPath
        
        path = nextPath
        let stroke = CABasicAnimation(keyPath: "strokeEnd")
        stroke.fromValue = CGFloat(1.0 - 1.0/Double(timeLimit-counter))
        stroke.toValue = 1.0
        stroke.beginTime = 0.0
        stroke.duration = 0.325
        stroke.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        stroke.fillMode = kCAFillModeForwards
        stroke.isRemovedOnCompletion = false
        add(stroke, forKey: nil)
    }

}
