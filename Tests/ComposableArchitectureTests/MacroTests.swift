#if canImport(ComposableArchitectureMacros)
  import ComposableArchitecture
  import SwiftUI

  private enum TestViewAction {
    @Reducer
    private struct Feature {
      struct State {}
      enum Action: ViewAction {
        case view(View)
        enum View { case tap }
      }
      var body: some ReducerOf<Self> { EmptyReducer() }
    }
    @ViewAction(for: Feature.self)
    private struct FeatureView: View {
      let store: StoreOf<Feature>
      var body: some View {
        Button("Tap") { send(.tap) }
        Button("Tap") { send(.tap, animation: .default) }
        Button("Tap") { send(.tap, transaction: Transaction(animation: .default)) }
      }
    }
  }

  private enum TestObservableEnum_NonObservableCase {
    @Reducer
    private struct Feature {
      enum State {
        case inert(Int)
      }
      enum Action {}
      var body: some ReducerOf<Self> { EmptyReducer() }
    }
  }
#endif
