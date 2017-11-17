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
    @IBOutlet weak var serialPortSelector: NSPopUpButton!
    @IBOutlet weak var toggleOpenPortButton: NSButton!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var kiteTitle: NSTextField!

    @IBOutlet weak var offboardButton: NSButton!

    // MARK: - Private Properties

    @objc dynamic internal let kite: KiteLink
    private let bag = DisposeBag()
    private var showParams = true

    @objc dynamic private var messages = [String]()

    required init?(coder: NSCoder) {
        kite = KiteController.availableKite
        kite.isAvailable = false
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        toggleOpenPortButton.rx.tap.bind(onNext: kite.togglePort).disposed(by: bag)
        offboardButton.bool.bind(to: kite.isOffboard).disposed(by: bag)
        kite.mavlinkMessage.subscribe(onNext: addMessage).disposed(by: bag)
        kite.parameterLog.asObservable().distinctUntilChanged().subscribe(onNext: updateLogWithParams).disposed(by: bag)
        kite.isSerialPortOpen.asObservable().distinctUntilChanged().subscribe(onNext: serialPortChanged).disposed(by: bag)
        kiteTitle.stringValue = "Kite \(kite.box.tarSysId)"
    }

    @IBAction func didChangeLogSelection(_ sender: NSButton) {
        messages.removeAll()
        textView.textStorage?.mutableString.setString("---")
        showParams = sender.tag == 0
        updateUI()
    }

    private func serialPortChanged(open: Bool) {
        toggleOpenPortButton.title = open ? "Close" : "Open"
    }

    private func addMessage(message: MavlinkMessage) {
        messages.append(message.description)
        
        if messages.count > lineCount && !showParams {
            updateUI()
            messages.removeAll()
        }
    }

    private func updateUI() {
        if showParams {
            updateLogWithParams(log: kite.parameterLog.value)
        }
        else {
            textView.textStorage?.mutableString.setString(messages.joined(separator: "\n"))
        }
        textView.needsDisplay = true
    }

    private func updateLogWithParams(log: String) {
        guard showParams else { return }
        textView.textStorage?.mutableString.setString(log)
    }
}

