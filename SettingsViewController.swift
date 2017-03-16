//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift


class SettingsViewController: NSViewController {
    private let kite = KiteLink.shared
    
    // MARK: - Outlets
    @IBOutlet weak var positionLabel: NSTextField!
    @IBOutlet weak var tetherLengthSlider: NSSlider!
    @IBOutlet weak var tetherLengthLabel: NSTextField!
    
    // MARK: BAG
    private let bag = DisposeBag()
    
    @IBAction func pressedUseAsB(_ sender: NSButton) {
    }
    
    override func viewDidLoad() {
        tetherLengthSlider.scalar.bindTo(kite.tetherLength).disposed(by: bag)
        tetherLengthSlider.scalar.map(getString).bindTo(tetherLengthLabel.rx.text).disposed(by: bag)
        
    }
    
    private func getString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }
    
    
    
}

struct Settings {
    public static let shared = Settings()
    
    
    
}
