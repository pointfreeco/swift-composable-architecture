import Foundation
struct DispatchToken: Hashable {
  static let specificKey = DispatchSpecificKey<Set<DispatchToken>>()
  
  var id: UUID
  var queueDescription: String
  
  init?(dispatchQueue: DispatchQueue) {
    guard dispatchQueue != .main else { return nil }
    self.id = UUID()
    self.queueDescription = "\(dispatchQueue)"
  }
  
  static func == (lhs: DispatchToken, rhs: DispatchToken) -> Bool { lhs.id == rhs.id }
  func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
