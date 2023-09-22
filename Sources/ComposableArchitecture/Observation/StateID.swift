import Foundation

//@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
public struct StateID: Equatable, Hashable, Sendable {
  private let uuid: UUID
  private var tag: Int?
  
  public init() {
    self.uuid = UUID()
  }

  public func tagged(_ tag: Int?) -> Self {
    var copy = self
    copy.tag = tag
    return copy
  }

  public static let inert = StateID()

  public static func stateID<T>(for value: T) -> StateID {
    (value as? any ObservableState)?._$id ?? .inert
  }
  
  public static func stateID(for value: some ObservableState) -> StateID {
    value._$id
  }
}

//@available(iOS 17, macOS 14, watchOS 10, tvOS 17, *)
extension StateID: CustomDebugStringConvertible {
  public var debugDescription: String {
    "StateID(\(self.uuid.description))"
  }
}
