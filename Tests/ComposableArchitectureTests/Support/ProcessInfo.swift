import Foundation

extension ProcessInfo {
  var isCI: Bool {
    self.environment["CI"].map { Bool($0.lowercased()) ?? ($0 == "1") } ?? false
  }
}
