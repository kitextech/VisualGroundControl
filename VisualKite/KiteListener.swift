//
//  KiteListener.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-10.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import Mavlink
import ORSSerial
import RxSwift

struct KiteLocation {
    let time: TimeInterval
    let pos: Vector
    let vel: Vector
}

class KiteLink: NSObject {
    public let thrust = Variable<Float>(0)
    public let mavlinkMessage = PublishSubject<String>()
    public let location = PublishSubject<KiteLocation>()
    
    public var isSerialPortOpen: Bool { return serialPort?.isOpen ?? false }

    public let isOffboard = Variable<Bool>(false)

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

    private let systemId: UInt8 = 255
    private let compId: UInt8 = 0
    
    // MARK: Mavlink Ids

    var targetSystemId: UInt8?
    var autopilotId: UInt8?
    
    // MARK: Mavlink Misc

    private var timer: Timer?
    private var count: Int = 0
    
    private let bag = DisposeBag()
    
    // MARK: Initializers
    
    override private init() {
        super.init()
        
        isOffboard.asObservable().bindNext(toggleOffBoard).disposed(by: bag)
        
        let center = NotificationCenter.default
        
        center.addObserver(self, selector: #selector(serialPortsWereConnected), name: .ORSSerialPortsWereConnected, object: nil)
        center.addObserver(self, selector: #selector(serialPortsWereDisconnected), name: .ORSSerialPortsWereDisconnected, object: nil)
        
        NSUserNotificationCenter.default.delegate = self
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

    // MARK: Private Methods
    
    private func toggleOffBoard(on: Bool) {
        print("Prepare offboard control: \(on)")

        if on {
            // TODO: sendOffboardEnabled(on: true) Enable doesn't work before a value has been send
            
            timer = Timer(timeInterval: 0.10, repeats: true) { _ in
                print("Thrust \(self.thrust.value)")
                
                print("Thrust \(self.thrust.value)")

                if let serialPort = self.serialPort, let targetSystemId = self.targetSystemId, let targetComponentId = self.autopilotId {
                    
                    let msg = MavlinkMessage.setAttitudeTarget(self.systemId, self.compId, targetSystemId, targetComponentId, thrust: self.thrust.value)
                    
                    serialPort.send(msg.data)
                }
            }
            
            guard let timer = timer else {
                return
            }
            
            RunLoop.main.add(timer, forMode: .commonModes)
        }
        else {
            timer?.invalidate()
            sendOffboardEnabled(on: false)
        }
    }

    // MARK: - Private Methods

    private func sendOffboardEnabled(on: Bool) {
        if let serialPort = serialPort, let targetSystemId = targetSystemId, let autopilotId = autopilotId {
            var com = mavlink_command_long_t()
            com.target_system = targetSystemId
            com.target_component = autopilotId // This seems right
            com.command = UInt16(MAV_CMD_NAV_GUIDED_ENABLE.rawValue)
            com.confirmation = UInt8(true)
            com.param1 = on ? 1 : 0 // // flag >0.5 => start, <0.5 => stop
            
            var message = mavlink_message_t()
            mavlink_msg_command_long_encode(systemId, compId, &message, &com);
            
            serialPort.send(message.data)
            
            print("sendOffboardEnabled: \(on)")
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
            if mavlink_parse_char(channel, byte, &message, &status) != 0 {
                
                targetSystemId = message.sysid // Only handles one drone
                autopilotId = message.compid

                if let point = message.localNEDDataPoint {
                    location.onNext(point)
                }
                
                mavlinkMessage.onNext(message.description)
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

