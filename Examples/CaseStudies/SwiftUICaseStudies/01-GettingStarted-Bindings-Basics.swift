import ComposableArchitecture
import SwiftUI

private let readMe = """
  This file demonstrates how to handle two-way bindings in the Composable Architecture.

  Two-way bindings in SwiftUI are powerful, but also go against the grain of the "unidirectional \
  data flow" of the Composable Architecture. This is because anything can mutate the value \
  whenever it wants.

  On the other hand, the Composable Architecture demands that mutations can only happen by sending \
  actions to the store, and this means there is only ever one place to see how the state of our \
  feature evolves, which is the reducer.

  Any SwiftUI component that requires a binding to do its job can be used in the Composable \
  Architecture. You can derive a binding from a store by taking a bindable store, chaining into a \
  property of state that renders the component, and calling the `sending` method with a key path \
  to an action to send when the component changes, which means you can keep using a unidirectional \
  style for your feature.
  """

@Reducer
struct BindingBasics {
  @ObservableState
  struct State: Equatable {
    var sliderValue = 5.0
    var stepCount = 10
    var text = ""
    var toggleIsOn = false
  }

  enum Action {
    case sliderValueChanged(Double)
    case stepCountChanged(Int)
    case textChanged(String)
    case toggleChanged(isOn: Bool)
  }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case let .sliderValueChanged(value):
        state.sliderValue = value
        return .none

      case let .stepCountChanged(count):
        state.sliderValue = .minimum(state.sliderValue, Double(count))
        state.stepCount = count
        return .none

      case let .textChanged(text):
        state.text = text
        return .none

      case let .toggleChanged(isOn):
        state.toggleIsOn = isOn
        return .none
      }
    }
  }
}

struct BindingBasicsView: View {
  @Bindable var store: StoreOf<BindingBasics>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        TextField("Type here", text: $store.text.sending(\.textChanged))
          .disableAutocorrection(true)
          .foregroundStyle(store.toggleIsOn ? Color.secondary : .primary)
        Text(alternate(store.text))
      }
      .disabled(store.toggleIsOn)

      Toggle(
        "Disable other controls",
        isOn: $store.toggleIsOn.sending(\.toggleChanged).resignFirstResponder()
      )

      Stepper(
        "Max slider value: \(store.stepCount)",
        value: $store.stepCount.sending(\.stepCountChanged),
        in: 0...100
      )
      .disabled(store.toggleIsOn)

      HStack {
        Text("Slider value: \(Int(store.sliderValue))")
        Slider(
          value: $store.sliderValue.sending(\.sliderValueChanged),
          in: 0...Double(store.stepCount)
        )
        .tint(.accentColor)
      }
      .disabled(store.toggleIsOn)
    }
    .monospacedDigit()
    .navigationTitle("Bindings basics")
  }
}

private func alternate(_ string: String) -> String {
  string
    .enumerated()
    .map { idx, char in
      idx.isMultiple(of: 2)
        ? char.uppercased()
        : char.lowercased()
    }
    .joined()
}

#Preview {
  NavigationStack {
    BindingBasicsView(
      store: Store(initialState: BindingBasics.State()) {
        BindingBasics()
      }
    )
  }
}
