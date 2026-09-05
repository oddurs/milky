import Foundation

/// A minimal assertion harness. It exists because neither Swift Testing nor XCTest
/// is usable without a full Xcode install; swap it for a real test target if one lands.
final class Harness {
    private var failures: [String] = []
    private var checks = 0
    private var suite = ""

    func suite(_ name: String, _ body: () throws -> Void) {
        suite = name
        if ProcessInfo.processInfo.environment["MILKY_TEST_TRACE"] != nil {
            FileHandle.standardError.write("→ \(name)\n".data(using: .utf8)!)
        }
        do { try body() } catch { failures.append("\(name): threw \(error)") }
    }

    func expect(_ condition: Bool, _ message: @autoclosure () -> String,
                file: StaticString = #file, line: UInt = #line) {
        checks += 1
        guard !condition else { return }
        failures.append("\(suite): \(message())  [\(URL(fileURLWithPath: "\(file)").lastPathComponent):\(line)]")
    }

    func equal<T: Equatable>(_ actual: T, _ expected: T, _ label: String,
                             file: StaticString = #file, line: UInt = #line) {
        checks += 1
        guard actual != expected else { return }
        failures.append("\(suite): \(label) — expected \(expected), got \(actual)  " +
                        "[\(URL(fileURLWithPath: "\(file)").lastPathComponent):\(line)]")
    }

    func finish() -> Never {
        if failures.isEmpty {
            print("✓ \(checks) checks passed")
            exit(0)
        }
        print("✗ \(failures.count) of \(checks) checks failed\n")
        failures.forEach { print("  " + $0) }
        exit(1)
    }
}
