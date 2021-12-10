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
  var currentTrivia: String?
  var isTriviaRequestInFlight = false
}

enum EffectsCancellationAction: Equatable {
  case cancelButtonTapped
  case stepperChanged(Int)
  case triviaButtonTapped
  case triviaResponse(Result<String, FactClient.Error>)
}

struct EffectsCancellationEnvironment {
  var fact: FactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

// MARK: - Business logic

let effectsCancellationReducer = Reducer<
  EffectsCancellationState, EffectsCancellationAction, EffectsCancellationEnvironment
> { state, action, environment in

  struct TriviaRequestId: Hashable {}

  switch action {
  case .cancelButtonTapped:
    state.isTriviaRequestInFlight = false
    return .cancel(id: TriviaRequestId())

  case let .stepperChanged(value):
    state.count = value
    state.currentTrivia = nil
    state.isTriviaRequestInFlight = false
    return .cancel(id: TriviaRequestId())

  case .triviaButtonTapped:
    state.currentTrivia = nil
    state.isTriviaRequestInFlight = true

    return environment.fact.fetch(state.count)
      .receive(on: environment.mainQueue)
      .catchToEffect(EffectsCancellationAction.triviaResponse)
      .cancellable(id: TriviaRequestId())

  case let .triviaResponse(.success(response)):
    state.isTriviaRequestInFlight = false
    state.currentTrivia = response
    return .none

  case .triviaResponse(.failure):
    state.isTriviaRequestInFlight = false
    return .none
  }
}

// MARK: - Application view

struct EffectsCancellationView: View {
  let store: Store<EffectsCancellationState, EffectsCancellationAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(
          header: Text(readMe),
          footer: Button("Number facts provided by numbersapi.com") {
            UIApplication.shared.open(URL(string: "http://numbersapi.com")!)
          }
        ) {
          Stepper(
            value: viewStore.binding(
              get: \.count, send: EffectsCancellationAction.stepperChanged)
          ) {
            Text("\(viewStore.count)")
          }

          if viewStore.isTriviaRequestInFlight {
            HStack {
              Button("Cancel") { viewStore.send(.cancelButtonTapped) }
              Spacer()
              ProgressView()
            }
          } else {
            Button("Number fact") { viewStore.send(.triviaButtonTapped) }
              .disabled(viewStore.isTriviaRequestInFlight)
          }

          viewStore.currentTrivia.map {
            Text($0).padding(.vertical, 8)
          }
        }
      }
    }
    .navigationBarTitle("Effect cancellation")
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
            fact: .live,
            mainQueue: .main
          )
        )
      )
    }
  }
}
