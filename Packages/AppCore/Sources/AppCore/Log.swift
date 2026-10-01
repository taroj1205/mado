public import os

public enum Log {
    public static let subsystem = "com.taroj1205.mado"

    public static func logger(_ category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }

    public static func signposter(_ category: String) -> OSSignposter {
        OSSignposter(subsystem: subsystem, category: category)
    }
}
