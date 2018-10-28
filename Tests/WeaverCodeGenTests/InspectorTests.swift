//
//  InspectorTests.swift
//  WeaverCodeGenTests
//
//  Created by Théophane Rupin on 3/11/18.
//

import Foundation
import XCTest
import SourceKittenFramework

@testable import WeaverCodeGen

final class InspectorTests: XCTestCase {
    
    func test_valid_dependency_graph() {
        
        let code = """
final class API {
  // weaver: sessionManager = SessionManager <- SessionManagerProtocol
}

final class SessionManager {
}

final class Router {
  // weaver: api <- APIProtocol
}

final class LoginController {
  // weaver: sessionManager = SessionManager <- SessionManagerProtocol
}

final class App {
  // weaver: router = Router <- RouterProtocol
  // weaver: router.scope = .container

  // weaver: sessionManager = SessionManager <- SessionManagerProtocol
  // weaver: sessionManager.scope = .container

  // weaver: api = API <- APIProtocol
  // weaver: api.scope = .container
  
  // weaver: loginController = LoginController
  // weaver: loginController.scope = .container
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_unresolvable_dependency() {
        let code = """
final class API {
  // weaver: sessionManager <- SessionManagerProtocol
}

final class App {
  // weaver: api = API
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                            name: "sessionManager",
                                                                                            type: nil),
                                                                        underlyingError: .unresolvableDependency(history: [
                                                                            InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 4, file: "test.swift"),
                                                                                                                                                  name: "sessionManager",
                                                                                                                                                  type: Type(name: "App")))
                                                                            ])))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_cyclic_dependency() {
        let code = """
final class API {
    // weaver: session = Session <- SessionProtocol
    // weaver: session.scope = .container
}

final class Session {
    // weaver: sessionManager = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager.scope = .container

    // weaver: sessionManager1 = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager1.scope = .transient
}

final class SessionManager {
    // weaver: api = API <- APIProtocol
    // weaver: api.scope = .weak
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.cyclicDependency(history: [
                InspectorAnalysisHistoryRecord.triedToBuildType(PrintableResolver(fileLocation: FileLocation(line: 13, file: "test.swift"), type: Type(name: "SessionManager")), stepCount: 0),
                InspectorAnalysisHistoryRecord.triedToBuildType(PrintableResolver(fileLocation: FileLocation(line: 0, file: "test.swift"), type: Type(name: "API")), stepCount: 1),
                InspectorAnalysisHistoryRecord.triedToBuildType(PrintableResolver(fileLocation: FileLocation(line: 5, file: "test.swift"), type: Type(name: "Session")), stepCount: 2)
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 9, file: "test.swift"),
                                                                                            name: "sessionManager1",
                                                                                            type: Type(name: "SessionManager")),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_lazy_loaded_dependency_cycle() {
        let code = """
final class API {
    // weaver: session = Session <- SessionProtocol
    // weaver: session.scope = .container
}

final class Session {
    // weaver: sessionManager = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager.scope = .container

    // weaver: sessionManager1 = SessionManager <- SessionManagerProtocol
    // weaver: sessionManager1.scope = .container
}

final class SessionManager {
    // weaver: api = API <- APIProtocol
    // weaver: api.scope = .weak
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_unresolvable_reference_with_custom_builder() {
        let code = """
final class API {
    // weaver: api <- APIProtocol
    // weaver: api.builder = API.make
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_complex_custom_builder_resolution() {
        let code = """
final class AppDelegate {
    // weaver: appDelegate = AppDelegateProtocol
    // weaver: appDelegate.scope = .container
    // weaver: appDelegate.builder = AppDelegate.make
    
    // weaver: viewController = ViewController
    // weaver: viewController.scope = .container
    // weaver: viewController.builder = ViewController.make
}

final class ViewController {
    // weaver: appDelegate <- AppDelegateProtocol
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_custom_builder_not_shared_with_children() {
        let code = """
final class AppDelegate {
    // weaver: appDelegate <- AppDelegateProtocol
    // weaver: appDelegate.builder = AppDelegate.make
    
    // weaver: viewController = ViewController
    // weaver: viewController.scope = .container
    // weaver: viewController.builder = ViewController.make
}

final class ViewController {
    // weaver: appDelegate <- AppDelegateProtocol
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                InspectorAnalysisHistoryRecord.foundUnaccessibleDependency(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                               name: "appDelegate",
                                                                                               type: nil))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 10, file: "test.swift"),
                                                                                            name: "appDelegate",
                                                                                            type: nil),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_two_references_of_the_same_type() {
        let code = """
final class AppDelegate {
    // weaver: viewController1 = ViewController1 <- UIViewController
    // weaver: viewController1.scope = .container

    // weaver: viewController2 = ViewController2 <- UIViewController
    // weaver: viewController2.scope = .container

    // weaver: coordinator = Coordinator
    // weaver: coordinator.scope = .container
}

final class ViewController1: UIViewController {
    // weaver: viewController2 <- UIViewController
}

final class Coordinator {
    // weaver: viewController2 <- UIViewController
    // weaver: viewController1 <- UIViewController
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_misnamed_reference() {
        let code = """
final class AppDelegate {
    // weaver: viewController1 = ViewController1 <- UIViewController
    // weaver: viewController1.scope = .container

    // weaver: viewController2 = ViewController2 <- UIViewController
    // weaver: viewController2.scope = .container

    // weaver: coordinator = Coordinator
    // weaver: coordinator.scope = .container
}

final class Coordinator {
    // weaver: viewController1 <- UIViewController
    // weaver: viewController2 <- UIViewController
    // weaver: viewController3 <- UIViewController
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 0, file: "test.swift"),
                                                                                      name: "viewController3",
                                                                                      type: Type(name: "AppDelegate")))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 14, file: "test.swift"),
                                                                                            name: "viewController3",
                                                                                            type: nil),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_references_skipping_more_than_one_hierarchy_level() {
        let code = """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = URLSession.shared
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
        
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
    
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: movieManager <- MovieManaging
    
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .transient
}

final class MovieViewController: UIViewController {
    // weaver: movieID <= UInt
    // weaver: title <= String

    // weaver: movieManager <- MovieManaging
    
    // weaver: urlSession <- URLSession
}

final class MovieManager: MovieManaging {
    // weaver: movieAPI <- APIProtocol
}

final class MovieAPI: APIProtocol {
    // weaver: urlSession <- URLSession
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_isolated_objects() {
        let code = """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = URLSession.shared
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
        
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: self.isIsolated = true

    // weaver: movieManager <- MovieManaging
    
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .transient
}

final class MovieViewController: UIViewController {
    // weaver: self.isIsolated = true

    // weaver: movieID <= UInt
    // weaver: title <= String

    // weaver: movieManager <- MovieManaging
    
    // weaver: urlSession <- URLSession
}

final class MovieManager: MovieManaging {
    // weaver: movieAPI <- APIProtocol
}

final class MovieAPI: APIProtocol {
    // weaver: urlSession <- URLSession
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_isolated_object_with_non_isolated_dependent() {
        let code = """
final class AppDelegate {
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = URLSession.shared
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    // weaver: movieAPI.scope = .container
        
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container

    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: self.isIsolated = true

    // weaver: movieManager <- MovieManaging
    
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .transient
}

final class MovieViewController: UIViewController {
    // weaver: movieID <= UInt
    // weaver: title <= String

    // weaver: movieManager <- MovieManaging
    
    // weaver: urlSession <- URLSession
}

final class MovieManager: MovieManaging {
    // weaver: movieAPI <- APIProtocol
}

final class MovieAPI: APIProtocol {
    // weaver: urlSession <- URLSession
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.isolatedResolverCannotHaveReferents(type: Type(name: "HomeViewController"), referents: [
                PrintableResolver(fileLocation: FileLocation(line: 0, file: "test.swift"), type: Type(name: "AppDelegate"))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 34, file: "test.swift"),
                                                                                            name: "movieAPI",
                                                                                            type: Type(name: "MovieAPI")),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_unresolvable_dependency_on_two_hierachical_levels() {
        let code = """
final class AppDelegate {
    // weaver: homeViewController = HomeViewController <- UIViewController
    // weaver: homeViewController.scope = .container
}

final class HomeViewController: UIViewController {
    // weaver: movieController = MovieViewController <- UIViewController
    // weaver: movieController.scope = .container
}

final class MovieViewController: UIViewController {
    // weaver: urlSession <- URLSession
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            let underlyingError = InspectorAnalysisError.unresolvableDependency(history: [
                InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 5, file: "test.swift"),
                                                                                      name: "urlSession",
                                                                                      type: Type(name: "HomeViewController"))),
                InspectorAnalysisHistoryRecord.dependencyNotFound(PrintableDependency(fileLocation: FileLocation(line: 0, file: "test.swift"),
                                                                                      name: "urlSession",
                                                                                      type: Type(name: "AppDelegate")))
                ])
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 11, file: "test.swift"),
                                                                                            name: "urlSession",
                                                                                            type: nil),
                                                                        underlyingError: underlyingError))
        } catch {
            XCTFail("Unexpected error: \(error).")
        }
    }
    
    func test_public_type_with_no_dependencies() {
        let code = """
public final class MovieViewController: UIViewController {
    // weaver: movieManager <- MovieManaging
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_internal_type_with_no_dependency() {
        let code = """
final class MovieViewController: UIViewController {
    // weaver: movieManager <- MovieManaging
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                            name: "movieManager",
                                                                                            type: nil),
                                                                        underlyingError: InspectorAnalysisError.unresolvableDependency(history: [])))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_internal_type_with_a_reference_on_a_public_generic_type() {
        let code = """
public final class MovieViewController: UIViewController {
    // weaver: logger <- Logger<String>
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- Logger<String>
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_internal_type_with_a_reference_on_a_public_type_with_the_wrong_generic_type() {
        let code = """
public final class MovieViewController: UIViewController {
    // weaver: logger <- Logger<Int>
    // weaver: movieManager = MovieManager
}

final class MovieManager {
    // weaver: logger <- Logger<String>
}
"""
        
        do {
            try performTest(string: code)
            XCTFail("Expected error.")
        } catch let error as InspectorError {
            XCTAssertEqual(error, InspectorError.invalidDependencyGraph(PrintableDependency(fileLocation: FileLocation(line: 1, file: "test.swift"),
                                                                                            name: "logger",
                                                                                            type: nil),
                                                                        underlyingError: InspectorAnalysisError.unresolvableDependency(history: [])))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func test_reference_resolution_by_type() {
        let code = """
protocol FeeTest17Protocol {
    func helloWorld()
}

final class FeeTest17: FeeTest17Protocol {
    func helloWorld() {
        print("Hello World")
    }
}

final class FooTest17 {
    // weaver: fee = FeeTest17 <- FeeTest17Protocol
    // weaver: fee.scope = .container
}

final class FuuTest17 {
    // weaver: fee1 <- FeeTest17Protocol
    
    init(dependencies: FuuTest17DependencyResolver) {
        dependencies.fee1.helloWorld()
    }
}
"""
        
        do {
            try performTest(string: code)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Utils

private extension InspectorTests {
    
    func performTest(string: String) throws {
        let file = File(contents: string)
        let lexer = Lexer(file, fileName: "test.swift")
        let tokens = try lexer.tokenize()
        let parser = Parser(tokens, fileName: "test.swift")
        let syntaxTree = try parser.parse()
        let linker = try Linker(syntaxTrees: [syntaxTree])
        let inspector = Inspector(dependencyGraph: linker.dependencyGraph)
        try inspector.validate()
    }
}
