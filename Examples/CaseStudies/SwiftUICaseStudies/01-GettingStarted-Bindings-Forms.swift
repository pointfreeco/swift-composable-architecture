import ComposableArchitecture
import SwiftUI

private let readMe = """
  This file demonstrates how to handle two-way bindings in the Composable Architecture using \
  bindable state and actions.

  Bindable state and actions allow you to safely eliminate the boilerplate caused by needing to \
  have a unique action for every UI control. Instead, all UI bindings can be consolidated into a \
  single `binding` action that holds onto a `BindingAction` value, and all bindable state can be \
  safeguarded with the `BindableState` property wrapper.

  It is instructive to compare this case study to the "Binding Basics" case study.
  """

// The state for this screen holds a bunch of values that will drive
struct BindingFormState: Equatable {
  @BindableState var sliderValue = 5.0
  @BindableState var stepCount = 10
  @BindableState var text = ""
  @BindableState var toggleIsOn = false
}

enum BindingFormAction: BindableAction, Equatable {
  case binding(BindingAction<BindingFormState>)
  case resetButtonTapped
}

struct BindingFormEnvironment {}

let bindingFormReducer = Reducer<
  BindingFormState, BindingFormAction, BindingFormEnvironment
> {
  state, action, _ in
  switch action {
  case .binding(\.$stepCount):
    state.sliderValue = .minimum(state.sliderValue, Double(state.stepCount))
    return .none

  case .binding:
    return .none

  case .resetButtonTapped:
    state = BindingFormState()
    return .none
  }
}
.binding()

struct BindingFormView: View {
  let store: Store<BindingFormState, BindingFormAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        HStack {
          TextField("Type here", text: viewStore.binding(\.$text))
            .disableAutocorrection(true)
            .foregroundStyle(viewStore.toggleIsOn ? Color.secondary : .primary)
          Text(alternate(viewStore.text))
        }
        .disabled(viewStore.toggleIsOn)

        Toggle(
          "Disable other controls",
          isOn: viewStore.binding(\.$toggleIsOn)
            .resignFirstResponder()
        )

        Stepper(
          "Max slider value: \(viewStore.stepCount)",
          value: viewStore.binding(\.$stepCount),
          in: 0...100
        )
        .disabled(viewStore.toggleIsOn)

        HStack {
          Text("Slider value: \(Int(viewStore.sliderValue))")

          Slider(value: viewStore.binding(\.$sliderValue), in: 0...Double(viewStore.stepCount))
            .tint(.accentColor)
        }
        .disabled(viewStore.toggleIsOn)

        Button("Reset") {
          viewStore.send(.resetButtonTapped)
        }
        .tint(.red)
      }
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

struct BindingFormView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      BindingFormView(
        store: Store(
          initialState: BindingFormState(),
          reducer: bindingFormReducer,
          environment: BindingFormEnvironment()
        )
      )
    }
  }
}
