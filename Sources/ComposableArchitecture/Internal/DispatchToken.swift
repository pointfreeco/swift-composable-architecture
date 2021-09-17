import Foundation
final class DispatchToken: Hashable {
  static let specificKey = DispatchSpecificKey<Set<DispatchToken>>()
  let queueDescription: String
  
  init?(dispatchQueue: DispatchQueue) {
    guard dispatchQueue != .main else { return nil }
    self.queueDescription = "\(dispatchQueue)"
  }
  
  static func == (lhs: DispatchToken, rhs: DispatchToken) -> Bool { lhs === rhs }
  func hash(into hasher: inout Hasher) { }
}
