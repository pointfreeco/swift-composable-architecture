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

  Any SwiftUI component that requires a Binding to do its job can be used in the Composable \
  Architecture. You can derive a Binding from your ViewStore by using the `binding` method. This \
  will allow you to specify what state renders the component, and what action to send when the \
  component changes, which means you can keep using a unidirectional style for your feature.
  """

// MARK: - Feature domain

struct BindingBasics: ReducerProtocol {
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

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
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

// MARK: - Feature view

struct BindingBasicsView: View {
  let store: StoreOf<BindingBasics>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        HStack {
          TextField(
            "Type here",
            text: viewStore.binding(get: \.text, send: BindingBasics.Action.textChanged)
          )
          .disableAutocorrection(true)
          .foregroundStyle(viewStore.toggleIsOn ? Color.secondary : .primary)
          Text(alternate(viewStore.text))
        }
        .disabled(viewStore.toggleIsOn)

        Toggle(
          "Disable other controls",
          isOn: viewStore.binding(get: \.toggleIsOn, send: BindingBasics.Action.toggleChanged)
            .resignFirstResponder()
        )

        Stepper(
          "Max slider value: \(viewStore.stepCount)",
          value: viewStore.binding(get: \.stepCount, send: BindingBasics.Action.stepCountChanged),
          in: 0...100
        )
        .disabled(viewStore.toggleIsOn)

        HStack {
          Text("Slider value: \(Int(viewStore.sliderValue))")
          Slider(
            value: viewStore.binding(
              get: \.sliderValue,
              send: BindingBasics.Action.sliderValueChanged
            ),
            in: 0...Double(viewStore.stepCount)
          )
          .tint(.accentColor)
        }
        .disabled(viewStore.toggleIsOn)
      }
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

// MARK: - SwiftUI previews

struct BindingBasicsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      BindingBasicsView(
        store: Store(
          initialState: BindingBasics.State(),
          reducer: BindingBasics()
        )
      )
    }
  }
}
