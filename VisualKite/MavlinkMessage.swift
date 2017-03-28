//
//  MavlinkMessage.swift
//  VisualKite
//
//  Created by Gustaf Kugelberg on 2017-03-14.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation
import Mavlink

struct MessageBox {
    public let sysId: UInt8
    public let compId: UInt8
    public let tarSysId: UInt8
    public let tarCompId: UInt8
    
    public func setOffboardEnabled(on: Bool) -> MavlinkMessage {
        var com = mavlink_command_long_t()
        com.target_system = tarSysId
        com.target_component = tarCompId
        com.command = UInt16(MAV_CMD_NAV_GUIDED_ENABLE.rawValue)
        com.confirmation = UInt8(true)
        com.param1 = on ? 1 : 0 // // flag >0.5 => start, <0.5 => stop
        
        var message = mavlink_message_t()
        mavlink_msg_command_long_encode(sysId, compId, &message, &com);
        
        return message
    }

    public func setPositionTarget(vector: Vector) -> MavlinkMessage {
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
        setPositionTarget.time_boot_ms = UInt32(ProcessInfo.processInfo.systemUptime*1000)
        setPositionTarget.type_mask = MAVLINK_MSG_SET_POSITION_TARGET_LOCAL_NED_POSITION // Bitmask should work for now.
        setPositionTarget.coordinate_frame = UInt8(MAV_FRAME_LOCAL_NED.rawValue)
        
        setPositionTarget.x = Float32(vector.x)
        setPositionTarget.y = Float32(vector.y)
        setPositionTarget.z = Float32(vector.z)
        
        setPositionTarget.target_component = tarCompId
        setPositionTarget.target_system = tarSysId
        
        var msg = mavlink_message_t()
        mavlink_msg_set_position_target_local_ned_encode(sysId, compId, &msg, &setPositionTarget)
        
        return msg
    }
    
    public func setAttitudeTarget(quaternion q: Quaternion, thrust: Scalar) -> MavlinkMessage {
        var setAttitudeTarget = mavlink_set_attitude_target_t()
        
        //        type_mask             uint8_t     Mappings: If any of these bits are set, the corresponding input should be ignored: bit 1: body roll rate, bit 2: body pitch rate, bit 3: body yaw rate. bit 4-bit 6: reserved, bit 7: throttle, bit 8: attitude
        //        q	float[4]	Attitude quaternion (w, x, y, z order, zero-rotation is 1, 0, 0, 0)
        //        body_roll_rate        float       Body roll rate in radians per second
        //        body_pitch_rate       float       Body roll rate in radians per second
        //        body_yaw_rate         float       Body roll rate in radians per second
        //        thrust                float       Collective thrust, normalized to 0 .. 1 (-1 .. 1 for vehicles capable of reverse trust)
        
        
        setAttitudeTarget.time_boot_ms = UInt32(ProcessInfo.processInfo.systemUptime*1000)
        setAttitudeTarget.type_mask = 0 // Bitmask should work for now.
        
        setAttitudeTarget.q = (Float(q.w), Float(q.x), Float(q.y), Float(q.z))
        
        setAttitudeTarget.body_roll_rate = 0
        setAttitudeTarget.body_pitch_rate = 0
        setAttitudeTarget.body_yaw_rate = 0
        
        setAttitudeTarget.thrust = Float32(thrust)
        
        setAttitudeTarget.target_component = tarCompId
        setAttitudeTarget.target_system = tarSysId
        
        var msg = mavlink_message_t()
        
        mavlink_msg_set_attitude_target_encode(sysId, compId, &msg, &setAttitudeTarget)
        
        return msg
    }
    
    public func requestParamList() -> MavlinkMessage {
        var parameterRequestList = mavlink_param_request_list_t()
        parameterRequestList.target_component = tarCompId
        parameterRequestList.target_system = tarSysId
        
        var msg = mavlink_message_t()
        
        mavlink_msg_param_request_list_encode(sysId, compId, &msg, &parameterRequestList)
        
        return msg
    }
    
    public func setParameter(id: String, value: Float, type: MAV_PARAM_TYPE) -> MavlinkMessage {
        var paramSet = mavlink_param_set_t()
        paramSet.target_component = tarCompId
        paramSet.target_system = tarSysId
        
        paramSet.param_id = id.paramId
        paramSet.param_value = value
        paramSet.param_type = UInt8(type.rawValue)
        
        var msg = mavlink_message_t()
        
        mavlink_msg_param_set_encode(sysId, compId, &msg, &paramSet)
        
        return msg
    }
}

extension String {
    var paramId: ParamId {
        let a = unicodeScalars.filter { $0.isASCII }.map { Int8($0.value) } + Array(repeating: 0, count: 16)
        return (a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11], a[12], a[13], a[14], a[15])
    }
    
    init(paramId p: ParamId) {
        let array = [p.0, p.1, p.2, p.3, p.4, p.5, p.6, p.7, p.8, p.9, p.10, p.11, p.12, p.13, p.14, p.15]
        self = String(array.map { Character(UnicodeScalar(UInt8($0))) })
    }
}

public typealias ParamId = (Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8, Int8)

public typealias MavlinkMessage = mavlink_message_t

extension MavlinkMessage: CustomStringConvertible {
    public var description: String {
        var message = self
        switch msgid {
        case 0:
            var heartbeat = mavlink_heartbeat_t()
            mavlink_msg_heartbeat_decode(&message, &heartbeat);
            return "HEARTBEAT mavlink_version: \(heartbeat.mavlink_version)"
        case 1:
            var sys_status = mavlink_sys_status_t()
            mavlink_msg_sys_status_decode(&message, &sys_status)
            return "SYS_STATUS comms drop rate: \(sys_status.drop_rate_comm)%"
        case 22:
            var p = mavlink_param_value_t()
            mavlink_msg_param_value_decode(&message, &p)
            return "PARAM_VALUE: id: \(String(paramId: p.param_id)), type: \(p.param_type), \(p.param_value), \(p.param_index), \(p.param_count)"
        case 23:
            var param_set = mavlink_param_set_t()
            mavlink_msg_param_set_decode(&message, &param_set)
            return "PARAM_SET: \(String(paramId: param_set.param_id)) = \(param_set.param_value)"
        case 30:
            var attitude = mavlink_attitude_t()
            mavlink_msg_attitude_decode(&message, &attitude)
            return "ATTITUDE roll: \(attitude.roll) pitch: \(attitude.pitch) yaw: \(attitude.yaw)"
        case 32:
            var local_position_ned = mavlink_local_position_ned_t()
            mavlink_msg_local_position_ned_decode(&message, &local_position_ned)
            return "LOCAL POSITION NED x: \(local_position_ned.x) y: \(local_position_ned.y) z: \(local_position_ned.z)"
        case 33:
            return "GLOBAL_POSITION_INT"
        case 74:
            var vfr_hud = mavlink_vfr_hud_t()
            mavlink_msg_vfr_hud_decode(&message, &vfr_hud)
            return "VFR_HUD heading: \(vfr_hud.heading) degrees"
        case 87:
            return "POSITION_TARGET_GLOBAL_INT"
        case 105:
            var highres_imu = mavlink_highres_imu_t()
            mavlink_msg_highres_imu_decode(&message, &highres_imu)
            return "HIGHRES_IMU Pressure: \(highres_imu.abs_pressure) millibar"
        case 147:
            var battery_status = mavlink_battery_status_t()
            mavlink_msg_battery_status_decode(&message, &battery_status)
            return "BATTERY_STATUS current consumed: \(battery_status.current_consumed) mAh"
        default:
            return "OTHER Message with id \(message.msgid)"
        }
    }
}

extension MavlinkMessage {
    var attitude: KiteAttitude? {
        guard msgid == 30 else {
            return nil
        }
        
        var message = self
        
        var att = mavlink_attitude_t()
        mavlink_msg_attitude_decode(&message, &att)
        
        let time = Double(att.time_boot_ms)
        let euler = Vector(att.yaw, att.pitch, att.roll)
        let rate = Vector(att.yawspeed, att.pitchspeed, att.rollspeed)
        
        return KiteAttitude(time: time, att: euler, rate: rate)
    }

    var quaternion: KiteQuaternion? {
        guard msgid == 31 else {
            return nil
        }

        var message = self
        
        var q = mavlink_attitude_quaternion_t()
        mavlink_msg_attitude_quaternion_decode(&message, &q)
        
        let time = Double(q.time_boot_ms)
        let quat = Quaternion(q.q2, q.q3, q.q4, q.q1)
        let rate = Vector(q.yawspeed, q.pitchspeed, q.rollspeed)

        return KiteQuaternion(time: time, quaternion: quat, rate: rate)
    }
    
    var location: KiteLocation? {
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

    var positionTarget: Vector? {
        guard msgid == 85 else {
            return nil
        }

        var message = self

        var local_position_ned = mavlink_position_target_local_ned_t()
        mavlink_msg_position_target_local_ned_decode(&message, &local_position_ned)
        let pos = Vector(local_position_ned.x, local_position_ned.y, local_position_ned.z)

        return pos
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
