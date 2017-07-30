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
    private let lineCount = 20
    
    // MARK: - Outlets
    @IBOutlet weak var toggleOpenPortButton: NSButton!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var clearButton: NSButton!

    @IBOutlet weak var offboardButton: NSButton!
    
    // MARK: - Private Properties

    internal let kite = KiteController.kite1
    private let bag = DisposeBag()
    
    private var messages = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearButton.rx.tap.bind(onNext: clearText).disposed(by: bag)
        toggleOpenPortButton.rx.tap.bind(onNext: kite.togglePort).disposed(by: bag)

        offboardButton.bool.bind(to: kite.isOffboard).disposed(by: bag)

        kite.mavlinkMessage.subscribe(onNext: addMessage).disposed(by: bag)
    }
    
    private func addMessage(message: MavlinkMessage) {
        messages.append(message.description)
        
        if messages.count > lineCount {
            updateUI()
            messages.removeAll()
        }
    }
    
    private func clearText() {
        messages = []
        updateUI()
    }
    
    private func updateUI() {
        textView.textStorage?.mutableString.setString(messages.joined(separator: "\n"))
        textView.needsDisplay = true
    }
}

