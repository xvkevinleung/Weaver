//
//  MovieManager.swift
//  Sample
//
//  Created by Théophane Rupin on 4/5/18.
//  Copyright © 2018 Scribd. All rights reserved.
//

import Foundation

// MARK: - Error

public enum MovieManagerError: Error {
    case oops
}

// MARK: - Manager

public protocol MovieManaging {
    
    func getDiscoverMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void)
    
    func getMovie(id: UInt, completion: @escaping (Result<Movie, MovieManagerError>) -> Void)
}

public final class MovieManager: MovieManaging {

    private let dependencies: MovieManagerDependencyResolver
    
    // weaver: logger <- Logger
    
    // weaver: urlSession = URLSession
    // weaver: urlSession.scope = .container
    // weaver: urlSession.builder = { _ in URLSession.shared }
    
    // weaver: movieAPI = MovieAPI <- APIProtocol
    
    // weaver: host <= String?
    
    init(injecting dependencies: MovieManagerDependencyResolver) {
        self.dependencies = dependencies
    }
    
    public func getDiscoverMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void) {
        
        let request = APIRequest<Page<Movie>>(host: dependencies.host, path: "/discover/movie")
        
        dependencies.movieAPI.send(request: request) { result in
            switch result {
            case .success(let page):
                completion(.success(page))
            case .failure(let error):
                self.dependencies.logger.log(.error, "\(error)")
                completion(.failure(.oops))
            }
        }
    }
    
    public func getMovie(id: UInt, completion: @escaping (Result<Movie, MovieManagerError>) -> Void) {
        
        let request = APIRequest<Movie>(path: "/movie/\(id)")
        
        dependencies.movieAPI.send(request: request) { result in
            switch result {
            case .success(let movie):
                completion(.success(movie))
            case .failure(let error):
                self.dependencies.logger.log(.error, "\(error)")
                completion(.failure(.oops))
            }
        }
    }
}
