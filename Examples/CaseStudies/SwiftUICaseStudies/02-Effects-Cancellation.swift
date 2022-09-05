import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how one can cancel in-flight effects in the Composable Architecture.

  Use the stepper to count to a number, and then tap the "Number fact" button to fetch \
  a random fact about that number using an API.

  While the API request is in-flight, you can tap "Cancel" to cancel the effect and prevent \
  it from feeding data back into the application. Interacting with the stepper while a \
  request is in-flight will also cancel it.
  """

// MARK: - Demo app domain

struct EffectsCancellationState: Equatable {
  var count = 0
  var currentFact: String?
  var isFactRequestInFlight = false
}

enum EffectsCancellationAction: Equatable {
  case cancelButtonTapped
  case stepperChanged(Int)
  case factButtonTapped
  case factResponse(TaskResult<String>)
}

struct EffectsCancellationEnvironment {
  var fact: FactClient
}

// MARK: - Business logic

let effectsCancellationReducer = Reducer<
  EffectsCancellationState, EffectsCancellationAction, EffectsCancellationEnvironment
> { state, action, environment in

  enum NumberFactRequestID {}

  switch action {
  case .cancelButtonTapped:
    state.isFactRequestInFlight = false
    return .cancel(id: NumberFactRequestID.self)

  case let .stepperChanged(value):
    state.count = value
    state.currentFact = nil
    state.isFactRequestInFlight = false
    return .cancel(id: NumberFactRequestID.self)

  case .factButtonTapped:
    state.currentFact = nil
    state.isFactRequestInFlight = true

    return .task { [count = state.count] in
      await .factResponse(TaskResult { try await environment.fact.fetch(count) })
    }
    .cancellable(id: NumberFactRequestID.self)

  case let .factResponse(.success(response)):
    state.isFactRequestInFlight = false
    state.currentFact = response
    return .none

  case .factResponse(.failure):
    state.isFactRequestInFlight = false
    return .none
  }
}

// MARK: - Application view

struct EffectsCancellationView: View {
  let store: Store<EffectsCancellationState, EffectsCancellationAction>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Section {
          Stepper(
            "\(viewStore.count)",
            value: viewStore.binding(get: \.count, send: EffectsCancellationAction.stepperChanged)
          )

          if viewStore.isFactRequestInFlight {
            HStack {
              Button("Cancel") { viewStore.send(.cancelButtonTapped) }
              Spacer()
              ProgressView()
                // NB: There seems to be a bug in SwiftUI where the progress view does not show
                // a second time unless it is given a new identity.
                .id(UUID())
            }
          } else {
            Button("Number fact") { viewStore.send(.factButtonTapped) }
              .disabled(viewStore.isFactRequestInFlight)
          }

          viewStore.currentFact.map {
            Text($0).padding(.vertical, 8)
          }
        }

        Section {
          Button("Number facts provided by numbersapi.com") {
            UIApplication.shared.open(URL(string: "http://numbersapi.com")!)
          }
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderless)
    }
    .navigationTitle("Effect cancellation")
  }
}

// MARK: - SwiftUI previews

struct EffectsCancellation_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EffectsCancellationView(
        store: Store(
          initialState: EffectsCancellationState(),
          reducer: effectsCancellationReducer,
          environment: EffectsCancellationEnvironment(
            fact: .live
          )
        )
      )
    }
  }
}
