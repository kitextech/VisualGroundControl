//
//  LeapMotion.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-14.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

class LeapViewController: NSViewController {
    enum ControlScheme {
        case attitude
        case position(tethered: Bool)
    }
    
    private var scheme: ControlScheme = .attitude
    
    @IBAction func controlChanged(_ sender: NSButton) {
        print("Control changed: \(sender.tag)")
        
        switch sender.tag {
        case 0: scheme = .attitude
        case 1: scheme = .position(tethered: false)
        default: scheme = .position(tethered: true)
        }
    }
}

class LeapListener: NSObject, LeapDelegate {
    public static let shared = LeapListener()
    
    // MARK: - Public Variables Rx
    
    public let leftHand = PublishSubject<LeapHand>()
    public let rightHand = PublishSubject<LeapHand>()

    private let controller = LeapController()!
    
    // MARK: - Public Methods

    public func start() {
        controller.addDelegate(self)
        print("Leap started")
    }
    
    // MARK: - Leap Delegate Methods
    
    func onInit(_ controller: LeapController!) {
        print("Leap initialized")
    }
    
    func onConnect(_ controller: LeapController!) {
        print("Leap connected")
//        controller.enable(LEAP_GESTURE_TYPE_CIRCLE, enable: true)
//        controller.enable(LEAP_GESTURE_TYPE_KEY_TAP, enable: true)
//        controller.enable(LEAP_GESTURE_TYPE_SCREEN_TAP, enable: true)
        controller.enable(LEAP_GESTURE_TYPE_SWIPE, enable: true)
    }
    
    func onDisconnect(_ controller: LeapController!) {
        print("Leap disconnected")
    }
    
    func onServiceConnect(_ controller: LeapController!) {
        print("Leap service disconnected")
    }
    
    func onDeviceChange(_ controller: LeapController!) {
        print("Leap device changed")
    }
    
    func onExit(_ controller: LeapController!) {
        print("Leap exited")
    }
    
    func onFrame(_ controller: LeapController!) {
        let hands = controller.frame(0)!.hands as! [LeapHand]
        
        for hand in hands {
            (hand.isLeft ? leftHand : rightHand).onNext(hand)
        }
    }
    
    func onFocusGained(_ controller: LeapController!) {
        print("Leap focus gained")
    }
    
    func onFocusLost(_ controller: LeapController!) {
        print("Leap focus lost")
    }
    
}
