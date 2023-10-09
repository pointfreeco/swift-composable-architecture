import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to show and hide views based on the presence of some optional child \
  state.

  The parent state holds a `CounterState?` value. When it is `nil` we will default to a plain text \
  view. But when it is non-`nil` we will show a view fragment for a counter that operates on the \
  non-optional counter state.

  Tapping "Toggle counter state" will flip between the `nil` and non-`nil` counter states.
  """

// MARK: - Feature domain

struct OptionalBasics: Reducer {
  @ObservableState
  struct State: Equatable {
    var optionalCounter: Counter.State?
  }

  enum Action: Equatable {
    case optionalCounter(Counter.Action)
    case toggleCounterButtonTapped
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .toggleCounterButtonTapped:
        state.optionalCounter =
          state.optionalCounter == nil
          ? Counter.State()
          : nil
        return .none
      case .optionalCounter:
        return .none
      }
    }
    .ifLet(\.optionalCounter, action: /Action.optionalCounter) {
      Counter()
    }
  }
}

// MARK: - Feature view

struct OptionalBasicsView: View {
  @State var isObservingCount = false
  let store: StoreOf<OptionalBasics>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        Button("Toggle counter state") {
          self.store.send(.toggleCounterButtonTapped)
        }
      }

      Section {
        if self.isObservingCount {
          if let count = self.store.optionalCounter?.count {
            Text("From parent: \(count)")
          }
        }
        Toggle(isOn: self.$isObservingCount) {
          Text("Observe count?")
        }
      }

      Section {
        IfLetStore(
          self.store.scope(state: \.optionalCounter, action: { .optionalCounter($0) })
        ) { store in
          Text(template: "`CounterState` is non-`nil`")
          CounterView(store: store)
            .buttonStyle(.borderless)
            .frame(maxWidth: .infinity)
        } else: {
          Text(template: "`CounterState` is `nil`")
        }
      }
    }
    .navigationTitle("Optional state")
  }
}

// MARK: - SwiftUI previews

struct OptionalBasicsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      NavigationView {
        OptionalBasicsView(
          store: Store(initialState: OptionalBasics.State()) {
            OptionalBasics()
          }
        )
      }

      NavigationView {
        OptionalBasicsView(
          store: Store(
            initialState: OptionalBasics.State(optionalCounter: Counter.State(count: 42))
          ) {
            OptionalBasics()
          }
        )
      }
    }
  }
}
