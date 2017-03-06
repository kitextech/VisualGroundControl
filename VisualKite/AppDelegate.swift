//
//  AppDelegate.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-02-25.
//  Copyright (c) 2017 Gustaf Kugelberg. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    @IBOutlet weak var window: NSWindow!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if #available(OSX 10.12.2, *) {
            NSApplication.shared().isAutomaticCustomizeTouchBarMenuItemEnabled = true
        }
    }
    
}
