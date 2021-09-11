extension _Reducer {
  @inlinable
  public func optional(
    file: StaticString = #fileID,
    line: UInt = #line
  ) -> Reducers.Optional<Self> {
    .init(
      self,
      file: file,
      line: line
    )
  }
}

extension Reducers {
  public struct Optional<WrappedReducer>: _Reducer
  where WrappedReducer: _Reducer {
    public let wrappedReducer: WrappedReducer
    public let file: StaticString
    public let line: UInt

    @Dependency(\.breakpointsEnabled) public var breakpointOnNil

    @inlinable
    public init(
      _ wrappedReducer: WrappedReducer,
      file: StaticString = #fileID,
      line: UInt = #line
    ) {
      self.wrappedReducer = wrappedReducer
      self.file = file
      self.line = line
    }

    @inlinable
    public func reduce(into state: inout WrappedReducer.State?, action: WrappedReducer.Action)
    -> Effect<WrappedReducer.Action, Never> {
      guard state != nil else {
        if self.breakpointOnNil {
          breakpoint(
            """
            ---
            Warning: Reducer.optional@\(file):\(line)

            "\(debugCaseOutput(action))" was received by an optional reducer when its state was \
            "nil". This is generally considered an application logic error, and can happen for a \
            few reasons:

            * The optional reducer was combined with or run from another reducer that set \
            "\(State.self)" to "nil" before the optional reducer ran. Combine or run optional \
            reducers before reducers that can set their state to "nil". This ensures that optional \
            reducers can handle their actions while their state is still non-"nil".

            * An in-flight effect emitted this action while state was "nil". While it may be \
            perfectly reasonable to ignore this action, you may want to cancel the associated \
            effect before state is set to "nil", especially if it is a long-living effect.

            * This action was sent to the store while state was "nil". Make sure that actions for \
            this reducer can only be sent to a view store when state is non-"nil". In SwiftUI \
            applications, use "IfLetStore".
            ---
            """
          )
        }
        return .none
      }
      return self.wrappedReducer.reduce(into: &state!, action: action)
    }
  }
}
