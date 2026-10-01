public enum ModuleError: Error, Equatable {
    case duplicateModule(String)
    case eventTapRefused(String)
    case unknownModule(String)
}
