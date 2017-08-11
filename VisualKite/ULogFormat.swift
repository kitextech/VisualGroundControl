//
//  ULogFormat.swift
//  ulogReader
//
//  Created by Gustaf Kugelberg on 2017-08-11.
//  Copyright © 2017 Andreas Okholm. All rights reserved.
//

import Foundation

struct ULogFormat: CustomStringConvertible {
    // MARK: - Initialisers -

    let typeName: String
    private let properties: [(String, ULogProperty)]

    // MARK: - Initialisers -

    init(_ typeName: String, _ properties: [(String, ULogProperty)]) {
        self.typeName = typeName
        self.properties = properties
    }

    init(_ formatString: String) {
        let nameAndContents = formatString.components(separatedBy: ":")
        self.typeName = nameAndContents[0]

        self.properties = nameAndContents[1].components(separatedBy: ";").filter { $0 != "" }.map { string in
            let formatAndName = string.components(separatedBy: " ")
            return (formatAndName[1], ULogProperty(formatAndName[0]))
        }
    }

    // MARK: - Recursive Expansion API -

    public func expanded(with customType: ULogFormat) -> ULogFormat {
        if customType.typeName == typeName {
            return customType
        }

        return ULogFormat(typeName, properties.map { ($0, $1.expanded(with: customType)) })
    }

    // MARK: - Information API -

    public func property(at path: [String]) -> ULogProperty? {
        guard !path.isEmpty else {
            return .custom(self)
        }

        let (name, index) = nameAndNumber(path[0])

        guard let property = properties.first(where: { $0.0 == name })?.1 else {
            return nil
        }

        let propertyToRecurse: ULogProperty?

        switch (index, path.count, property) {
        case let (i?, _, .builtins(type, n)) where i < n: propertyToRecurse = .builtin(type)
        case let (i?, _, .customs(type, n)) where i < n: propertyToRecurse = .custom(type)
        case (nil, _, .builtin), (nil, _, .custom): propertyToRecurse = property
        case (nil, 1, .builtins), (nil, 1, .customs): propertyToRecurse = property
        default: propertyToRecurse = nil
        }

        return propertyToRecurse?.property(at: Array(path.dropFirst()))
    }

    public func byteOffset(to path: [String]) -> UInt? {
        guard !path.isEmpty else {
            return 0
        }

        var offsetToProperty: UInt = 0
        for property in properties {
            let (name, index) = nameAndNumber(path[0])

            if property.0 == name {
                guard let offsetInsideProperty = property.1.byteOffset(to: Array(path.dropFirst())) else {
                    return nil
                }

                let offset: UInt?

                switch (index, path.count, property.1) {
                case let (i?, _, .builtins(type, n)) where i < n: offset = offsetToProperty + i*type.byteCount + offsetInsideProperty
                case let (i?, _, .customs(type, n)) where i < n: offset = offsetToProperty + i*type.byteCount + offsetInsideProperty
                case (nil, _, .builtin), (nil, _, .custom): offset = offsetToProperty + offsetInsideProperty
                case (nil, 1, .builtins), (nil, 1, .customs): offset = offsetToProperty + offsetInsideProperty
                default: return nil
                }

                return offset

            }
            else {
                offsetToProperty += property.1.byteCount
            }
        }

        return nil
    }

    public var byteCount: UInt {
        return properties.reduce(0) { $0 + $1.1.byteCount }
    }

    // MARK: - Description API -

    public var description: String {
        return ([typeName] + indent(formatDescription)).joined(separator: "\n")
    }

    public var formatDescription: [String] {
        return properties.flatMap { name, property in ["\(name): \(property.typeName)"] + indent(property.formatDescription) }
    }

    // MARK: - Helper methods -

    private func indent(_ list: [String]) -> [String] {
        return list.map { "    " + $0 }
    }
}

enum ULogProperty {
    case builtin(ULogPrimitive)
    case custom(ULogFormat)
    case builtins(ULogPrimitive, UInt)
    case customs(ULogFormat, UInt)

    // MARK: - Initialiser -

    init(_ formatString: String) {
        let (name, arraySize) = nameAndNumber(formatString)

        if let arraySize = arraySize {
            if let builtin = ULogPrimitive(rawValue: name) {
                self = .builtins(builtin, arraySize)
            }
            else {
                self = .customs(.init(name, []), arraySize)
            }
        }
        else {
            if let builtin = ULogPrimitive(rawValue: name) {
                self = .builtin(builtin)
            }
            else {
                self = .custom(.init(name, []))
            }
        }
    }

    // MARK: - Recursive Expansion API -

    public func expanded(with customType: ULogFormat) -> ULogProperty {
        switch self {
        case .custom(let format): return .custom(format.expanded(with: customType))
        case .customs(let format, let n): return .customs(format.expanded(with: customType), n)
        default: return self
        }
    }

    // MARK: - Information API -

    // MARK: Non-recursive
    public var isArray: Bool {
        switch self {
        case .customs, .builtins: return true
        default: return false
        }
    }

    public var isBuiltin: Bool {
        switch self {
        case .builtin, .builtins: return true
        default: return false
        }
    }

    public var byteCount: UInt {
        switch self {
        case .builtin(let primitiveType): return primitiveType.byteCount
        case .builtins(let primitiveType, let n): return n*primitiveType.byteCount
        case .custom(let customType): return customType.byteCount
        case .customs(let customType, let n): return n*customType.byteCount
        }
    }

    public var format: ULogFormat? {
        switch self {
        case .custom(let format), .customs(let format, _): return format
        default: return nil
        }
    }

    // MARK: Recursive

    public func property(at path: [String]) -> ULogProperty? {
        switch (path.count, self) {
        case (0, _): return self
        case (_, .customs(let format, _)), (_, .custom(let format)): return format.property(at: path)
        default: return nil
        }
    }

    public func byteOffset(to path: [String]) -> UInt? {
        switch (path.count, self) {
        case (0, _): return 0
        case (_, .customs(let format, _)), (_, .custom(let format)): return format.byteOffset(to: path)
        default: return nil
        }
    }


    // MARK: - Description API -

    public var typeName: String {
        switch self {
        case .builtin(let builtin): return builtin.typeName
        case .custom(let format): return format.typeName
        case .builtins(let builtin, let n): return builtin.typeName + "[\(n)]"
        case .customs(let format, let n): return format.typeName + "[\(n)]"
        }
    }

    public var formatDescription: [String] {
        switch self {
        case .builtin, .builtins: return []
        case .custom(let format), .customs(let format, _): return format.formatDescription
        }
    }
}

enum ULogPrimitive: String {
    case uint8 = "uint8_t"
    case uint16 = "uint16_t"
    case uint32 = "uint32_t"
    case uint64 = "uint64_t"
    case int8 = "int8_t"
    case int16 = "int16_t"
    case int32 = "int32_t"
    case int64 = "int64_t"
    case float = "float"
    case double = "double"
    case bool = "bool"
    case char = "char"

    // MARK: - Information API -

    public var byteCount: UInt {
        switch self {
        case .uint8: return 1
        case .uint16: return 2
        case .uint32: return 4
        case .uint64: return 8
        case .int8: return 1
        case .int16: return 2
        case .int32: return 4
        case .int64: return 8
        case .float: return 4
        case .double: return 8
        case .bool: return 1
        case .char: return 1
        }
    }
    
    // MARK: - Description API -
    
    public var typeName: String {
        return rawValue
    }
}

// MARK: - Extensions -

private func nameAndNumber(_ formatString: String) -> (name: String, number: UInt?) {
    let parts = formatString.components(separatedBy: ["[", "]"])
    guard parts.count == 3, let count = UInt(parts[1]) else {
        return (parts[0], nil)
    }

    return (parts[0], count)
}

