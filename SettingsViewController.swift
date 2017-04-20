//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

class SettingsModel {
    public let kite: KiteLink

    private let kiteLocalPosition = Variable<Vector>(.zero)

    private var currentLocalPosition: Vector = .zero
    private var currentGlobalPosition: GPSVector = .zero

    private let bag = DisposeBag()

    init(kite: KiteLink) {
        self.kite = kite

        kite.location.map(KiteLocation.getPosition).bindTo(kiteLocalPosition).disposed(by: bag)
        kite.globalPosition.map(KiteGpsPosition.getPosition).subscribe(onNext: updatePositions).disposed(by: bag)
    }

    public func saveB() {
        kite.globalPositionB.value = currentGlobalPosition
        kite.localPositionB.value = currentLocalPosition
    }

    private func updatePositions(global: GPSVector) {
        currentGlobalPosition = global
        currentLocalPosition = kiteLocalPosition.value
    }
}

class SettingsViewController: NSViewController {
    private var model: SettingsModel!

    // MARK: - Outlets

    @IBOutlet weak var errorLabel: NSTextField!

    @IBOutlet weak var positionLabel: NSTextField!
    @IBOutlet weak var tetherLengthSlider: NSSlider!
    @IBOutlet weak var tetherLengthLabel: NSTextField!

    @IBOutlet weak var phiCSlider: NSSlider!
    @IBOutlet weak var thetaCSlider: NSSlider!
    @IBOutlet weak var turningRadiousSlider: NSSlider!

    @IBOutlet weak var phiCLabel: NSTextField!
    @IBOutlet weak var thetaCLabel: NSTextField!
    @IBOutlet weak var turningRLabel: NSTextField!

    @IBOutlet weak var tetheredHoverThrustSlider: NSSlider!

    // MARK: Private

    // MARK: BAG
    private let bag = DisposeBag()
    
    @IBAction func pressedUseAsB(_ sender: NSButton) {
        model.saveB()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        model = SettingsModel(kite: KiteController.kite(kiteIndex))

        // Controls
        tetherLengthSlider.scalar.bindTo(model.kite.tetherLength).disposed(by: bag)

        tetheredHoverThrustSlider.scalar.bindTo(model.kite.tetheredHoverThrust).disposed(by: bag)

        phiCSlider.scalar.bindTo(model.kite.phiC).disposed(by: bag)
        thetaCSlider.scalar.bindTo(model.kite.thetaC).disposed(by: bag)
        turningRadiousSlider.scalar.bindTo(model.kite.turningRadius).disposed(by: bag)

        // UI

        model.kite.tetherLength.asObservable().map(getScalarString).bindTo(tetherLengthLabel.rx.text).disposed(by: bag)

        model.kite.globalPosition.asObservable().map { "GPS: \($0.pos.lat), \($0.pos.lon). \($0.pos.alt/1000)" }.bindTo(positionLabel.rx.text).disposed(by: bag)

        phiCSlider.scalar.map(getScalarString).bindTo(phiCLabel.rx.text).disposed(by: bag)
        thetaCSlider.scalar.map(getScalarString).bindTo(thetaCLabel.rx.text).disposed(by: bag)
        turningRadiousSlider.scalar.map(getScalarString).bindTo(turningRLabel.rx.text).disposed(by: bag)

        model.kite.errorMessage.bindTo(errorLabel.rx.text).disposed(by: bag)
    }

    @IBAction func selectedOffboardMode(_ sender: NSButton) {
        let submode = OffboardFlightMode(sender.tag, subNumber: 0)
        model.kite.flightMode.value = .offboard(subMode: submode)
    }

    @IBAction func togglePosCtr(_ sender: NSButton) {
        model.kite.offboardPositionTethered.value = !model.kite.offboardPositionTethered.value
    }

    private func getScalarString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }
}

