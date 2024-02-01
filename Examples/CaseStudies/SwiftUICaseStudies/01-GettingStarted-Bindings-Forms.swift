import ComposableArchitecture
import SwiftUI

private let readMe = """
  This file demonstrates how to handle two-way bindings in the Composable Architecture using \
  bindable actions and binding reducers.

  Bindable actions allow you to safely eliminate the boilerplate caused by needing to have a \
  unique action for every UI control. Instead, all UI bindings can be consolidated into a single \
  `binding` action, which the `BindingReducer` can automatically apply to state.

  It is instructive to compare this case study to the "Binding Basics" case study.
  """

@Reducer
struct BindingForm {
  @ObservableState
  struct State: Equatable {
    var sliderValue = 5.0
    var stepCount = 10
    var text = ""
    var toggleIsOn = false
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case resetButtonTapped
  }

  var body: some Reducer<State, Action> {
    BindingReducer()
    Reduce { state, action in
      switch action {
      case .binding(\.stepCount):
        state.sliderValue = .minimum(state.sliderValue, Double(state.stepCount))
        return .none

      case .binding:
        return .none

      case .resetButtonTapped:
        state = State()
        return .none
      }
    }
  }
}

struct BindingFormView: View {
  @Bindable var store: StoreOf<BindingForm>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        TextField("Type here", text: $store.text)
          .disableAutocorrection(true)
          .foregroundStyle(store.toggleIsOn ? Color.secondary : .primary)
        Text(alternate(store.text))
      }
      .disabled(store.toggleIsOn)

      Toggle("Disable other controls", isOn: $store.toggleIsOn.resignFirstResponder())

      Stepper(
        "Max slider value: \(store.stepCount)",
        value: $store.stepCount,
        in: 0...100
      )
      .disabled(store.toggleIsOn)

      HStack {
        Text("Slider value: \(Int(store.sliderValue))")

        Slider(value: $store.sliderValue, in: 0...Double(store.stepCount))
          .tint(.accentColor)
      }
      .disabled(store.toggleIsOn)

      Button("Reset") {
        store.send(.resetButtonTapped)
      }
      .tint(.red)
    }
    .monospacedDigit()
    .navigationTitle("Bindings form")
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
    BindingFormView(
      store: Store(initialState: BindingForm.State()) {
        BindingForm()
      }
    )
  }
}
