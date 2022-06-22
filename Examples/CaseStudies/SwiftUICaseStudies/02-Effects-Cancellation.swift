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

struct EffectsCancellation: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var currentTrivia: String?
    var isTriviaRequestInFlight = false
  }

  enum Action: Equatable {
    case cancelButtonTapped
    case stepperChanged(Int)
    case triviaButtonTapped
    case triviaResponse(TaskResult<String>)
  }

  @Dependency(\.factClient) var factClient
  @Dependency(\.mainQueue) var mainQueue

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    enum TriviaRequestId {}

    switch action {
    case .cancelButtonTapped:
      state.isTriviaRequestInFlight = false
      return .cancel(id: TriviaRequestId.self)

    case let .stepperChanged(value):
      state.count = value
      state.currentTrivia = nil
      state.isTriviaRequestInFlight = false
      return .cancel(id: TriviaRequestId.self)

    case .triviaButtonTapped:
      state.currentTrivia = nil
      state.isTriviaRequestInFlight = true

      return .task { [count = state.count] in
        await .triviaResponse(TaskResult { try await self.factClient.fetch(count) })
      }
      .cancellable(id: TriviaRequestId.self)

    case let .triviaResponse(.success(response)):
      state.isTriviaRequestInFlight = false
      state.currentTrivia = response
      return .none

    case .triviaResponse(.failure):
      state.isTriviaRequestInFlight = false
      return .none
    }
  }
}

// MARK: - Application view

struct EffectsCancellationView: View {
  let store: StoreOf<EffectsCancellation>

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
            value: viewStore.binding(get: \.count, send: EffectsCancellation.Action.stepperChanged)
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
          initialState: EffectsCancellation.State(),
          reducer: EffectsCancellation()
        )
      )
    }
  }
}
