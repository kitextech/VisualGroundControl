//
//  LeapMotion.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-14.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit

class LeapSettingsViewController: NSViewController {
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

class LeapListener {
    
}
