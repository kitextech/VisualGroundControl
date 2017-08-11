//
//  ULogParser.swift
//  ulogReader
//
//  Created by Gustaf Kugelberg on 2017-08-11.
//  Copyright © 2017 Andreas Okholm. All rights reserved.
//

import Foundation

class ULogParser: CustomStringConvertible {

    // MARK: - Private variables -

    private let data: Data
    private var formats: [String : ULogFormat] = [:]
    private var dataMessages: [String : [MessageData]] = [:]
    private var messageNames: [UInt16 : String] = [:]

    // MARK: - Initialiser -

    init?(_ data: Data) {
        self.data = data

        guard checkMagicHeader(data: data), checkVersionHeader(data: data) else {
            return nil
        }

        parse(data: data.subdata(in: 16..<data.endIndex))
    }

    // MARK: - Reading API -

    public func read<S>(_ typeName: String, range: CountableRange<Int>? = nil, closure: (ULogReader) -> S) -> [S] {
        guard let messages = dataMessages[typeName] else {
            return []
        }

        let reader = ULogReader(parser: self, typeName: typeName, messages: messages)


        var result: [S] = []
        for i in range ?? 0..<messages.count {
            reader.index = i
            result.append(closure(reader))
        }

        return result
    }

    public func read<T>(_ typeName: String, primitive path: String) -> [T] {
        guard let offsetInMessage = byteOffset(of: typeName, at: path), let prop = property(of: typeName, at: path), prop.isBuiltin, !prop.isArray else {
            return []
        }

        return dataMessages[typeName]?.map { $0.data.advanced(by: Int(offsetInMessage)).value() } ?? []
    }

    public func read<T>(_ typeName: String, primitiveArray path: String) -> [[T]] {
        guard let offsetInMessage = byteOffset(of: typeName, at: path), let prop = property(of: typeName, at: path), case let .builtins(prim, n) = prop else {
            return []
        }

        return dataMessages[typeName]?.map { dataMessage in
            return (0..<n).map { i in dataMessage.data.advanced(by: Int(offsetInMessage + i*prim.byteCount)).value() }
            } ?? []
    }

    // MARK: - Information API -

    public func format(of typeName: String, at path: String = "") -> ULogFormat? {
        return property(of: typeName, at: path)?.format
    }

    public func property(of typeName: String, at path: String) -> ULogProperty? {
        return formats[typeName]?.property(at: path.pathComponents)
    }

    public func byteOffset(of typeName: String, at path: String) -> UInt? {
        return formats[typeName]?.byteOffset(to: path.pathComponents)
    }

    // MARK: - Private methods -

    // MARK: Initial parsing

    private func parse(data: Data) {
        var iteration = 0
        let iterationMax = 50000

        let startTime = Date()

        let numberOfBytes = data.count


        data.withUnsafeBytes { (u8Ptr: UnsafePointer<UInt8>) in
            var ptr = UnsafeMutableRawPointer(mutating: u8Ptr)
            let initialPointer = ptr

            while iteration < iterationMax {
                iteration += 1

                guard let messageHeader = MessageHeader(ptr: ptr) else {
                    break // complete when the header is nil
                }

                //                print(messageHeader)
                ptr += 3

                if ptr - initialPointer + Int(messageHeader.size) > numberOfBytes { return }
                let data = Data(bytes: ptr, count: Int(messageHeader.size))

                switch messageHeader.type {
                case .info:
                    guard let message = MessageInfo(data: data, header: messageHeader) else { return }
                    //                    infos.append(message)

                //                    print(message)
                case .format:
                    add(ULogFormat(data.subdata(in: 0..<Int(messageHeader.size)).asString()))
                    //                case .parameter:
                    //                    let message = MessageParameter(data: data, header: messageHeader)
                //                    parameters.append(message)
                case .parameter:
                    let message = MessageParameter(data: data, header: messageHeader)
                //                    parameters.append(message)
                case .addLoggedMessage:
                    let message = MessageAddLoggedMessage(data: data, header: messageHeader)
                    messageNames[message.id] = message.messageName
                    dataMessages[message.messageName] = dataMessages[message.messageName] ?? []
                    //                    addLoggedMessages.append(message)
                    //                    formatsByLoggedId.insert(formats[message.messageName]!, at: Int(message.id))

                case .data:
                    if let messageName = messageNames[data.value() as UInt16] {
                        dataMessages[messageName]?.append(MessageData(data: data, header: messageHeader))
                    }

                    //                    var index = 0
                    //                    let format = formatsByLoggedId[Int(message.id)]
                    //                    var content = [UlogValue]()
                    //
                    //                    for type in format.types {
                    //                        content.append(UlogValue(type: type, data: message.data.advanced(by: index)))
                    //                        index += type.byteCount
                    //                    }
                    //
                    //                    if self.data[format.name] == nil {
                    //                        self.data[format.name] = [[UlogValue]]()
                    //                    }
                    //
                    //                    self.data[format.name]!.append(content)

                    //                case .logging:
                    //                    let message = MessageLog(data: data, header: messageHeader)
                    //                    print("logging \(message.message)")
                    //                    break
                    //
                    //                case .dropout:
                    //                    let message = MessageDropout(data: data, header: messageHeader)
                    //                    print("dropout \(message.duration) ms")
                //                    break
                case .logging:
                    let message = MessageLog(data: data, header: messageHeader)
                    print("logging \(message.message)")

                case .dropout:
                    let message = MessageDropout(data: data, header: messageHeader)
                    print("dropout \(message.duration) ms")

                default:
                    break
                }
                
                ptr += Int(messageHeader.size)
            }
        }
        
        print("Complete: \(Date().timeIntervalSince(startTime))")
    }

    // MARK: - Helper methods

    private func checkMagicHeader(data: Data) -> Bool {
        let ulog = "ULog".unicodeScalars.map(UInt8.init(ascii:))
        return Array(data[0..<7]) == ulog + ["01", "12", "35"].map { UInt8($0, radix: 16)! }
    }

    private func checkVersionHeader(data: Data) -> Bool {
        return data[7] == 0 || data[7] == 1
    }

    private func add(_ format: ULogFormat) {
        let expanded = expandedWithExisting(format)
        expandExisting(with: expanded)
        formats[format.typeName] = expanded
    }

    private func expandedWithExisting(_ format: ULogFormat) -> ULogFormat {
        var expandedFormat = format
        for existingFormat in formats.values {
            expandedFormat = expandedFormat.expanded(with: existingFormat)
        }
        
        return expandedFormat
    }
    
    private func expandExisting(with newFormat: ULogFormat) {
        for (key, format) in formats {
            formats[key] = format.expanded(with: newFormat)
        }
    }

    // MARK: - Decription API -
    
    public var description: String {
        return formats.values.map { $0.description }.joined(separator: "\n\n")
    }

    // MARK: - Debugging API -

    public func debugAdd(_ format: ULogFormat) {
        add(format)
    }
}

class ULogReader {

    // MARK: - Private variables -

    private let parser: ULogParser
    private let typeName: String
    private let messages: [MessageData]

    private var cachedOffsets: [String : Int] = [:]
    private var cachedProperties: [String : ULogProperty] = [:]

    // MARK: - Initialiser -

    init(parser: ULogParser, typeName: String, messages: [MessageData]) {
        self.parser = parser
        self.typeName = typeName
        self.messages = messages
    }

    // MARK: - Reading API -

    public var index = 0

    public func value<T>(_ path: String) -> T {
        cache(path)

        guard let offsetInMessage = cachedOffsets[path], case .builtin? = cachedProperties[path] else {
            fatalError()
        }

        return messages[index].data.advanced(by: offsetInMessage).value()
    }

    public func values<T>(_ path: String) -> [T] {
        cache(path)

        guard let offsetInMessage = cachedOffsets[path], case let .builtins(prim, n)? = cachedProperties[path] else {
            fatalError()
        }

        return (0..<n).map { i in messages[index].data.advanced(by: offsetInMessage + Int(i*prim.byteCount)).value() as T }
    }

    // MARK: - Helper methods -

    private func cache(_ path: String) {
        cachedOffsets[path] = cachedOffsets[path] ?? parser.byteOffset(of: typeName, at: path).flatMap(Int.init)
        cachedProperties[path] = cachedProperties[path] ?? parser.property(of: typeName, at: path)
    }
}

extension String {
    var pathComponents: [String] {
        return components(separatedBy: ".").filter { $0 != "" }
    }
}

extension Data {
    func hexEncodedString() -> String {
        return map { String(format: "x%02hhx", $0) }.joined()
    }

    func asString() -> String {
        return String(map { Character(UnicodeScalar($0)) })
    }

    func value<T>() -> T {
        return withUnsafeBytes { $0.pointee }
    }
}
