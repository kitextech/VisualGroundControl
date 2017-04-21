//
//  SettingsViewController.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-15.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import AppKit
import RxSwift

/*
tetherLengthSlider.scalar.bindTo(model.kite.tetherLength).disposed(by: bag)

tetheredHoverThrustSlider.scalar.bindTo(model.kite.tetheredHoverThrust).disposed(by: bag)

phiCSlider.scalar.bindTo(model.kite.phiC).disposed(by: bag)
thetaCSlider.scalar.bindTo(model.kite.thetaC).disposed(by: bag)
turningRadiousSlider.scalar.bindTo(model.kite.turningRadius).disposed(by: bag)
*/

class SettingsModel {
    private let kiteLocalPosition0 = Variable<Vector>(.zero)
    private var currentLocalPosition0: Vector = .zero
    private var currentGlobalPosition0: GPSVector = .zero

    private let kiteLocalPosition1 = Variable<Vector>(.zero)
    private var currentLocalPosition1: Vector = .zero
    private var currentGlobalPosition1: GPSVector = .zero

    private let bag = DisposeBag()

    init(_ tetherLength: Observable<Scalar>, _ hoverThrust: Observable<Scalar>, _ phiC: Observable<Scalar>, _ thetaC: Observable<Scalar>, _ turningRadius: Observable<Scalar>) {

        [KiteController.kite0, KiteController.kite1].forEach { kite in
            tetherLength.bindTo(kite.tetheredHoverThrust).addDisposableTo(bag)

            phiC.bindTo(kite.phiC).disposed(by: bag)
            thetaC.bindTo(kite.thetaC).disposed(by: bag)
            turningRadius.bindTo(kite.turningRadius).disposed(by: bag)
        }

        KiteController.kite0.location.map(KiteLocation.getPosition).bindTo(kiteLocalPosition0).disposed(by: bag)
        KiteController.kite0.globalPosition.map(KiteGpsPosition.getPosition).subscribe(onNext: updatePositions0).disposed(by: bag)

        KiteController.kite1.location.map(KiteLocation.getPosition).bindTo(kiteLocalPosition1).disposed(by: bag)
        KiteController.kite1.globalPosition.map(KiteGpsPosition.getPosition).subscribe(onNext: updatePositions1).disposed(by: bag)
    }

    public func saveB(kiteIndex: Int) {
        if kiteIndex == 0 {
            KiteController.kite0.globalPositionB.value = currentGlobalPosition0
            KiteController.kite0.localPositionB.value = currentLocalPosition0
        }
        else {
            KiteController.kite1.globalPositionB.value = currentGlobalPosition1
            KiteController.kite1.localPositionB.value = currentLocalPosition1
        }
    }

    private func updatePositions0(global: GPSVector) {
        currentGlobalPosition0 = global
        currentLocalPosition0 = kiteLocalPosition0.value
    }

    private func updatePositions1(global: GPSVector) {
        currentGlobalPosition1 = global
        currentLocalPosition1 = kiteLocalPosition1.value
    }

    private func updatePositions(kiteIndex: Int) -> (GPSVector) -> Void {
        return { [unowned self] global in
            self.currentGlobalPosition1 = global
            self.currentLocalPosition1 = self.kiteLocalPosition1.value
        }
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

        model = SettingsModel(tetherLengthSlider.scalar, tetheredHoverThrustSlider.scalar, phiCSlider.scalar, thetaCSlider.scalar, turningRadiousSlider.scalar)

        // Controls

        // UI

        tetherLengthSlider.scalar.map(getScalarString).bindTo(tetherLengthLabel.rx.text).disposed(by: bag)

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

