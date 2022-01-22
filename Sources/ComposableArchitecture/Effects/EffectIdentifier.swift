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
  }

  func with(contextID: AnyHashable?) -> Self {
    var identifier = self
    identifier.contextID = contextID
    return identifier
  }

  public static func == (lhs: EffectIdentifier, rhs: EffectIdentifier) -> Bool {
    #if DEBUG
      if lhs.contextID == nil || rhs.contextID == nil {
        func issueWarningIfNeeded(id: EffectIdentifier) {
          guard id.contextID == nil else { return }
          let warningID = WarningID(file: id.file, line: id.line, column: id.column)
          guard
            Self.issuedWarningsLock.sync(work: {
              guard !issuedWarnings.contains(warningID) else { return false }
              issuedWarnings.insert(warningID)
              return true
            })
          else {
            return
          }
          os_log(
            .fault, dso: rw.dso, log: rw.log,
            """
            An `@EffectID` declared at "%@:%d" was accessed outside of a reducer's context.

            `@EffectID` identifiers should only be accessed by `Reducer`'s while they're receiving \
            an action.
            """,
            "\(id.file)",
            id.line
          )
        }
        issueWarningIfNeeded(id: lhs)
        issueWarningIfNeeded(id: rhs)
      }
    #endif
    guard
      lhs.file == rhs.file,
      lhs.line == rhs.line,
      lhs.column == rhs.column,
      lhs.contextID == rhs.contextID,
      lhs.userData == rhs.userData
    else {
      return false
    }
    return true
  }

  #if DEBUG
    static var issuedWarningsLock = NSRecursiveLock()
    static var issuedWarnings = Set<WarningID>()
    struct WarningID: Hashable {
      let file: String
      let line: UInt
      let column: UInt
    }
  #endif
}
