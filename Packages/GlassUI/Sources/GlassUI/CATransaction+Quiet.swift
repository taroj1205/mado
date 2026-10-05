import QuartzCore

extension CATransaction {
    static func quietly(_ body: () -> Void) {
        begin()
        setDisableActions(true)
        body()
        commit()
    }
}
