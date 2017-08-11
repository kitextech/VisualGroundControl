//
//  ULogMessage.swift
//  ulogReader
//
//  Created by Gustaf Kugelberg on 2017-08-11.
//  Copyright © 2017 Andreas Okholm. All rights reserved.
//

import Foundation

/*
 All the data
 HEADER:
 16 bytes - magic + timestamp
 DEFINITIONS:
 {
 3 bytes - header (type = format, size)
 n bytes - data
 }
 {
 3 bytes - header (type = info, size)

 n bytes - data
 }
 DATA:
 {
 3 bytes - header (type = addLoggedMessage, size)
 n bytes - data
 }
 {
 3 bytes - header (type = data, size)
 2 bytes - id
 n bytes - data
 }
 */

enum MessageType: Character {
    case format = "F"
    case data = "D"
    case info = "I"
    case infoMultiple = "M"
    case parameter = "P"
    case addLoggedMessage = "A"
    case removeLoggedMessage = "R"
    case sync = "S"
    case dropout = "O"
    case logging = "L"
    case flagBits = "B"
}

struct MessageHeader: CustomStringConvertible {
    let size: UInt16
    let type: MessageType

    var description: String {
        return "MessageHeader(size \(size), type: \(type))"
    }

    init?(ptr: UnsafeRawPointer) {
        size = ptr.assumingMemoryBound(to: UInt16.self).pointee // size = ptr.load(as: UInt16.self) works the first time, but not the second !

        guard let mt = MessageType(rawValue: ptr.load(fromByteOffset: 2, as: UInt8.self).character) else {
            print("Header error: \(Character(UnicodeScalar(ptr.load(fromByteOffset: 2, as: UInt8.self))))")
            return nil
        }
        type = mt
    }
}

struct MessageInfo: CustomStringConvertible {
    let header: MessageHeader
    let keyLength: UInt8
    let key: String
    let value: UlogValue

    var description: String {
        return "MessageInfo(keyLength: \(keyLength), key \(key), typeName: \(value.typeName)):\nValue:\n\(value)"
    }

    init?(data: Data, header: MessageHeader) {
        self.header = header
        keyLength = data.value()
        let typeAndName = data.subdata(in: 1..<Int(1 + keyLength)).asString().components(separatedBy: " ")

        let dataValue = data.subdata(in: 1 + Int(keyLength)..<Int(header.size))
        value = UlogValue(type: UlogType(typeName: typeAndName[0])!, data: dataValue)

        key = typeAndName[1]
    }
}

struct MessageParameter {
    let header: MessageHeader
    let keyLength: UInt8
    let key: String
    let value: UlogValue

    init(data: Data, header: MessageHeader) {
        self.header = header
        keyLength = data.value()
        let typeAndName = data.subdata(in: 1..<(1+Int(keyLength))).asString()
        let typeNName = typeAndName.components(separatedBy: " ")

        let dataValue = data.subdata(in: 1 + Int(keyLength)..<Int(header.size))

        value = UlogValue(type: UlogType(typeName: typeNName.first!)!, data: dataValue)

        key = typeNName[1]
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
        id = data.advanced(by: 1).value()
        messageName = data.subdata(in: 3..<Int(header.size) ).asString()
    }
}

struct MessageData {
    let header: MessageHeader
    let id: UInt16
    let data: Data

    init(data: Data, header: MessageHeader) {
        self.header = header
        id = data.value()
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
        timestamp = data.advanced(by: 1).value()
        message = data.subdata(in: 7..<Int(header.size)).asString()
    }
}

struct MessageDropout {
    let header: MessageHeader
    let duration: UInt16

    init(data: Data, header: MessageHeader) {
        self.header = header
        duration = data.value()
    }
}

extension UInt8 {
    var character: Character {
        return Character(UnicodeScalar(self))
    }
}

// MARK: - To be removed

struct MessageFormat {
    let header: MessageHeader
    let format: String

    init?(data: Data, header: MessageHeader) {
        self.header = header
        format = data.subdata(in: 0..<Int(header.size)).asString()
    }

    var messageName: String {
        return format.substring(to: format.range(of: ":")!.lowerBound)
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

enum UlogType {
    case uint8
    case uint16
    case uint32
    case uint64
    case int8
    case int16
    case int32
    case int64
    case float
    case double
    case bool
    case string
    case array([UlogType])

    init?(typeName: String) {
        let (name, count) = UlogType.nameAndNumber(typeName)

        if let count = count {
            self = name == "char" ? .string : .array(Array(repeating: UlogType(typeName: name)!, count: Int(count)))
        }
        else {
            switch typeName {
            case "uint8_t": self = .uint8
            case "uint16_t": self = .uint16
            case "uint32_t": self = .uint32
            case "uint64_t": self = .uint64
            case "int8_t": self = .int8
            case "int16_t": self = .int16
            case "int32_t": self = .int32
            case "int64_t": self = .int64
            case "float": self = .float
            case "double": self = .double
            case "bool": self = .bool
            default: self = .bool
            }
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

    private static func nameAndNumber(_ formatString: String) -> (name: String, number: UInt?) {
        let parts = formatString.components(separatedBy: ["[", "]"])
        guard parts.count == 3, let count = UInt(parts[1]) else {
            return (parts[0], nil)
        }

        return (parts[0], count)
    }
}

enum UlogValue: CustomStringConvertible {
    case uint8(UInt8)
    case uint16(UInt16)
    case uint32(UInt32)
    case uint64(UInt64)
    case int8(Int8)
    case int16(Int16)
    case int32(Int32)
    case int64(Int64)
    case float(Float)
    case double(Double)
    case bool(Bool)
    case string(String)
    case array([UlogValue])

    init(type: UlogType, data: Data) {
        //        print("Type name :\(type)")
        switch type {
        case .int8: self = .int8(data.value())
        case .uint8: self = .uint8(data.value())
        case .int16: self = .int16(data.value())
        case .uint16: self = .uint16(data.value())
        case .int32: self = .int32(data.value())
        case .uint32: self = .uint32(data.value())
        case .int64: self = .int64(data.value())
        case .uint64: self = .uint64(data.value())
        case .float: self = .float(data.value())
        case .double: self = .double(data.value())
        case .bool: self = .bool(data.value())
        case .string: self = .string(data.asString())
        case .array(let array):

            self = .array(array.enumerated().map { (offset, type) in
                return UlogValue(type: type, data: data.advanced(by: offset*type.byteCount))
                }
            )
        }
    }

    var typeName: String {
        switch self {
        case .uint8: return "uint8_t"
        case .uint16: return "uint16_t"
        case .uint32: return "uint32_t"
        case .uint64: return "uint64_t"
        case .int8: return "int8_t"
        case .int16: return "int16_t"
        case .int32: return "int32_t"
        case .int64: return "int64_t"
        case .float: return "float_t"
        case .double: return "double_t"
        case .bool: return "bool_t"
        case .string: return "char_t"
        case .array(let val): return val[0].description
        }
    }

    func getValue<T>() -> T {
        switch self {
        case .int8(let val): return val as! T
        case .uint8(let val): return val as! T
        case .int16(let val): return val as! T
        case .uint16(let val): return val as! T
        case .int32(let val): return val as! T
        case .uint32(let val): return val as! T
        case .int64(let val): return val as! T
        case .uint64(let val): return val as! T
        case .float(let val): return val as! T
        case .double(let val): return val as! T
        case .bool(let val): return val as! T
        case .string(let val): return val as! T
        case .array(let val): return val as! T
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
}

// HELPER structures

struct Format {
    let name: String
    let lookup: Dictionary<String, Int>
    let types: [UlogType]
}

class ULogOld {
    //    let data: Data

    var infos = [MessageInfo]()
    var messageFormats = [MessageFormat]()
    var formats = [String : Format]()
    var formatsByLoggedId = [Format]()
    var parameters = [MessageParameter]()
    var addLoggedMessages = [MessageAddLoggedMessage]()

    var data = [String : [[UlogValue]]]()

    init?(data: Data) {
        guard checkMagicHeader(data: data) else {
            return nil
        }

        guard checkVersionHeader(data: data) else {
            return nil
        }

        print(getLoggingStartMicros(data: data))

        readFileDefinitions(data: data.subdata(in: 16..<data.endIndex))
    }

    private func checkMagicHeader(data: Data) -> Bool {
        let ulog = "ULog".unicodeScalars.map(UInt8.init(ascii:))
        return Array(data[0..<7]) == ulog + ["01", "12", "35"].map { UInt8($0, radix: 16)! }
    }

    private func checkVersionHeader(data: Data) -> Bool {
        return data[7] == 0 || data[7] == 1
    }

    func getLoggingStartMicros(data: Data) -> UInt64 {
        // logging start in micro
        return data.subdata(in: 8..<16).value()
    }

    func readFileDefinitions(data: Data) {
        var iteration = 0
        let iterationMax = 50000

        let startTime = Date()

        let numberOfBytes = data.count

        data.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            var ptr = UnsafeMutableRawPointer(mutating: u8Ptr)
            let initialPointer = ptr

            while iteration < iterationMax {
                iteration += 1
                let newTime = Date()

                if iteration % (iterationMax/100) == 0 {
                    print( "complete\(Int(100*iteration/iterationMax)) time: \(newTime.timeIntervalSince(startTime))" )
                }

                guard let messageHeader = MessageHeader(ptr: ptr) else {
                    return // complete when the header is nil
                }

                print(messageHeader)
                ptr += 3

                if ptr - initialPointer + Int(messageHeader.size) > numberOfBytes { return }
                let data = Data(bytes: ptr, count: Int(messageHeader.size))

                switch messageHeader.type {
                case .info:
                    guard let message = MessageInfo(data: data, header: messageHeader) else { return }
                    //                    infos.append(message)

                    print(message)
                    break
                case .format:
                    guard let message = MessageFormat(data: data, header: messageHeader) else { return }
                    messageFormats.append(message)

                    let name = message.messageName

                    var types = [UlogType]()
                    var lookup = [String : Int]()

                    message.formatsProcessed.enumerated().forEach { (offset, element) in
                        lookup[element.0] = offset
                        types.append(element.1)
                    }

                    let f = Format(name: name, lookup: lookup, types: types)
                    formats[name] = f

                    break
                case .parameter:
                    let message = MessageParameter(data: data, header: messageHeader)
                    parameters.append(message)
                case .addLoggedMessage:
                    let message = MessageAddLoggedMessage(data: data, header: messageHeader)
                    addLoggedMessages.append(message)

                    formatsByLoggedId.insert(formats[message.messageName]!, at: Int(message.id))
                    break

                case .data:
                    let message = MessageData(data: data, header: messageHeader)

                    var index = 0
                    let format = formatsByLoggedId[Int(message.id)]
                    var content = [UlogValue]()

                    for type in format.types {
                        content.append(UlogValue(type: type, data: message.data.advanced(by: index)))
                        index += type.byteCount
                    }

                    if self.data[format.name] == nil {
                        self.data[format.name] = [[UlogValue]]()
                    }

                    self.data[format.name]!.append(content)
                    break

                case .logging:
                    let message = MessageLog(data: data, header: messageHeader)
                    print("logging \(message.message)")
                    break

                case .dropout:
                    let message = MessageDropout(data: data, header: messageHeader)
                    print("dropout \(message.duration) ms")
                    break

                default:
                    print("default, messageHeader.type \(messageHeader.type)")
                    
                    return
                }
                
                ptr += Int(messageHeader.size)
            }
        }
    }
}

