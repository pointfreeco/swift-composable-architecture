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

struct BindingForm: ReducerProtocol {
  struct State: Equatable {
    @BindableState var sliderValue = 5.0
    @BindableState var stepCount = 10
    @BindableState var text = ""
    @BindableState var toggleIsOn = false
  }

  enum Action: BindableAction, Equatable {
    case binding(BindingAction<State>)
    case resetButtonTapped
  }

  var body: some ReducerProtocol<State, Action> {
    Reduce { state, action in
      switch action {
      case .binding(\.$stepCount):
        state.sliderValue = .minimum(state.sliderValue, Double(state.stepCount))
        return .none

      case .binding:
        return .none

      case .resetButtonTapped:
        state = State()
        return .none
      }
    }
    .binding()
  }
}

struct BindingFormView: View {
  let store: StoreOf<BindingForm>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        HStack {
          TextField("Type here", text: viewStore.binding(\.$text))
            .disableAutocorrection(true)
            .foregroundColor(viewStore.toggleIsOn ? .gray : .primary)

          Text(alternate(viewStore.text))
        }
        .disabled(viewStore.toggleIsOn)

        Toggle(
          "Disable other controls",
          isOn: viewStore.binding(\.$toggleIsOn)
            .resignFirstResponder()
        )

        Stepper(value: viewStore.binding(\.$stepCount), in: 0...100) {
          Text("Max slider value: \(viewStore.stepCount)")
            .font(.body.monospacedDigit())
        }
        .disabled(viewStore.toggleIsOn)

        HStack {
          Text("Slider value: \(Int(viewStore.sliderValue))")
            .font(.body.monospacedDigit())

          Slider(value: viewStore.binding(\.$sliderValue), in: 0...Double(viewStore.stepCount))
        }
        .disabled(viewStore.toggleIsOn)

        Button("Reset") {
          viewStore.send(.resetButtonTapped)
        }
        .foregroundColor(.red)
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
          initialState: BindingForm.State(),
          reducer: BindingForm()
        )
      )
    }
  }
}
