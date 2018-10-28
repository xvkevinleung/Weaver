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
