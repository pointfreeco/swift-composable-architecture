import Foundation
#if DEBUG
import os
#endif
@propertyWrapper
public struct EffectID: Hashable {
  static var currentContextID: AnyHashable? {
    Thread.current.threadDictionary.value(forKey: currentContextKey) as? AnyHashable
  }
  
  @usableFromInline
  static let currentContextKey = "swift-composable-architecture:currentContext"
  private let effectIdentifier: EffectIdentifier
  
  public var wrappedValue: EffectIdentifier {
    effectIdentifier.with(contextID: Self.currentContextID)
  }

  public init<UserData>(
    wrappedValue: UserData,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) where UserData: Hashable {
    effectIdentifier = .init(
      userData: wrappedValue,
      file: file,
      line: line,
      column: column
    )
  }

  public init(
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) {
    effectIdentifier = .init(
      file: file,
      line: line,
      column: column
    )
  }
}

public struct EffectIdentifier: Hashable {
  var contextID: AnyHashable?
  let userData: AnyHashable?
  let file: String
  let line: UInt
  let column: UInt
  
  internal init(
    contextID: AnyHashable? = nil,
    userData: AnyHashable? = nil,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) {
    self.contextID = contextID
    self.userData = userData
    self.file = "\(file)"
    self.line = line
    self.column = column
    #if DEBUG
      if contextID == nil {
        os_log(
          .fault, dso: rw.dso, log: rw.log,
          """
          An `@EffectID` declared at "%@:%d" was accessed outside of a reducer's context.
          
          `@EffectID` identifiers should only be accessed by `Reducer`'s while they're receiving \
          an action.
          """,
          "\(file)",
          line
        )
      }
    #endif
  }
  
  func with(contextID: AnyHashable?) -> Self {
    var identifier = self
    identifier.contextID = contextID
    return identifier
  }
}
