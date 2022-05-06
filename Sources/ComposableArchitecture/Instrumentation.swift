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

  public init(store: Instrumentation.Store? = nil) {
    self.store = store
  }

  public static var shared: Instrumentation = .noop

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

  let store: Store?
}

extension Instrumentation {
  static let noop = Instrumentation()
}
