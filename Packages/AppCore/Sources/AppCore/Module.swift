@MainActor
public protocol Module {
    var descriptor: ModuleDescriptor { get }

    func start(context: ModuleContext) throws
    func stop()
}
