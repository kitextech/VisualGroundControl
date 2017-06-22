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
tetherLengthSlider.scalar.bind(to: model.kite.tetherLength).disposed(by: bag)

tetheredHoverThrustSlider.scalar.bind(to: model.kite.tetheredHoverThrust).disposed(by: bag)

phiCSlider.scalar.bind(to: model.kite.phiC).disposed(by: bag)
thetaCSlider.scalar.bind(to: model.kite.thetaC).disposed(by: bag)
turningRadiousSlider.scalar.bind(to: model.kite.turningRadius).disposed(by: bag)
*/

class SettingsModel {
    private let localPositions: [Variable<Vector>] = [Variable(.zero), Variable(.zero)]
    private var currentLocalPositions: [Vector] = [.zero, .zero]
    private var currentGlobalPositions: [GPSVector] = [.zero, .zero]

    private let bag = DisposeBag()

    init(_ tetherLength: Observable<Scalar>, _ hoverThrust: Observable<Scalar>, _ phiC: Observable<Scalar>, _ thetaC: Observable<Scalar>, _ turningRadius: Observable<Scalar>) {

        [KiteController.kite0, KiteController.kite1].enumerated().forEach { index, kite in
            // Common
            tetherLength.bind(to: kite.tetheredHoverThrust).addDisposableTo(bag)
            phiC.bind(to: kite.phiC).disposed(by: bag)
            thetaC.bind(to: kite.thetaC).disposed(by: bag)
            turningRadius.bind(to: kite.turningRadius).disposed(by: bag)

            // Per kite
            kite.location.map(KiteLocation.getPosition).bind(to: localPositions[index]).disposed(by: bag)
            kite.globalPosition.map(KiteGpsPosition.getPosition).subscribe(onNext: updatePositions(index)).disposed(by: bag)
        }
    }

    public func saveB(kiteIndex: Int) {
        KiteController.kite(kiteIndex).globalPositionB.value = currentGlobalPositions[kiteIndex]
        KiteController.kite(kiteIndex).localPositionB.value = currentLocalPositions[kiteIndex]
    }

    private func updatePositions(_ kiteIndex: Int) -> (GPSVector) -> Void {
        return { [unowned self] global in
            self.currentGlobalPositions[kiteIndex] = global
            self.currentLocalPositions[kiteIndex] = self.localPositions[kiteIndex].value
        }
    }
}

class SettingsViewController: NSViewController {
    private var model: SettingsModel!

    // MARK: - Outlets

    @IBOutlet weak var tetheredHoverThrustSlider: NSSlider!

    @IBOutlet weak var tetherLengthSlider: NSSlider!

    @IBOutlet weak var phiCSlider: NSSlider!
    @IBOutlet weak var thetaCSlider: NSSlider!
    @IBOutlet weak var turningRadiousSlider: NSSlider!

    // Displays
    @IBOutlet weak var errorLabel: NSTextField!

    @IBOutlet weak var position0Label: NSTextField!
    @IBOutlet weak var position1Label: NSTextField!

    @IBOutlet weak var tetherLengthLabel: NSTextField!

    @IBOutlet weak var phiCLabel: NSTextField!
    @IBOutlet weak var thetaCLabel: NSTextField!
    @IBOutlet weak var turningRLabel: NSTextField!

    // MARK: Private

    // MARK: BAG
    private let bag = DisposeBag()
    
    @IBAction func pressedUse0AsB(_ sender: NSButton) {
        model.saveB(kiteIndex: 0)
    }

    @IBAction func pressedUse1AsB(_ sender: NSButton) {
        model.saveB(kiteIndex: 1)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        model = SettingsModel(tetherLengthSlider.scalar, tetheredHoverThrustSlider.scalar, phiCSlider.scalar, thetaCSlider.scalar, turningRadiousSlider.scalar)

        // Controls

        // UI

        tetherLengthSlider.scalar.map(getScalarString).bind(to: tetherLengthLabel.rx.text).disposed(by: bag)

        let positionString = { (p: KiteGpsPosition) in "GPS: \(p.pos.lat), \(p.pos.lon). \(p.pos.alt/1000)" }

        KiteController.kite0.globalPosition.asObservable().map(positionString).bind(to: position0Label.rx.text).disposed(by: bag)
        KiteController.kite1.globalPosition.asObservable().map(positionString).bind(to: position1Label.rx.text).disposed(by: bag)

        phiCSlider.scalar.map(getScalarString).bind(to: phiCLabel.rx.text).disposed(by: bag)
        thetaCSlider.scalar.map(getScalarString).bind(to: thetaCLabel.rx.text).disposed(by: bag)
        turningRadiousSlider.scalar.map(getScalarString).bind(to: turningRLabel.rx.text).disposed(by: bag)

        Observable.merge(KiteController.kite0.errorMessage, KiteController.kite1.errorMessage).bind(to: errorLabel.rx.text).disposed(by: bag)

    }

    @IBAction func selectedOffboardMode(_ sender: NSButton) {
//        let submode = OffboardFlightMode(sender.tag, subNumber: 0)
//        model.kite.flightMode.value = .offboard(subMode: submode)
    }

    @IBAction func togglePosCtr(_ sender: NSButton) {
//        model.kite.offboardPositionTethered.value = !model.kite.offboardPositionTethered.value
    }

    private func getScalarString(scalar: Scalar) -> String {
        return String(format: "%.2f", scalar)
    }
}

