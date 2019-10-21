import Foundation

/// This file is generated by Weaver 0.12.4
/// DO NOT EDIT!

// MARK: - MovieAPI

protocol MovieAPIInputDependencyResolver: AnyObject {
    var urlSession: URLSession { get }
}

protocol MovieAPIDependencyResolver: AnyObject {
    var urlSession: URLSession { get }
    var logger: Logger { get }
}

final class MovieAPIDependencyContainer: MovieAPIDependencyResolver {

    let urlSession: URLSession

    private var _logger: Optional<Logger> = nil
    var logger: Logger {
        if let value: Logger = _logger {
            return value
        }
        let value: Logger = Logger()
        _logger = value
        return value
    }

    init(injecting dependencies: MovieAPIInputDependencyResolver) {
        urlSession = dependencies.urlSession
        _ = logger
    }
}

final class MovieAPIShimDependencyContainer: MovieAPIInputDependencyResolver {

    let urlSession: URLSession

    init(urlSession: URLSession) { self.urlSession = urlSession }
}

public extension MovieAPI {

    convenience init(urlSession: URLSession) {
        let shim = MovieAPIShimDependencyContainer(urlSession: urlSession)
        let dependencies = MovieAPIDependencyContainer(injecting: shim)
        self.init(injecting: dependencies)
    }
}
