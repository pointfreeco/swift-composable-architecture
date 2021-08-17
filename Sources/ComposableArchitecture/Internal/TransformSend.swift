// NB: todo
extension Store {
  func transformSend(
    _ transform: @escaping (Action, (Action) -> Void) -> Void
  ) -> Store<State, Action> {
    var isSending = false
    let localStore = Store(
      initialState: self.state.value,
      reducer: .init { localState, localAction, _ in
        isSending = true
        defer { isSending = false }
        transform(localAction, self.send)
        localState = self.state.value
        return .none
      },
      environment: ()
    )
    localStore.parentCancellable = self.state
      .dropFirst()
      .sink { [weak localStore] newValue in
        guard !isSending else { return }
        localStore?.state.value = newValue
      }
    return localStore
  }
}
