import Foundation

extension ProcessInfo {
  var isCI: Bool {
    print("!!!")
    dump(self.environment)
    print("!!!")
    return self.environment["CI"].map { Bool($0.lowercased()) ?? ($0 == "1") } ?? false
  }
}
