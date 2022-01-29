import Foundation

#if DEBUG
  import os
#endif
/// A property wrapper that generates a hashable value suitable to identify ``Effect``'s.
///
/// These identifiers are bound to the root ``Store`` executing the ``Reducer`` that produces the
/// ``Effect``'s. This can be conveniently exploited in document-based apps for example, where
/// you may have multiple documents and by extension, multiple root ``Store``'s coexisting in the
/// same process.
///
/// The value returned is an opaque hashable value that is constant across ``Reducer``'s runs, and
/// which can be used to identify long-running or cancellable effects:
///
/// ``` swift
/// Reducer<State, Action, Environment> { state, action, environment in
///  @EffectID var timerID
///  switch action {
///  case .onAppear:
///   return
///     .timer(id: timerID, every: 1, on: environment.mainQueue)
///     .map { _ in Action.timerTick }
///  case .onDisappear:
///   return .cancel(id: timerID)
///  case .timerTick:
///   state.ticks += 1
///   return .none
///  }
/// }
/// ```
///
/// If these property wrappers can be used without arguments, you can also provide some contextual
/// data to parametrize them:
///
/// ``` swift
/// Reducer<State, Action, Environment> { state, action, environment in
///  @EffectID var timerID = state.timerID
///  …
/// }
/// ```
///
/// - Important: This property wrapper is context-specific. Two identifiers defined in different
/// locations are always different, even if they share the same user data.
///
/// ``` swift
/// Reducer<State, Action, Environment> { _, _, _ in
///  @EffectID var id1 = 1
///  @EffectID var id2 = 1
///
///  // id1 != id2
/// }
/// ```
/// Two identifiers are equal iff they are defined at the same place, and with the same contextual
/// data (if any).
///
/// - Warning: This property wrapper should only be used with some ``Reducer``'s context, that is,
/// when reducing some action. Failing to do so raises a runtime warning when comparing two
/// identifiers. The value can be defined in any spot allowing property wrappers, but it should only
/// be accessed from some ``Reducer`` execution block.
@propertyWrapper
public struct EffectID: Hashable {
  #if canImport(_Concurrency) && compiler(>=5.5.2)
    @TaskLocal
    static var currentContextID: AnyHashable?
  #else
    static var currentContextID: AnyHashable? {
      if Thread.isMainThread {
        return mainThreadStoreCurrentContextID
      } else {
        return currentStoreContextIDLock.sync {
          currentStoreContextID
        }
      }
    }
  #endif

  private let value: Value

  public var wrappedValue: Value {
    value.with(contextID: Self.currentContextID)
  }

  public init<UserData>(
    wrappedValue: UserData,
    file: StaticString = #fileID,
    line: UInt = #line,
    column: UInt = #column
  ) where UserData: Hashable {
    value = .init(
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
    value = .init(
      file: file,
      line: line,
      column: column
    )
  }
}

extension EffectID {
  public struct Value: Hashable {
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

    public static func == (lhs: Value, rhs: Value) -> Bool {
      #if DEBUG
        if lhs.contextID == nil || rhs.contextID == nil {
          func issueWarningIfNeeded(id: Value) {
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
}
