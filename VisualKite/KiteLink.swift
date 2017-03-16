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
}

enum FlightMode {
    case manual(subMode: ManualFlightMode)
    case offboard(subMode: OffboardFlightMode)
}

enum ManualFlightMode {
    case normal
    case tethered
}

enum OffboardFlightMode {
    case position(subMode: OffboardPositionFlightMode)
    case attitude
    case looping
}

enum OffboardPositionFlightMode {
    case normal
    case tethered
}

class KiteLink: NSObject {
    public var flightMode: FlightMode = .manual(subMode: .normal)

    public let isOffboard = Variable<Bool>(false)

    // MARK: Parameters
    
    public let positionB = Variable<Vector>(.zero) // Offboard
    public let tetherLength = Variable<Scalar>(100) // Offboard
    
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
    public let attitude = PublishSubject<KiteAttitude>()
    public let quaternion = PublishSubject<KiteQuaternion>()
    
    public var isSerialPortOpen: Bool { return serialPort?.isOpen ?? false }

    // MARK: Singleton

    public static let shared = KiteLink()
    
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

    internal let systemId: UInt8 = 255
    internal let compId: UInt8 = 0
    
    // MARK: Mavlink Ids

    internal var targetSystemId: UInt8?
    internal var autopilotId: UInt8?
    
    // MARK: Mavlink Misc

    internal var box: MessageBox?
    private var timer: Timer?
    private var count: Int = 0
    
    // MARK: Private Variables

    private let bag = DisposeBag()

    private var unsentMessages = [MavlinkMessage]()

    // MARK: Initializers
    
    private override init() {
        super.init()
        
        isOffboard.asObservable().bindNext(toggleOffBoard).disposed(by: bag)
        
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(serialPortsWereConnected), name: .ORSSerialPortsWereConnected, object: nil)
        center.addObserver(self, selector: #selector(serialPortsWereDisconnected), name: .ORSSerialPortsWereDisconnected, object: nil)
        
        NSUserNotificationCenter.default.delegate = self
        
        bind(positionB, with: setVector(ids: (MPC_X_POS_B, MPC_Y_POS_B, MPC_Z_POS_B)))
        bind(tetherLength, with: setScalar(id: MPC_TETHER_LEN))
        bind(hoverPitchAngle, with: setScalar(id: MPC_PITCH_HVR))
        bind(tetheredHoverThrust, with: setScalar(id: MPC_THR_TETHER))
        
        bind(offboardPositionTethered, with: setBool(id: MPC_TET_POS_CTL))
        
//        bind(phiC, with: setScalar(id: MPC_LOOP_PHI_C))
//        bind(thetaC, with: setScalar(id: MPC_LOOP_THETA_C))
//        bind(turningRadius, with: setScalar(id: MPC_LOOP_TURN_R))
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: Public Methods

    public func togglePort() {
        guard let port = serialPort else {
            return
        }
        
        if port.isOpen {
            port.close()
        }
        else {
            port.open()
            startUsbMavlinkSession() // TODO: Maybe depend on USB vs Telemetry
        }
    }

    public func requestParameterList() {
        
        guard let data = box?.requestParamList().data else {
            return
        }
        
        serialPort?.send(data)
    }
    
    // MARK: Private Methods
    
    private func toggleOffBoard(on: Bool) {
        print("Prepare offboard control: \(on)")
        
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
    
    private func heartbeat(timer: Timer) {
        guard let box = box else { return }
    
        unsentMessages.forEach(send)
        unsentMessages.removeAll()
        
        switch flightMode {
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
    
    private func bind<T: Equatable>(_ variable: Variable<T>, with function: @escaping (T) -> [MavlinkMessage]) {
        variable.asObservable()
            .distinctUntilChanged()
            .map(function)
            .bindNext(push)
            .disposed(by: bag)
    }
    
    private func push(_ messages: [MavlinkMessage]) {
        unsentMessages.append(contentsOf: messages)
    }
    
    private func setBool(id: String) -> (Bool) -> [MavlinkMessage] {
        return { bool in
            guard let box = self.box else { return [] }
            
            return [box.setParameter(id: id, value: bool ? 1 : 0, type: MAV_PARAM_TYPE_INT32)]
        }
    }
    
    private func setScalar(id: String) -> (Scalar) -> [MavlinkMessage] {
        return { value in
            guard let box = self.box else { return [] }
            
            return [box.setParameter(id: id, value: Float(value), type: MAV_PARAM_TYPE_REAL32)]
        }
    }
    
    private func setVector(ids: (String, String, String)) -> (Vector) -> [MavlinkMessage] {
        return { vector in
            guard let box = self.box else { return [] }
            
            return [box.setParameter(id: ids.0, value: Float(vector.x), type: MAV_PARAM_TYPE_REAL32),
                    box.setParameter(id: ids.1, value: Float(vector.y), type: MAV_PARAM_TYPE_REAL32),
                    box.setParameter(id: ids.2, value: Float(vector.z), type: MAV_PARAM_TYPE_REAL32)]
        }
    }

    // MARK: - Private Methods

    private func send(_ message: MavlinkMessage) {
        guard let serialPort = serialPort else { return }

        print("Sending message: \(message)")
        
        serialPort.send(message.data)
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
            if mavlink_parse_char(channel, byte, &message, &status) != 0 {
                targetSystemId = message.sysid // Only handles one drone
                autopilotId = message.compid

                if let loc = message.location {
                    location.onNext(loc)
                }
                
                if let att = message.attitude {
                    attitude.onNext(att)
                }
                
                if let q = message.quaternion {
                    quaternion.onNext(q)
                }
                
                mavlinkMessage.onNext(message)
            }
        }
        
        if box == nil, let targetSystemId = targetSystemId, let autopilotId = autopilotId {
            box = MessageBox(sysId: systemId, compId: compId, tarSysId: targetSystemId, tarCompId: autopilotId)
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

