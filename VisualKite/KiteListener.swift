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

    private var targetSystemId: UInt8?
    private var autopilotId: UInt8?
    
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
        if on {
            print("Prepare offboard control")
            
            // TODO: sendOffboardEnabled(on: true) Enable doesn't work before a value has been send
            
            timer = Timer(timeInterval: 0.10, repeats: true) { _ in
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

public typealias MavlinkMessage = mavlink_message_t

extension MavlinkMessage: CustomStringConvertible {
    public var description: String {
        var message = self
        switch msgid {
        case 0:
            var heartbeat = mavlink_heartbeat_t()
            mavlink_msg_heartbeat_decode(&message, &heartbeat);
            return "HEARTBEAT mavlink_version: \(heartbeat.mavlink_version)\n"
        case 1:
            var sys_status = mavlink_sys_status_t()
            mavlink_msg_sys_status_decode(&message, &sys_status)
            return "SYS_STATUS comms drop rate: \(sys_status.drop_rate_comm)%\n"
        case 30:
            var attitude = mavlink_attitude_t()
            mavlink_msg_attitude_decode(&message, &attitude)
            return "ATTITUDE roll: \(attitude.roll) pitch: \(attitude.pitch) yaw: \(attitude.yaw)\n"
        case 32:
            var local_position_ned = mavlink_local_position_ned_t()
            mavlink_msg_local_position_ned_decode(&message, &local_position_ned)
            return "LOCAL POSITION NED x: \(local_position_ned.x) y: \(local_position_ned.y) z: \(local_position_ned.z)\n"
        case 33:
            return "GLOBAL_POSITION_INT\n"
        case 74:
            var vfr_hud = mavlink_vfr_hud_t()
            mavlink_msg_vfr_hud_decode(&message, &vfr_hud)
            return "VFR_HUD heading: \(vfr_hud.heading) degrees\n"
        case 87:
            return "POSITION_TARGET_GLOBAL_INT\n"
        case 105:
            var highres_imu = mavlink_highres_imu_t()
            mavlink_msg_highres_imu_decode(&message, &highres_imu)
            return "HIGHRES_IMU Pressure: \(highres_imu.abs_pressure) millibar\n"
        case 147:
            var battery_status = mavlink_battery_status_t()
            mavlink_msg_battery_status_decode(&message, &battery_status)
            return "BATTERY_STATUS current consumed: \(battery_status.current_consumed) mAh\n"
        default:
            return "OTHER Message id \(message.msgid) received\n"
        }
    }
}

extension MavlinkMessage {
    public static func setPositionTarget(_ sysId: UInt8, _ compId: UInt8, _ tarSysId: UInt8, _ tarCompId: UInt8, x: Float32, y: Float32, z: Float32) -> MavlinkMessage {
        
        var setPositionTarget = mavlink_set_position_target_local_ned_t()
        
        //        time_boot_ms    uint32_t    Timestamp in milliseconds since system boot
        //        target_system    uint8_t    System ID
        //        target_component    uint8_t    Component ID
        //        coordinate_frame    uint8_t    Valid options are: MAV_FRAME_LOCAL_NED = 1, MAV_FRAME_LOCAL_OFFSET_NED = 7, MAV_FRAME_BODY_NED = 8, MAV_FRAME_BODY_OFFSET_NED = 9
        //        type_mask    uint16_t    Bitmask to indicate which dimensions should be ignored by the vehicle: a value of 0b0000000000000000 or 0b0000001000000000 indicates that none of the setpoint dimensions should be ignored. If bit 10 is set the floats afx afy afz should be interpreted as force instead of acceleration. Mapping: bit 1: x, bit 2: y, bit 3: z, bit 4: vx, bit 5: vy, bit 6: vz, bit 7: ax, bit 8: ay, bit 9: az, bit 10: is force setpoint, bit 11: yaw, bit 12: yaw rate
        //        x    float    X Position in NED frame in meters
        //        y    float    Y Position in NED frame in meters
        //        z    float    Z Position in NED frame in meters (note, altitude is negative in NED)
        //        vx    float    X velocity in NED frame in meter / s
        //        vy    float    Y velocity in NED frame in meter / s
        //        vz    float    Z velocity in NED frame in meter / s
        //        afx    float    X acceleration or force (if bit 10 of type_mask is set) in NED frame in meter / s^2 or N
        //        afy    float    Y acceleration or force (if bit 10 of type_mask is set) in NED frame in meter / s^2 or N
        //        afz    float    Z acceleration or force (if bit 10 of type_mask is set) in NED frame in meter / s^2 or N
        //        yaw    float    yaw setpoint in rad
        //        yaw_rate    float    yaw rate setpoint in rad/s
        
        /**
         * Defines for mavlink_set_position_target_local_ned_t.type_mask
         *
         * Bitmask to indicate which dimensions should be ignored by the vehicle
         *
         * a value of 0b0000000000000000 or 0b0000001000000000 indicates that none of
         * the setpoint dimensions should be ignored.
         *
         * If bit 10 is set the floats afx afy afz should be interpreted as force
         * instead of acceleration.
         *
         * Mapping:
         * bit 1: x,
         * bit 2: y,
         * bit 3: z,
         * bit 4: vx,
         * bit 5: vy,
         * bit 6: vz,
         * bit 7: ax,
         * bit 8: ay,
         * bit 9: az,
         * bit 10: is force setpoint,
         * bit 11: yaw,
         * bit 12: yaw rate
         * remaining bits unused
         *
         * Combine bitmasks with bitwise &
         *
         * Example for position and yaw angle:
         * uint16_t type_mask =
         *     MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_POSITION &
         *     MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_YAW_ANGLE;
         */
        
        // bit number  876543210987654321
        let MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_POSITION      : UInt16 = 0b0000110111111000
        //        let MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_VELOCITY      : UInt16 = 0b0000110111000111
        //        let MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_ACCELERATION  : UInt16 = 0b0000110000111111
        //        let MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_FORCE         : UInt16 = 0b0000111000111111
        //        let MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_YAW_ANGLE     : UInt16 = 0b0000100111111111
        //        let MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_YAW_RATE      : UInt16 = 0b0000010111111111
        //
        setPositionTarget.time_boot_ms = UInt32(ProcessInfo.processInfo.systemUptime * 1000)
        setPositionTarget.type_mask = MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_POSITION // Bitmask should work for now.
        setPositionTarget.coordinate_frame = UInt8(MAV_FRAME_LOCAL_NED.rawValue)
        
        setPositionTarget.x = x
        setPositionTarget.y = y
        setPositionTarget.z = z
        
        
        setPositionTarget.target_component = tarCompId
        setPositionTarget.target_system = tarSysId
        
        var msg = mavlink_message_t()
        mavlink_msg_set_position_target_local_ned_encode(sysId, compId, &msg, &setPositionTarget)
        
        return msg
    }
    
    public static func toggleOffboard(_ sysId: UInt8, _ compId: UInt8, _ tarSysId: UInt8, _ tarCompId: UInt8, on: Bool) -> MavlinkMessage {
        var com = mavlink_command_long_t()
        com.target_system = tarSysId
        com.target_component = tarCompId // This seems right
        com.command = UInt16(MAV_CMD_NAV_GUIDED_ENABLE.rawValue)
        com.confirmation = UInt8(true)
        com.param1 = on ? 1 : 0 // // flag >0.5 => start, <0.5 => stop
        
        var message = mavlink_message_t()
        mavlink_msg_command_long_encode(sysId, compId, &message, &com);

        return message
    }
    
    public static func setAttitudeTarget(_ sysId: UInt8, _ compId: UInt8, _ tarSysId: UInt8, _ tarCompId: UInt8, thrust: Float32) -> MavlinkMessage {
        
        var setAttitudeTarget = mavlink_set_attitude_target_t()
        
        //        time_boot_ms          uint32_t	Timestamp in milliseconds since system boot
        //        target_system         uint8_t     System ID
        //        target_component      uint8_t     Component ID
        //        type_mask             uint8_t     Mappings: If any of these bits are set, the corresponding input should be ignored: bit 1: body roll rate, bit 2: body pitch rate, bit 3: body yaw rate. bit 4-bit 6: reserved, bit 7: throttle, bit 8: attitude
        //        q	float[4]	Attitude quaternion (w, x, y, z order, zero-rotation is 1, 0, 0, 0)
        //        body_roll_rate        float       Body roll rate in radians per second
        //        body_pitch_rate       float       Body roll rate in radians per second
        //        body_yaw_rate         float       Body roll rate in radians per second
        //        thrust                float       Collective thrust, normalized to 0 .. 1 (-1 .. 1 for vehicles capable of reverse trust)
        
        
        setAttitudeTarget.time_boot_ms = UInt32(ProcessInfo.processInfo.systemUptime * 1000)
        setAttitudeTarget.type_mask = UInt8(0) // Bitmask should work for now.
        
        setAttitudeTarget.q = (1, 0, 0, 0)
        
        setAttitudeTarget.body_roll_rate = 0
        setAttitudeTarget.body_pitch_rate = 0
        setAttitudeTarget.body_yaw_rate = 0
        
        setAttitudeTarget.thrust = thrust
        
        setAttitudeTarget.target_component = tarCompId
        setAttitudeTarget.target_system = tarSysId
        
        var msg = mavlink_message_t()
        
        mavlink_msg_set_attitude_target_encode(sysId, compId, &msg, &setAttitudeTarget)
        
        return msg
    }

    var localNEDDataPoint: KiteLocation? {
        guard msgid == 32 else {
            return nil
        }
        
        var message = self
        
        var local_position_ned = mavlink_local_position_ned_t()
        mavlink_msg_local_position_ned_decode(&message, &local_position_ned)
        
        let time = Double(local_position_ned.time_boot_ms)
        let pos = Vector(local_position_ned.x, local_position_ned.y, local_position_ned.z)
        let vel = Vector(local_position_ned.vx, local_position_ned.vy, local_position_ned.vz)
        
        return KiteLocation(time: time, pos: pos, vel: vel)
    }
    
    var data: Data {
        let buffer = Data(count: 300) // 300 from mavlink example c_uart_interface_example
        
        return buffer.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) -> Data in
            let mutablePointer  = UnsafeMutablePointer(mutating: u8Ptr)
            
            var mySelf = self
            let length = mavlink_msg_to_send_buffer(mutablePointer, &mySelf)
            
            return buffer.subdata(in: 0..<Int(length) )
        }
    }
}

