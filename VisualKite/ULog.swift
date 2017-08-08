//
//  UlogReader.swift
//  VisualKite
//
//  Created by Andreas Okholm on 07/08/2017.
//  Copyright © 2017 Gustaf Kugelberg. All rights reserved.
//

import Foundation

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "x%02hhx", $0) }.joined()
    }
    
    func toString() -> String {
        return String( self.map { Character(UnicodeScalar($0)) } )
    }
    
    func to<T>(type: T.Type) -> T {
        return withUnsafeBytes { pointer in return pointer.pointee }
    }
    
    func toValueType<T>() -> T {
        return withUnsafeBytes { pointer in return pointer.pointee }
    }
}


// ULog message types

enum MessageType: Character {
    case Format = "F"
    case Data = "D"
    case Info = "I"
    case InfoMultiple = "M"
    case Parameter = "P"
    case AddLoggedMessage = "A"
    case RemoveLoggedMessage = "R"
    case Sync = "S"
    case Dropout = "O"
    case Logging = "L"
    case FlagBits = "B"
}

// Ulog Datatypes

enum UlogType {
    case uint8
    case int8
    case uint16
    case int16
    case uint32
    case int32
    case uint64
    case int64
    case float
    case double
    case bool
    case string
    case array([UlogType])
    
    init?(typeName: String) {
        if (typeName.contains("[")) {
            if (typeName.contains("char")) {
                self = .string
            } else {
                let type = UlogType( typeName: typeName.substring(to: typeName.range(of: "[")!.lowerBound) )!
                
                let x = typeName.range(of: "[")!.upperBound
                let y = typeName.range(of: "]")!.lowerBound
                
                let count = Int(typeName.substring(with: x..<y))!
                
                self = .array( [UlogType](repeatElement(type, count: count) ) )
            }
        } else if (typeName == "int8_t") {
            self = .int8
        } else if (typeName == "uint8_t") {
            self = .uint8
        } else if (typeName == "int16_t") {
            self = .int16
        } else if (typeName == "uint16_t") {
            self = .uint16
        } else if (typeName == "int32_t") {
            self = .int32
        } else if (typeName == "uint32_t") {
            self = .uint32
        } else if (typeName == "int64_t") {
            self = .int64
        } else if (typeName == "uint64_t") {
            self = .uint64
        } else if (typeName == "float") {
            self = .float
        } else if (typeName == "double") {
            self = .double
        } else {
            self = .bool // not correct, could be ?
        }
    }
    
    var byteCount: Int {
        switch self {
        case .int8: return 1
        case .uint8: return 1
        case .int16: return 2
        case .uint16: return 2
        case .int32: return 4
        case .uint32: return 4
        case .int64: return 8
        case .uint64: return 8
        case .float: return 4
        case .double: return 8
        case .bool: return 1
        case .string: return 0 // Should not be ussed
        case .array(let array): return array.reduce(0) { $0 + $1.byteCount } // Should not be ussed
        }
    }
}


// Container of a ULogValue

enum UlogValue: CustomStringConvertible {
    
    case uint8(UInt8)
    case int8(Int8)
    case uint16(UInt16)
    case int16(Int16)
    case uint32(UInt32)
    case int32(Int32)
    case uint64(UInt64)
    case int64(Int64)
    case float(Float)
    case double(Double)
    case bool(Bool)
    case string(String)
    case array([UlogValue])
    
    init?(type: UlogType, value: Data) {
        switch type {
        case .int8: self = .int8(value.toValueType())
        case .uint8: self = .uint8(value.toValueType())
        case .int16: self = .int16(value.toValueType())
        case .uint16: self = .uint16(value.toValueType())
        case .int32: self = .int32(value.toValueType())
        case .uint32: self = .uint32(value.toValueType())
        case .int64: self = .int64(value.toValueType())
        case .uint64: self = .uint64(value.toValueType())
        case .float: self = .float(value.toValueType())
        case .double: self = .double(value.toValueType())
        case .bool: self = .bool(value.toValueType())
        case .string: self = .string(value.toString())
        case .array(let array):
            
            self = .array( array.enumerated().map { (offset, type) in
                return UlogValue(type: type, value: value.advanced(by: offset * type.byteCount))!
                }
            )
        }
    }
    
    var description: String {
        switch self {
        case .int8(let val): return String(val)
        case .uint8(let val): return String(val)
        case .int16(let val): return String(val)
        case .uint16(let val): return String(val)
        case .int32(let val): return String(val)
        case .uint32(let val): return String(val)
        case .int64(let val): return String(val)
        case .uint64(let val): return String(val)
        case .float(let val): return String(val)
        case .double(let val): return String(val)
        case .bool(let val): return String(val)
        case .string(let val): return val
        case .array(let val): return String(describing: val)
        }
    }
    
    func getValue<T>() -> T {
        switch self {
//        case .int8(let val): return String(val)
//        case .uint8(let val): return String(val)
//        case .int16(let val): return String(val)
//        case .uint16(let val): return String(val)
//        case .int32(let val): return String(val)
//        case .uint32(let val): return String(val)
        case .int64(let val): return val as! T
        case .uint64(let val): return val as! T
        case .float(let val): return val as! T
        case .double(let val): return val as! T
//        case .bool(let val): return String(val)
//        case .string(let val): return val
        case .array(let val): return val as! T
        default: fatalError()
        }
    }
}

//
// Messages
//

struct MessageHeader: CustomStringConvertible {
    let size: UInt16
    let type: MessageType
    
    var description: String {
        return "type: \(type), size \(size)"
    }
    
    init?(ptr: UnsafeRawPointer) {
        size = ptr.assumingMemoryBound(to: UInt16.self).pointee //        size = ptr.load(as: UInt16.self) works the first time, but not the second !
        
        guard let mt = MessageType(rawValue: Character(UnicodeScalar( ptr.load(fromByteOffset: 2, as: UInt8.self) ) ) ) else {
            let number = ptr.load(fromByteOffset: 2, as: UInt8.self)
            print( Character(UnicodeScalar( number ) ) )
            return nil
        }
        type = mt
    }
}

struct MessageInfo {
    let header: MessageHeader
    let keyLength: UInt8
    let key: String
    let value: UlogValue
    
    init?(data: Data, header: MessageHeader) {
        self.header = header
        keyLength = data.toValueType()
        let typeAndName = data.subdata(in: 1..<(1+Int(keyLength))).toString()
        let typeNName = typeAndName.components(separatedBy: " ")
        
        let dataValue = data.subdata(in: 1+Int(keyLength)..<Int(header.size) )
        
        value = UlogValue(type: UlogType(typeName: typeNName.first!)!, value: dataValue)!
        
        key = typeNName[1]
    }
}

struct MessageParameter {
    let header: MessageHeader
    let keyLength: UInt8
    let key: String
    let value: UlogValue
    
    init(data: Data, header: MessageHeader) {
        self.header = header
        keyLength = data.toValueType()
        let typeAndName = data.subdata(in: 1..<(1+Int(keyLength))).toString()
        let typeNName = typeAndName.components(separatedBy: " ")
        
        let dataValue = data.subdata(in: 1+Int(keyLength)..<Int(header.size) )
        
        value = UlogValue(type: UlogType(typeName: typeNName.first!)!, value: dataValue)!
        
        key = typeNName[1]
    }
}

struct MessageFormat {
    let header: MessageHeader
    let format: String
    
    init?(data: Data, header: MessageHeader) {
        self.header = header
        format = data.subdata(in: 0..<Int(header.size) ).toString()
    }
    
    var messageName: String {
        let f = format.substring(to: format.range(of: ":")!.lowerBound)
        return f
    }
    
    var formatsProcessed: [(String, UlogType)] {
        return format
            .substring(from: format.range(of: ":")!.upperBound)
            .components(separatedBy: ";")
            .filter { $0.characters.count > 0 }
            .map { split(s: $0) }
            .filter { $0.0 != "_padding0" }
    }
    
    func split(s: String) -> (String, UlogType) {
        let x = s.components(separatedBy: " ")
        let typeString = x.first!
        let variableName = x[1]
        let ulogtype = UlogType(typeName: typeString)!
        
        return (variableName, ulogtype)
    }
}

struct MessageAddLoggedMessage {
    let header: MessageHeader
    let multi_id: UInt8
    let id: UInt16
    let messageName: String
    
    init(data: Data, header: MessageHeader) {
        self.header = header
        multi_id = data[0]
        id = data.advanced(by: 1).toValueType()
        messageName = data.subdata(in: 3..<Int(header.size) ).toString()
    }
}

struct MessageData {
    let header: MessageHeader
    let id: UInt16
    let data: Data
    
    init(data: Data, header: MessageHeader) {
        self.header = header
        id = data.toValueType()
        self.data = data.advanced(by: 2)
    }
}

struct MessageLog {
    let header: MessageHeader
    let level: UInt8
    let timestamp: UInt64
    let message: String
    
    init(data: Data, header: MessageHeader) {
        self.header = header
        level = data[0]
        timestamp = data.advanced(by: 1).toValueType()
        message = data.subdata(in: 7..<Int(header.size) ).toString()
    }
}

struct MessageDropout {
    let header: MessageHeader
    let duration: UInt16
    
    init(data: Data, header: MessageHeader) {
        self.header = header
        duration = data.toValueType()
    }
    
};

// HELPER structures

struct Format {
    let name: String
    let lookup: Dictionary<String, Int>
    let types: [UlogType]
}

class ULog {
    
    //    let data: Data
    
    var infos = [MessageInfo]()
    var messageFormats = [MessageFormat]()
    var formats = Dictionary<String, Format>()
    var formatsByLoggedId = [Format]()
    var parameters = [MessageParameter]()
    var addLoggedMessages = [MessageAddLoggedMessage]()
    
    var data = Dictionary<String, [[UlogValue]]>()
    
    
    init?(data: Data) {
        if !checkMagicHeader(data: data) {
            print("bad header magic")
            return nil
        }
        
        if !checkVersionHeader(data: data) {
            print("bad version")
            return nil
        }
        
        print(getLoggingStartMicros(data: data))
        
        readFileDefinitions(data: data.subdata(in: 16..<data.endIndex))
    }
    
    func checkMagicHeader(data: Data) -> Bool {
        
        let magic = Data(bytes: Array<UInt8>( [
            UInt8(ascii: "U"),
            UInt8(ascii: "L"),
            UInt8(ascii: "o"),
            UInt8(ascii: "g"),
            UInt8("01", radix: 16)!,
            UInt8("12", radix: 16)!,
            UInt8("35", radix: 16)!
            ]))
        
        return data.subdata(in: Range(uncheckedBounds: (lower: 0, upper: 7))) == magic
    }
    
    func checkVersionHeader(data:Data) -> Bool {
        return data[7] == UInt8(0) || data[7] == UInt8(1)
    }
    
    func getLoggingStartMicros(data: Data) -> UInt64 {
        // logging start in micro
        return data.subdata(in: 8..<16).withUnsafeBytes { $0.pointee }
    }
    
    func readFileDefinitions(data: Data) -> Void {
        
        var iteration = 0
        let iterationMax = 50000
        
        let startTime = Date()
        
        let numberOfBytes = data.count
        
        
        data.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            var ptr = UnsafeMutableRawPointer(mutating: u8Ptr)
            let initialPointer = ptr
            
            
            while (iteration < iterationMax) {
                iteration += 1
                let newTime = Date()
                
                if ( iteration % (iterationMax/100) == 0) { print( "complete\(Int(100*iteration/iterationMax)) time: \(newTime.timeIntervalSince(startTime))" ) }
                
                guard let messageHeader = MessageHeader(ptr: ptr ) else {
                    return // complete when the header is nil
                }
                ptr += 3
                
                if (ptr-initialPointer + Int(messageHeader.size) > numberOfBytes) { return }
                let data = Data(bytes: ptr, count: Int(messageHeader.size))
                
                
                switch messageHeader.type {
                case .Info:
                    guard let message = MessageInfo(data: data, header: messageHeader) else { return }
                    infos.append(message)
                    break
                case .Format:
                    guard let message = MessageFormat(data: data, header: messageHeader) else { return }
                    messageFormats.append(message)
                    
                    let name = message.messageName
                    
                    var types = [UlogType]()
                    var lookup = Dictionary<String, Int>()
                    
                    message.formatsProcessed.enumerated().forEach({ (offset, element) in
                        lookup[element.0] = offset
                        types.append(element.1)
                    })
                    
                    let f = Format(name: name, lookup: lookup, types: types)
                    
                    formats[name] = f
                    
                    break
                case .Parameter:
                    let message = MessageParameter(data: data, header: messageHeader)
                    parameters.append(message)
                case .AddLoggedMessage:
                    let message = MessageAddLoggedMessage(data: data, header: messageHeader)
                    addLoggedMessages.append(message)
                    
                    formatsByLoggedId.insert(formats[message.messageName]!, at: Int(message.id))
                    break
                    
                case .Data:
                    let message = MessageData(data: data, header: messageHeader)
                    
                    var index = 0
                    let format = formatsByLoggedId[Int(message.id)]
                    var content = [UlogValue]()
                    
                    for type in format.types {
                        content.append( UlogValue(type: type, value: message.data.advanced(by: index) )! )
                        index += type.byteCount
                    }
                    
                    if (self.data[format.name] == nil) {
                        self.data[format.name] = [[UlogValue]]()
                    }
                    
                    self.data[format.name]!.append(content)
                    break
                    
                case .Logging:
                    let message = MessageLog(data: data, header: messageHeader)
                    print(message.message)
                    break
                    
                case .Dropout:
                    let message = MessageDropout(data: data, header: messageHeader)
                    print("dropout \(message.duration) ms")
                    break
                    
                default:
                    print(messageHeader.type)
                    return
                }
                
                ptr += Int(messageHeader.size)
            }
        }
    }
}
