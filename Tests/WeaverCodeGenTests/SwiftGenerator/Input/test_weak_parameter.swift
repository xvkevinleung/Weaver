final class FooTest18: BarTest18Protocol {
    // weaver: bar <- BarTest18Protocol
    // weaver: bar.scope = .weak
    
    init(injecting: FooTest18DependencyResolver) {
        // no-op
    }
}

protocol BarTest18Protocol: AnyObject {
}

final class BarTest18 {
    // weaver: fuu = FuuTest18
    // weaver: fuu.scope = .container
}

final class FuuTest18 {
    // weaver: foo = FooTest18 <- BarTest18Protocol
    // weaver: foo.scope = .container
    
    init(injecting: FuuTest18DependencyResolver) {
        // no-op
    }
}
