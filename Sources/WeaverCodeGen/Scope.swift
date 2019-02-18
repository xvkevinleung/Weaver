//
//  Scope.swift
//  WeaverCodeGen
//
//  Created by Théophane Rupin on 2/20/18.
//

import Foundation

/// Enum representing the scope of an instance.
///
/// - Cases:
///     - transient: A new instance is created when resolved. Can't be accessed from children.
///     - graph: One instance lives for the time the `DependencyContainer` object lives.
///     - weak: One instance lives for the time its strong references are living. Accessible from children.
///     - container: Like graph, but accessible from children.
enum Scope: String {
    case transient
    case graph
    case weak
    case container
    
    static var `default`: Scope {
        return .graph
    }
}

// MARK: Rules

extension Scope: CaseIterable, Encodable {
    
    var allowsAccessFromChildren: Bool {
        switch self {
        case .weak,
             .container:
            return true
        case .transient,
             .graph:
            return false
        }
    }
}
