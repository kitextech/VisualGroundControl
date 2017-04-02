//
//  KiteLink.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-10.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import Mavlink
import ORSSerial
import RxSwift

let MPC_PITCH_HVR = "MPC_PITCH_HVR"
let MPC_TET_POS_CTL = "MPC_TET_POS_CTL"
let MPC_THR_TETHER = "MPC_THR_TETHER"

let MPC_TETHER_LEN = "MPC_TETHER_LEN"

let MPC_X_POS_B = "MPC_X_POS_B"
let MPC_Y_POS_B = "MPC_Y_POS_B"
let MPC_Z_POS_B = "MPC_Z_POS_B"

// TODO: Add in C++
let MPC_LOOP_PHI_C = "MPC_LOOP_PHI_C"
let MPC_LOOP_THETA_C = "MPC_LOOP_THETA_C"
let MPC_LOOP_TURN_R = "MPC_LOOP_TURN_R"

struct KiteLocation {
    let time: TimeInterval
    let pos: Vector
    let vel: Vector
    
    init(time: TimeInterval = 0, pos: Vector = .zero, vel: Vector = .zero) {
        self.time = time
        self.pos = pos
        self.vel = vel
    }

    static func getPosition(kiteLocation: KiteLocation) -> Vector {
        return kiteLocation.pos
    }

    static func getVelocity(kiteLocation: KiteLocation) -> Vector {
        return kiteLocation.vel
    }
}

struct KiteAttitude {
    let time: TimeInterval
    let att: Vector
    let rate: Vector
    
    init(time: TimeInterval = 0, att: Vector = .zero, rate: Vector = .zero) {
        self.time = time
        self.att = att
        self.rate = rate
    }

    static func getAttitude(kiteAttitude: KiteAttitude) -> Vector {
        return kiteAttitude.att
    }
}

struct KiteQuaternion {
    let time: TimeInterval
    let quaternion: Quaternion
    let rate: Vector

    init(time: TimeInterval = 0, quaternion: Quaternion = .id, rate: Vector = .zero) {
        self.time = time
        self.quaternion = quaternion
        self.rate = rate
    }

    static func getQuaternion(kiteQuaternion: KiteQuaternion) -> Quaternion {
        return kiteQuaternion.quaternion
    }
}

public let systemId: UInt8 = 255
public let compId: UInt8 = 0

struct ParameterValue {
    let id: String
    let value: Scalar
    let type: MAV_PARAM_TYPE

    init(id: String, value: Scalar, type: MAV_PARAM_TYPE = MAV_PARAM_TYPE_REAL32) {
        self.id = id
        self.value = value
        self.type = type
    }
}

class KiteLink: NSObject {
    public let flightMode: Variable<FlightMode> = Variable(.offboard(subMode: .position(subMode: .normal)))

    public let isOffboard = Variable<Bool>(true)

    // MARK: Parameters
    
    public let positionB = Variable<Vector>(.zero) // Offboard
    public let tetherLength = Variable<Scalar>(50) // Offboard
    
    public let offboardPositionTethered = Variable<Bool>(true) // Offboard>Position

    public let hoverPitchAngle = Variable<Scalar>(0.174) // Manual>Tethered
    public let tetheredHoverThrust = Variable<Scalar>(0.174) // Offboard>Position>Tethered
    
    public let phiC = Variable<Scalar>(0) // Offboard>Looping
    public let thetaC = Variable<Scalar>(0) // Offboard>Looping
    public let turningRadius = Variable<Scalar>(0) // Offboard>Looping
    
    // MARK: - Continuous Parameters
    
    public let positionTarget = Variable<Vector>(.zero) // Offboard>Position
    
    public let attitudeTarget = Variable<Quaternion>(.id) // Offboard>Attitude
    public let thrust = Variable<Scalar>(0) // Offboard>Attitude

    // MARK: Output

    public let mavlinkMessage = PublishSubject<MavlinkMessage>()
    
    public let location = PublishSubject<KiteLocation>()
    public let quaternion = PublishSubject<KiteQuaternion>()
    public let attitude = PublishSubject<KiteAttitude>()

    public let errorMessage = PublishSubject<String>()

    public var isSerialPortOpen: Bool { return serialPort?.isOpen ?? false }

    // MARK: Singleton

    public static let shared = KiteLink(targetSystemId: 1, targetComponentId: 1)
    
    // MARK: Serial Port Properties

    public let serialPortManager = ORSSerialPortManager.shared()

    public var serialPort: ORSSerialPort? {
        didSet {
            oldValue?.close()
            oldValue?.delegate = nil
            serialPort?.delegate = self
            serialPort?.baudRate = 57600
            serialPort?.numberOfStopBits = 1
            serialPort?.parity = .none
        }
    }
    
    // MARK: Local Mavlink Ids

    // MARK: Mavlink Ids

    // MARK: Mavlink Misc

    internal let box: MessageBox
    private var timer: Timer?
    private var count: Int = 0
    
    // MARK: Private Variables

    private let bag = DisposeBag()

    internal var unsentParameterValues = [String : ParameterValue]()
    internal var unconfirmedParameterValues = [String : (ParameterValue, Date, Int)]()

    private let parameterGracePeriod: TimeInterval = 1
    private let parameterRetries = 10

    // MARK: Initializers
    
    private init(targetSystemId: UInt8, targetComponentId: UInt8) {
        box = MessageBox(sysId: systemId, compId: compId, tarSysId: targetSystemId, tarCompId: targetComponentId)
        super.init()

        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(serialPortsWereConnected), name: .ORSSerialPortsWereConnected, object: nil)
        center.addObserver(self, selector: #selector(serialPortsWereDisconnected), name: .ORSSerialPortsWereDisconnected, object: nil)
        
        NSUserNotificationCenter.default.delegate = self
        
        bind(positionB, using: setVector(ids: (MPC_X_POS_B, MPC_Y_POS_B, MPC_Z_POS_B)))
        bind(tetherLength, using: setScalar(id: MPC_TETHER_LEN))
        bind(hoverPitchAngle, using: setScalar(id: MPC_PITCH_HVR))
        bind(tetheredHoverThrust, using: setScalar(id: MPC_THR_TETHER))
        bind(offboardPositionTethered, using: setBool(id: MPC_TET_POS_CTL))

        flightMode.asObservable().bindNext(changedFlightMode).disposed(by: bag)

//        bind(phiC, with: setScalar(id: MPC_LOOP_PHI_C))
//        bind(thetaC, with: setScalar(id: MPC_LOOP_THETA_C))
//        bind(turningRadius, with: setScalar(id: MPC_LOOP_TURN_R))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: Public Methods

    public func togglePort() {
        guard let serialPort = serialPort else {
            return
        }
        
        if serialPort.isOpen {
            serialPort.close()
        }
        else {
            serialPort.open()
            startUsbMavlinkSession() // TODO: Maybe depend on USB vs Telemetry
        }
    }

    public func requestParameterList() {
        send(box.requestParamList())
    }

    // MARK: Private Methods

    private func heartbeat(timer: Timer) {
        let now = Date()
        unconfirmedParameterValues.values.forEach { value, sentDate, retries in
            if now.timeIntervalSince(sentDate) > Double(retries + 1)*parameterGracePeriod {
                if retries < parameterRetries {
                    print("Retrying (\(retries + 1)) retries for \(value.id) value: \(value.value)")
                    send(box.setParameter(value: value))
                    unconfirmedParameterValues[value.id] = (value, sentDate, retries + 1)
                }
                else {
                    errorMessage.onNext("too many (\(retries)) retries for \(value.id)")
                    unconfirmedParameterValues[value.id] = nil
                }
            }
        }

        unsentParameterValues.forEach { key, value in
            send(box.setParameter(value: value))
            unconfirmedParameterValues[key] = (value, now, 0)
        }

        unsentParameterValues.removeAll()

        switch flightMode.value {
        case .manual:
            break

        case .offboard(subMode: let secondary):
            switch secondary {
            case .attitude:
                send(box.setAttitudeTarget(quaternion: attitudeTarget.value, thrust: thrust.value))
            case .position:
                send(box.setPositionTarget(vector: positionTarget.value))
            case .looping:
                break
            }
        }
    }

    // MARK: - Helper Methods for Linking Rx and Mavlink Parameter Messages

    private func bind<T: Equatable>(_ variable: Variable<T>, using function: @escaping (T) -> [ParameterValue]) {
        variable.asObservable()
            .distinctUntilChanged()
            .map(function)
            .bindNext(push)
            .disposed(by: bag)
    }

    private func push(_ values: [ParameterValue]) {
        values.forEach {
            unsentParameterValues[$0.id] = $0
            unconfirmedParameterValues[$0.id] = nil
        }
    }

    private func setBool(id: String) -> (Bool) -> [ParameterValue] {
        return { bool in
            return [ParameterValue(id: id, value: bool ? 1 : 0)]
        }
    }

    private func setScalar(id: String) -> (Scalar) -> [ParameterValue] {
        return { value in
            return [ParameterValue(id: id, value: value)]
        }
    }

    private func setVector(ids: (String, String, String)) -> (Vector) -> [ParameterValue] {
        return { v in
            return [ParameterValue(id: ids.0, value: v.x),
                    ParameterValue(id: ids.1, value: v.y),
                    ParameterValue(id: ids.2, value: v.z)]
        }
    }

    internal func confirm(_ p: ParameterValue) {
        func isCloseEnough(actual: Scalar, received: Scalar) -> Bool {
            let relativeError: Scalar = 1/10000
            let absoluteError: Scalar = 1/100000
            return abs(actual - received) < relativeError*abs(actual) + absoluteError
        }

        if let unconfirmed = unconfirmedParameterValues[p.id]?.0, unconfirmed.type == p.type, isCloseEnough(actual: unconfirmed.value, received: p.value) {
            unconfirmedParameterValues[p.id] = nil
            print("Confirmed \(p.id) : \(p.value)")
        }
    }

    private func changedFlightMode(mode: FlightMode) {
        print("Changed to: \(mode)")

        if case FlightMode.offboard = mode {
            toggleOffBoard(on: true)
        }
        else {
            toggleOffBoard(on: false)
        }
    }

    private func toggleOffBoard(on: Bool) {
        if on {
            // TODO: sendOffboardEnabled(on: true) Enable doesn't work before a value has been send
            
            let heartbeatTimer = Timer(timeInterval: 0.10, repeats: true, block: heartbeat)
            RunLoop.main.add(heartbeatTimer, forMode: .commonModes)
            timer = heartbeatTimer
        }
        else {
            timer?.invalidate()
            
//            guard let message = box?.setOffboardEnabled(on: false) else { return }
//            send(message)
        }
    }

    // MARK: - Private Methods

    private func send(_ message: MavlinkMessage) {
        guard let serialPort = serialPort else { return }

        serialPort.send(message.data)

        if message.msgid != 84 {
            print("SEND: \(message)")
        }
    }
    
    // MARK: - Notifications
    
    @objc func serialPortsWereConnected(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let connectedPorts = userInfo[ORSConnectedSerialPortsKey] as! [ORSSerialPort]
            print("Ports were connected: \(connectedPorts)")
            postUserNotificationForConnectedPorts(connectedPorts)
        }
    }
    
    @objc func serialPortsWereDisconnected(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            let disconnectedPorts: [ORSSerialPort] = userInfo[ORSDisconnectedSerialPortsKey] as! [ORSSerialPort]
            print("Ports were disconnected: \(disconnectedPorts)")
            postUserNotificationForDisconnectedPorts(disconnectedPorts)
        }
    }
    
    func postUserNotificationForConnectedPorts(_ connectedPorts: [ORSSerialPort]) {
        let center = NSUserNotificationCenter.default
        for port in connectedPorts {
            let userNote = NSUserNotification()
            userNote.title = NSLocalizedString("Serial Port Connected", comment: "Serial Port Connected")
            userNote.informativeText = "Serial Port \(port.name) was connected to your Mac."
            userNote.soundName = nil
            center.deliver(userNote)
        }
    }
    
    func postUserNotificationForDisconnectedPorts(_ disconnectedPorts: [ORSSerialPort]) {
        let center = NSUserNotificationCenter.default
        for port in disconnectedPorts {
            let userNote = NSUserNotification()
            userNote.title = NSLocalizedString("Serial Port Disconnected", comment: "Serial Port Disconnected")
            userNote.informativeText = "Serial Port \(port.name) was disconnected from your Mac."
            userNote.soundName = nil;
            center.deliver(userNote)
        }
    }
    
    // MARK: Private Methods

    private func startUsbMavlinkSession() {
        guard let port = serialPort, port.isOpen else {
            print("Serial port is not open")
            return
        }
        
        guard let data = "mavlink start -d /dev/ttyACM0\n".data(using: .utf32LittleEndian) else {
            print("Cannot create mavlink USB start command")
            return
        }
        
        port.send(data)
    }
}

extension KiteLink: ORSSerialPortDelegate {
    func serialPortWasOpened(_ serialPort: ORSSerialPort) {
        print("Serial port was opened: \(serialPort.name)")
    }
    
    func serialPortWasClosed(_ serialPort: ORSSerialPort) {
        print("Serial port was closed: \(serialPort.name)")
    }
    
    /**
     *  Called when a serial port is removed from the system, e.g. the user unplugs
     *  the USB to serial adapter for the port.
     *
     *	In this method, you should discard any strong references you have maintained for the
     *  passed in `serialPort` object. The behavior of `ORSSerialPort` instances whose underlying
     *  serial port has been removed from the system is undefined.
     *
     *  @param serialPort The `ORSSerialPort` instance representing the port that was removed.
     */
    public func serialPortWasRemovedFromSystem(_ serialPort: ORSSerialPort) {
        print("Serial port was removed: \(serialPort.name)")
        self.serialPort = nil
    }

    func serialPort(_ serialPort: ORSSerialPort, didReceive data: Data) {
        var bytes = [UInt8](repeating: 0, count: data.count)
        (data as NSData).getBytes(&bytes, length: data.count)

        for byte in bytes {
            var message = mavlink_message_t()
            var status = mavlink_status_t()
            let channel = UInt8(MAVLINK_COMM_1.rawValue)

            let parse = mavlink_parse_char(channel, byte, &message, &status)
            if parse != 0 {
                guard message.sysid == box.tarSysId && message.compid == box.tarCompId else { return }

                if let loc = message.location {
                    location.onNext(loc)
                }

                if let att = message.attitude {
                    attitude.onNext(att)
                }

                if let q = message.quaternion {
                    quaternion.onNext(q)
                }

                if let value = message.parameterValue {
                    print("Received Parameter: \(value.id) (\(value.id.characters.count)) = \(value.value)")

                    confirm(value)
                }

                mavlinkMessage.onNext(message)
            }
        }
    }

    func serialPort(_ serialPort: ORSSerialPort, didEncounterError error: Error) {
        print("SerialPort \(serialPort.name) encountered an error: \(error)")
    }
}

extension KiteLink: NSUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        let popTime = DispatchTime.now() + Double(Int64(3.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.asyncAfter(deadline: popTime) {
            center.removeDeliveredNotification(notification)
        }
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
}

enum FlightMode: CustomStringConvertible {
    case manual(subMode: ManualFlightMode)
    case offboard(subMode: OffboardFlightMode)

    public var description: String {
        let result = "FlightMode."
        switch self {
        case .manual(subMode: let manualMode): return result + manualMode.description
        case .offboard(subMode: let offboardMode): return result + offboardMode.description
        }
    }
}

enum ManualFlightMode: CustomStringConvertible {
    case normal
    case tethered

    public var description: String {
        let result = "manual."
        switch self {
        case .normal: return result + "normal"
        case .tethered: return result + "tethered"
        }
    }
}

enum OffboardFlightMode: CustomStringConvertible {
    case position(subMode: OffboardPositionFlightMode)
    case attitude
    case looping

    init(_ number: Int, subNumber: Int?) {
        let all: [OffboardFlightMode] = [.position(subMode: OffboardPositionFlightMode(subNumber!)), .attitude, .looping]
        self = all[number]
    }

    public var description: String {
        let result = "offboard."

        switch self {
        case .position(subMode: let positionMode): return result + positionMode.description
        case .attitude: return result + "attitude"
        case .looping: return result + "looping"
        }
    }

    enum OffboardPositionFlightMode: CustomStringConvertible {
        case normal
        case tethered

        init(_ number: Int) {
            let all: [OffboardPositionFlightMode] = [.normal, .tethered]
            self = all[number]
        }

        public var description: String {
            let result = "position."

            switch self {
            case .normal: return result + "normal"
            case .tethered: return result + "tethered"
            }
        }
    }
}

