import ComposableArchitecture
import SwiftUI

private let readMe = """
  This file demonstrates how to handle two-way bindings in the Composable Architecture using \
  binding actions.

  Binding actions allow you to eliminate the boilerplate caused by needing to have a unique action \
  for every UI control. Instead, all UI bindings can be consolidated into a single `binding` \
  action that holds onto a `BindingAction` value.

  It is instructive to compare this case study to the "Binding Basics" case study.
  """

// The state for this screen holds a bunch of values that will drive
struct BindingFormState: Equatable {
  var sliderValue = 5.0
  var stepCount = 10
  var text = ""
  var toggleIsOn = false
}

enum BindingFormAction: Equatable {
  case binding(BindingAction<BindingFormState>)
  case resetButtonTapped
}

struct BindingFormEnvironment {}

let bindingFormReducer = Reducer<
  BindingFormState, BindingFormAction, BindingFormEnvironment
> {
  state, action, _ in
  switch action {
  case .binding(\.stepCount):
    state.sliderValue = .minimum(state.sliderValue, Double(state.stepCount))
    return .none

  case .binding:
    return .none

  case .resetButtonTapped:
    state = .init()
    return .none
  }
}
.binding(action: /BindingFormAction.binding)

struct BindingFormView: View {
  let store: Store<BindingFormState, BindingFormAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(template: readMe, .caption)) {
          HStack {
            TextField(
              "Type here",
              text: viewStore.binding(keyPath: \.text, send: BindingFormAction.binding)
            )
            .disableAutocorrection(true)
            .foregroundColor(viewStore.toggleIsOn ? .gray : .primary)
            Text(alternate(viewStore.text))
          }
          .disabled(viewStore.toggleIsOn)

          Toggle(isOn: viewStore.binding(keyPath: \.toggleIsOn, send: BindingFormAction.binding)) {
            Text("Disable other controls")
          }

          Stepper(
            value: viewStore.binding(keyPath: \.stepCount, send: BindingFormAction.binding),
            in: 0...100
          ) {
            Text("Max slider value: \(viewStore.stepCount)")
              .font(Font.body.monospacedDigit())
          }
          .disabled(viewStore.toggleIsOn)

          HStack {
            Text("Slider value: \(Int(viewStore.sliderValue))")
              .font(Font.body.monospacedDigit())
            Slider(
              value: viewStore.binding(keyPath: \.sliderValue, send: BindingFormAction.binding),
              in: 0...Double(viewStore.stepCount)
            )
          }
          .disabled(viewStore.toggleIsOn)
        }
      }
    }
    .navigationBarTitle("Bindings form")
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
