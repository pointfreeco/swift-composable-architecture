#if canImport(Testing)
  import ComposableArchitecture
  import Testing

  @Suite
  struct EffectCancellationIsolationTests {
    @Test
    func testIsolation1() async {
      let store = await TestStore(initialState: Feature.State()) {
        Feature()
      }
      await store.send(.start)
      await store.receive(\.response) {
        $0.value = 42
      }
      await store.send(.stop)
    }

    @Test
    func testIsolation2() async {
      let store = await TestStore(initialState: Feature.State()) {
        Feature()
      }
      await store.send(.start)
      await store.receive(\.response) {
        $0.value = 42
      }
      await store.send(.stop)
    }
  }

  @Reducer
  private struct Feature {
    struct State: Equatable {
      var value = 0
    }
    enum Action {
      case response(Int)
      case start
      case stop
    }
    enum CancelID { case longLiving }
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .response(let value):
          state.value = value
          return .none
        case .start:
          return .run { send in
            await send(.response(42))
            try await Task.never()
          }
          .cancellable(id: CancelID.longLiving, cancelInFlight: true)
        case .stop:
          return .cancel(id: CancelID.longLiving)
        }
      }
    }
  }

#endif
