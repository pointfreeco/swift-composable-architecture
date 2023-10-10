import Foundation
import Observation

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public protocol ObservableState: Observable {
  var _$id: ObservableStateID { get }
}

@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
public struct ObservableStateID: Equatable, Hashable, Sendable {
  private let uuid: UUID

  public init() {
    self.uuid = UUID()
  }
}
