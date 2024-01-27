#if swift(>=5.9)
  import ComposableArchitecture
  import SwiftUI

  private enum TestViewAction {
    @Reducer
    fileprivate struct Feature {
      struct State {}
      enum Action: ViewAction {
        case view(View)
        enum View { case tap }
      }
      var body: some ReducerOf<Self> { EmptyReducer() }
    }
    @ViewAction(for: Feature.self)
    fileprivate struct FeatureView: View {
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
    fileprivate struct Feature {
      enum State {
        case inert(Int)
      }
      enum Action {}
      var body: some ReducerOf<Self> { EmptyReducer() }
    }
  }
#endif
