import Foundation

extension String {
    func nest() -> String {
        components(separatedBy: .newlines)
            .map { $0.isEmpty ? "" : "    \($0)" }
            .joined(separator: "\n")
    }
}
