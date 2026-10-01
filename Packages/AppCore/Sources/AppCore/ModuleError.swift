public enum ModuleError: Error, Equatable {
    case duplicateModule(String)
    case unknownModule(String)
}
