@_spi(Logging) import ComposableArchitecture
import SwiftUI

struct ObservableBasicsView: View {
  @State var store = Store(initialState: Feature.State()) {
    Feature()
  }

  var body: some View {
    let _ = Logger.shared.log("\(Self.self).body")
    Text(self.store.count.description)
    Button("Decrement") { self.store.send(.decrementButtonTapped) }
    Button("Increment") { self.store.send(.incrementButtonTapped) }
    Button("Dismiss") { self.store.send(.dismissButtonTapped) }
  }

  struct Feature: Reducer {
    struct State: Equatable, Identifiable, ObservableState {
      let id = UUID()
      var _count = 0
      var count: Int {
        get {
          self._$observationRegistrar.access(self, keyPath: \.count)
          return self._count
        }
        set {
          self._$observationRegistrar.withMutation(of: self, keyPath: \.count) {
            self._count = newValue
          }
        }
      }
      init(count: Int = 0) {
        self.count = count
      }
      let _$id = ObservableStateID()
      let _$observationRegistrar = ObservationRegistrar()
    }
    enum Action {
      case decrementButtonTapped
      case dismissButtonTapped
      case incrementButtonTapped
    }
    @Dependency(\.dismiss) var dismiss
    var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .decrementButtonTapped:
          state.count -= 1
          return .none
        case .dismissButtonTapped:
          return .run { _ in await self.dismiss() }
        case .incrementButtonTapped:
          state.count += 1
          return .none
        }
      }
    }
  }
}
