import Foundation
import SQLite3

@safe
final class Database {
    enum Value {
        case text(String?)
        case blob(Data?)
        case real(Double)
        case integer(Int)

        func bind(to statement: OpaquePointer, at index: Int32) -> Int32 {
            let transient = unsafe unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            switch self {
            case .text(let text?):
                return text.utf8CString.withUnsafeBufferPointer { chars in
                    unsafe sqlite3_bind_text64(
                        statement, index, chars.baseAddress, sqlite3_uint64(chars.count - 1),
                        transient, UInt8(SQLITE_UTF8))
                }

            case .blob(let data?) where data.isEmpty:
                return unsafe sqlite3_bind_zeroblob(statement, index, 0)

            case .blob(let data?):
                return unsafe data.withUnsafeBytes { bytes in
                    unsafe sqlite3_bind_blob64(
                        statement, index, bytes.baseAddress, sqlite3_uint64(bytes.count), transient)
                }

            case .text(nil), .blob(nil):
                return unsafe sqlite3_bind_null(statement, index)

            case .real(let number):
                return unsafe sqlite3_bind_double(statement, index, number)

            case .integer(let number):
                return unsafe sqlite3_bind_int64(statement, index, Int64(number))
            }
        }
    }

    @safe
    struct Row {
        let statement: OpaquePointer

        func string(_ column: Int32) -> String? {
            guard let text = unsafe sqlite3_column_text(statement, column) else { return nil }
            let count = unsafe Int(sqlite3_column_bytes(statement, column))
            return unsafe String(
                bytes: UnsafeBufferPointer(start: text, count: count), encoding: .utf8)
        }

        func data(_ column: Int32) -> Data? {
            guard unsafe sqlite3_column_type(statement, column) != SQLITE_NULL else { return nil }
            let count = unsafe Int(sqlite3_column_bytes(statement, column))
            let bytes = unsafe sqlite3_column_blob(statement, column)
            return unsafe bytes.map { unsafe Data(bytes: $0, count: count) } ?? Data()
        }

        func integer(_ column: Int32) -> Int64 {
            unsafe sqlite3_column_int64(statement, column)
        }

        func real(_ column: Int32) -> Double {
            unsafe sqlite3_column_double(statement, column)
        }
    }

    struct Failure: Error {
        let message: String
    }

    private let connection: OpaquePointer

    init(path: String) throws {
        var pointer: OpaquePointer?
        let status = unsafe sqlite3_open_v2(
            path, &pointer, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard status == SQLITE_OK, let opened = unsafe pointer else {
            let message = unsafe String(cString: sqlite3_errstr(status))
            unsafe sqlite3_close(pointer)
            throw Failure(message: message)
        }
        unsafe connection = opened
    }

    func execute(_ sql: String) throws {
        try check(unsafe sqlite3_exec(connection, sql, nil, nil, nil))
    }

    func run(_ sql: String, _ values: [Value]) throws {
        try rows(sql, values) { _ in Never?.none }
    }

    @discardableResult
    func rows<T>(_ sql: String, _ values: [Value], _ read: (Row) -> T?) throws -> [T] {
        var prepared: OpaquePointer?
        try check(unsafe sqlite3_prepare_v2(connection, sql, -1, &prepared, nil))
        guard let statement = unsafe prepared else { return [] }
        defer { unsafe sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() {
            try check(unsafe value.bind(to: statement, at: Int32(index + 1)))
        }
        var results: [T] = []
        while true {
            let status = unsafe sqlite3_step(statement)
            guard status == SQLITE_ROW else {
                try check(status == SQLITE_DONE ? SQLITE_OK : status)
                return results
            }
            if let result = unsafe read(Row(statement: statement)) {
                results.append(result)
            }
        }
    }

    private func check(_ status: Int32) throws {
        guard status != SQLITE_OK else { return }
        throw Failure(message: unsafe String(cString: sqlite3_errmsg(connection)))
    }

    deinit {
        unsafe sqlite3_close(connection)
    }
}
