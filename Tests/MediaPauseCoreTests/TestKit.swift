/// Minimal assertion framework for environments without Xcode/XCTest
/// (Command Line Tools only). Tests are plain throwing functions registered
/// in main.swift; the runner reports PASS/FAIL and exits non-zero on any
/// failure — good enough for CI and for mutation testing.
import Foundation

public struct TestFailure: Error, CustomStringConvertible {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var description: String { message }
}

public func check(_ condition: Bool, _ message: @autoclosure () -> String = "check failed") throws {
    if !condition { throw TestFailure(message()) }
}

public func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ context: String = "") throws {
    if actual != expected {
        throw TestFailure(context.isEmpty
            ? "expected \(String(describing: expected)), got \(String(describing: actual))"
            : "\(context): expected \(String(describing: expected)), got \(String(describing: actual))")
    }
}

public func checkTrue(_ value: Bool, _ context: String = "") throws {
    try check(value, context.isEmpty ? "expected true" : "\(context): expected true")
}

public func checkFalse(_ value: Bool, _ context: String = "") throws {
    try check(!value, context.isEmpty ? "expected false" : "\(context): expected false")
}

public func checkNil<T>(_ value: T?, _ context: String = "") throws {
    try check(value == nil, context.isEmpty ? "expected nil" : "\(context): expected nil")
}

public func checkNotNil<T>(_ value: T?, _ context: String = "") throws -> T {
    guard let value else { throw TestFailure(context.isEmpty ? "expected non-nil" : "\(context): expected non-nil") }
    return value
}

public func checkContains(_ haystack: String, _ needle: String, _ context: String = "") throws {
    try check(haystack.contains(needle), context.isEmpty
        ? "expected '\(haystack)' to contain '\(needle)'"
        : "\(context): expected '\(haystack)' to contain '\(needle)'")
}

/// Asserts that `body` throws, and returns the thrown error.
@discardableResult
public func checkThrowsError<T>(_ body: () throws -> T) throws -> Error {
    do {
        _ = try body()
        throw TestFailure("expected an error but none was thrown")
    } catch let failure as TestFailure {
        throw failure
    } catch {
        return error
    }
}

/// Asserts that `body` does NOT throw.
public func checkNoThrow<T>(_ body: () throws -> T, _ context: String = "") throws {
    do {
        _ = try body()
    } catch {
        throw TestFailure(context.isEmpty ? "unexpected error: \(error)" : "\(context): unexpected error \(error)")
    }
}
