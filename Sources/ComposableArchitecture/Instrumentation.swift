import Foundation

public class Instrumentation {
  public typealias Trigger = (EventInfo) -> Void

  public struct EventInfo: CustomStringConvertible {
    internal init(type: String, action: String = "", tags: [String: String] = [:]) {
      self.type = type
      self.action = action
      self.tags = tags
    }

    public let type: String
    public var action: String
    public var tags: [String: String]

    public var description: String {
      guard !action.isEmpty else {
        return "\(type)"
      }

      return "\(type): \(action)"
    }
  }

  public init(viewStore: Instrumentation.ViewStore? = nil, store: Instrumentation.Store? = nil) {
    self.viewStore = viewStore
    self.store = store
  }

  public static var shared: Instrumentation = .noop

  public struct ViewStore {
    public init(willSend: @escaping Trigger, didSend: @escaping Trigger, willDeduplicate: @escaping Trigger, didDeduplicate: @escaping Trigger, stateWillChange: @escaping Trigger, stateDidChange: @escaping Trigger) {
      self.willSend = willSend
      self.didSend = didSend
      self.willDeduplicate = willDeduplicate
      self.didDeduplicate = didDeduplicate
      self.stateWillChange = stateWillChange
      self.stateDidChange = stateDidChange
    }

    let willSend: Trigger
    let didSend: Trigger
    let willDeduplicate: Trigger
    let didDeduplicate: Trigger
    let stateWillChange: Trigger
    let stateDidChange: Trigger
  }

  public struct Store {
    public init(willSend: @escaping Instrumentation.Trigger, didSend: @escaping Instrumentation.Trigger, willScope: @escaping Instrumentation.Trigger, didScope: @escaping Instrumentation.Trigger, willProcessEvents: @escaping Instrumentation.Trigger, didProcessEvents: @escaping Instrumentation.Trigger) {
      self.willSend = willSend
      self.didSend = didSend
      self.willScope = willScope
      self.didScope = didScope
      self.willProcessEvents = willProcessEvents
      self.didProcessEvents = didProcessEvents
    }

    let willSend: Trigger
    let didSend: Trigger
    let willScope: Trigger
    let didScope: Trigger
    let willProcessEvents: Trigger
    let didProcessEvents: Trigger
  }

  let viewStore: ViewStore?
  let store: Store?
}

extension Instrumentation {
  static let noop = Instrumentation()
}
