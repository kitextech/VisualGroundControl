//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit

class SettingsViewController: NSViewController {
    private let kite = KiteLink.shared
    
    // MARK: - Outlets
    @IBOutlet weak var positionLabel: NSTextField!
    
    
    @IBAction func pressedUseAsB(_ sender: NSButton) {
    }
    
    
}

struct Settings {
    public static let shared = Settings()
    
    
    
}
