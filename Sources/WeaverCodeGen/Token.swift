//
//  Token.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/22/18.
//

import Foundation
import SourceKittenFramework
import WeaverDI

// MARK: - Token

public protocol AnyTokenBox {
    var offset: Int { get }
    var length: Int { get }
    var line: Int { get set }
}

public struct TokenBox<T: Token & Equatable>: AnyTokenBox, Equatable, CustomStringConvertible {
    let value: T
    public let offset: Int
    public let length: Int
    public var line: Int
    
    public static func ==(lhs: TokenBox<T>, rhs: TokenBox<T>) -> Bool {
        guard lhs.value == rhs.value else { return false }
        guard lhs.offset == rhs.offset else { return false }
        guard lhs.length == rhs.length else { return false }
        guard lhs.line == rhs.line else { return false }
        return true
    }
    
    public var description: String {
        return "\(value) - \(offset)[\(length)] - at line: \(line)"
    }
}

public protocol Token: CustomStringConvertible {
    static func create(_ string: String) throws -> Self?
}

// MARK: - Patterns

private enum Patterns {
    private static let spaces = "\\s*"
    private static let equal = "\(spaces)=\(spaces)"
    private static let arrow = "\(spaces)<-\(spaces)"
    private static let name = "\\w+"
    private static let typeName = "\(name)(<\(name)(\(spaces),\(spaces)\(name))*>)?\\??"
    
    static let register = "^(\(name))\(equal)(\(typeName))\(spaces)(<-\(spaces)(\(typeName))\(spaces))?$"
    static let reference = "^(\(name))\(arrow)(\(typeName))\(spaces)$"
    static let parameter = "^(\(name))\(spaces)<=\(spaces)(\(typeName))\(spaces)$"
    static let scope = "^(\(name))\\.scope\(equal)\\.(\(name))\(spaces)$"
    static let configuration = "^(\(name))\\.(\(name))\(equal)(\(name)\\??)\(spaces)$"
    static let `import` = "^import\\s+(\(name))\(spaces)$"
}

// MARK: - Token Types

public struct RegisterAnnotation: Token, AutoEquatable {
    let name: String
    let typeName: String
    let protocolName: String?
    
    public static func create(_ string: String) throws -> RegisterAnnotation? {
        guard let matches = try NSRegularExpression(pattern: Patterns.register).matches(in: string) else {
            return nil
        }

        let protocolName: String?
        let arrowIndex = matches.index { $0.hasPrefix("<-") }
        if let arrowIndex = arrowIndex, arrowIndex + 1 < matches.count {
            protocolName = matches[arrowIndex + 1]
        } else {
            protocolName = nil
        }
        
        return RegisterAnnotation(name: matches[0], typeName: matches[1], protocolName: protocolName)
    }
    
    public var description: String {
        var s = "\(name) = \(typeName)"
        if let protocolName = protocolName {
            s += " <- \(protocolName)"
        }
        return s
    }
}

public struct ScopeAnnotation: Token, AutoEquatable {

    let name: String
    let scope: Scope
    
    public static func create(_ string: String) throws -> ScopeAnnotation? {
        guard let matches = try NSRegularExpression(pattern: Patterns.scope).matches(in: string) else {
            return nil
        }
        
        guard let scope = Scope(matches[1]) else {
            throw TokenError.invalidScope(matches[1])
        }
        
        return ScopeAnnotation(name: matches[0], scope: scope)
    }
    
    public var description: String {
        return "\(name).scope = \(scope)"
    }
}

public struct ReferenceAnnotation: Token, AutoEquatable {
    
    let name: String
    let typeName: String
    
    public static func create(_ string: String) throws -> ReferenceAnnotation? {
        guard let matches = try NSRegularExpression(pattern: Patterns.reference).matches(in: string) else {
            return nil
        }
        return ReferenceAnnotation(name: matches[0], typeName: matches[1])
    }
    
    public var description: String {
        return "\(name) <- \(typeName)"
    }
}

public struct ParameterAnnotation: Token, AutoEquatable {
    
    let name: String
    let typeName: String
    
    public static func create(_ string: String) throws -> ParameterAnnotation? {
        guard let matches = try NSRegularExpression(pattern: Patterns.parameter).matches(in: string) else {
            return nil
        }
        return ParameterAnnotation(name: matches[0], typeName: matches[1])
    }
    
    public var description: String {
        return "\(name) <= \(typeName)"
    }
}

public struct ConfigurationAnnotation: Token, AutoHashable, AutoEquatable {
    
    let attribute: ConfigurationAttribute
    
    let target: ConfigurationAttributeTarget
    
    public static func create(_ string: String) throws -> ConfigurationAnnotation? {
        guard let matches = try NSRegularExpression(pattern: Patterns.configuration).matches(in: string) else {
            return nil
        }
        
        let target = ConfigurationAttributeTarget(matches[0])
        let attribute = try ConfigurationAttribute(name: matches[1], valueString: matches[2])
        
        guard validate(configurationAttribute: attribute, with: target) else {
            throw TokenError.invalidConfigurationAttributeTarget(name: attribute.name.rawValue, target: target)
        }
        
        return ConfigurationAnnotation(attribute: attribute, target: target)
    }
    
    public var description: String {
        return "\(target).\(attribute)"
    }
}

public struct ImportDeclaration: Token, AutoEquatable {
    
    let moduleName: String
    
    public static func create(_ string: String) throws -> ImportDeclaration? {
        guard let matches = try NSRegularExpression(pattern: Patterns.import).matches(in: string) else {
            return nil
        }
        
        return ImportDeclaration(moduleName: matches[0])
    }
    
    public var description: String {
        return "import \(moduleName)"
    }
}

public struct InjectableType: Token, AutoEquatable {
    let name: String
    let accessLevel: AccessLevel
    let doesSupportObjc: Bool

    init(name: String,
         accessLevel: AccessLevel = .default,
         doesSupportObjc: Bool = false) {
        self.name = name
        self.accessLevel = accessLevel
        self.doesSupportObjc = doesSupportObjc
    }
    
    public var description: String {
        return "\(accessLevel.rawValue) \(name) {"
    }
}

public struct EndOfInjectableType: Token, AutoEquatable {
    public let description = "_ }"
}

public struct AnyDeclaration: Token, AutoEquatable {
    public let description = "{"
}

public struct EndOfAnyDeclaration: Token, AutoEquatable {
    public let description = "}"
}

// MARK: - Annotation Builder

enum TokenBuilder {

    static func makeAnnotationToken(string: String,
                                    offset: Int,
                                    length: Int,
                                    line: Int) throws -> AnyTokenBox? {
        
        let chars = CharacterSet(charactersIn: "/").union(.whitespaces)
        let annotation = string.trimmingCharacters(in: chars)

        let bodyRegex = try NSRegularExpression(pattern: "^weaver\\s*:\\s*(.*)")
        guard let body = bodyRegex.matches(in: annotation)?.first else {
            return nil
        }

        func makeTokenBox<T: Token & Equatable>(_ token: T) -> AnyTokenBox {
            return TokenBox(value: token, offset: offset, length: length, line: line)
        }
        
        if let token = try ConfigurationAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try RegisterAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ReferenceAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ScopeAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ParameterAnnotation.create(body) {
            return makeTokenBox(token)
        }
        if let token = try ImportDeclaration.create(body) {
            return makeTokenBox(token)
        }
        throw TokenError.invalidAnnotation(annotation)
    }
}

// MARK: - Default implementations

extension Token {
    public static func create(_ string: String) throws -> Self? {
        return nil
    }
}

// MARK: - Regex Util

private extension NSRegularExpression {
    
    func matches(in string: String) -> [String]? {
        let result = self
            .matches(in: string, range: NSMakeRange(0, string.utf16.count))
            .flatMap { match in (1..<match.numberOfRanges).map { match.range(at: $0) } }
            .compactMap { Range($0, in: string) }
            .map { String(string[$0]) }
        
        if result.isEmpty {
            return nil
        }
        return result
    }
}
