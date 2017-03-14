//
//  SerialViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-14.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift
import RxCocoa
import ORSSerial

class SerialViewController: NSViewController {
    private let lineCount = 100
    private let maxLineCount = 1000
    
    // MARK: - Outlets
    @IBOutlet weak var toggleOpenPortButton: NSButton!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var clearButton: NSButton!

    @IBOutlet weak var thrustSlider: NSSlider!
    @IBOutlet weak var offboardButton: NSButton!
    
    // MARK: - Private Properties

    private let kite = KiteLink.shared
    private let bag = DisposeBag()
    
    private var messages = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearButton.rx.tap.bindNext(clearText).disposed(by: bag)
        toggleOpenPortButton.rx.tap.bindNext(kite.togglePort).disposed(by: bag)
        
        thrustSlider.rx.value.map(Float.init).bindTo(kite.thrust).disposed(by: bag)
        
        offboardButton.bool.bindTo(kite.isOffboard).disposed(by: bag)

        kite.mavlinkMessage.subscribe(onNext: addMessage).disposed(by: bag)
    }
    
    private func addMessage(message: String) {
        messages.append(message)
        
        print("Added message: \(message)")
        
        if messages.count > maxLineCount {
            messages.removeFirst(maxLineCount - lineCount)
        }
        
        updateUI()
    }
    
    private func clearText() {
        messages = []
        updateUI()
    }
    
    private func updateUI() {
        let contents: String
        
        if messages.isEmpty {
            contents = " -- No messages --"
        }
        else {
            let range = max(messages.count - lineCount, 0)..<messages.count
            contents = messages[range].joined()
        }
        
        textView.textStorage?.mutableString.setString(contents)
        textView.needsDisplay = true
    }
}

