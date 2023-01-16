public struct UnimplementedReducer<State, Action>: ReducerProtocol {
  let file: StaticString
  let fileID: StaticString
  let line: UInt

  public init(file: StaticString = #file, fileID: StaticString = #fileID, line: UInt = #line) {
    self.file = file
    self.fileID = fileID
    self.line = line
  }

  public func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    runtimeWarn(
      """
      An unimplemented reducer received \(action) at \(fileID):\(line).
      """,
      file: file,
      line: line
    )
    return .none
  }
}
