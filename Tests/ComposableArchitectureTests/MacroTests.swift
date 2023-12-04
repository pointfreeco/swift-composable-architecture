#if canImport(ComposableArchitectureMacros)
import ComposableArchitecture
import SwiftUI

@Reducer
private struct Feature_ViewAction {
  struct State {}
  enum Action: ViewAction {
    case view(View)
    enum View { case tap }
  }
  var body: some ReducerOf<Self> { EmptyReducer() }
}
@ViewAction(for: Feature_ViewAction.self)
private struct Feature_ViewAction_View: View {
  let store: StoreOf<Feature_ViewAction>
  var body: some View {
    Button("Tap") { send(.tap) }
    Button("Tap") { send(.tap, animation: .default) }
    Button("Tap") { send(.tap, transaction: Transaction(animation: .default)) }
  }
}
#endif
