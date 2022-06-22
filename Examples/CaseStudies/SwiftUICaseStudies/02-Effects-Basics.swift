import Combine
import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to introduce side effects into a feature built with the \
  Composable Architecture.

  A side effect is a unit of work that needs to be performed in the outside world. For example, an \
  API request needs to reach an external service over HTTP, which brings with it lots of \
  uncertainty and complexity.

  Many things we do in our applications involve side effects, such as timers, database requests, \
  file access, socket connections, and anytime a scheduler is involved (such as debouncing, \
  throttling and delaying), and they are typically difficult to test.

  This application has two simple side effects:

  • Each time you count down the number will be incremented back up after a delay of 1 second.
  • Tapping "Number fact" will trigger an API request to load a piece of trivia about that number.

  Both effects are handled by the reducer, and a full test suite is written to confirm that the \
  effects behave in the way we expect.
  """

struct EffectsBasics: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var isNumberFactRequestInFlight = false
    var numberFact: String?
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case incrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(TaskResult<String>)
  }

  @Dependency(\.factClient) var factClient
  @Dependency(\.mainQueue) var mainQueue
  @Dependency(\.isTesting) var isTesting

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      state.numberFact = nil
      // Return an effect that re-increments the count after 1 second.
      return .task {
        try? await self.mainQueue.sleep(for: 1)
        return .incrementButtonTapped
      }

    case .incrementButtonTapped:
      state.count += 1
      state.numberFact = nil
      return .none

    case .numberFactButtonTapped:
      state.isNumberFactRequestInFlight = true
      state.numberFact = nil
      // Return an effect that fetches a number fact from the API and returns the
      // value back to the reducer's `numberFactResponse` action.
      return .task { [count = state.count] in
        await .numberFactResponse(TaskResult { try await self.factClient.fetch(count) })
      }

    case let .numberFactResponse(.success(response)):
      state.isNumberFactRequestInFlight = false
      state.numberFact = response
      return .none

    case .numberFactResponse(.failure):
      state.isNumberFactRequestInFlight = false
      return .none
    }
  }
}

// MARK: - Feature view

struct EffectsBasicsView: View {
  let store: Store<EffectsBasics.State, EffectsBasics.Action>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(readMe)) {
          EmptyView()
        }

        Section(
          footer: Button("Number facts provided by numbersapi.com") {
            UIApplication.shared.open(URL(string: "http://numbersapi.com")!)
          }
        ) {
          HStack {
            Spacer()
            Button("−") { viewStore.send(.decrementButtonTapped) }
            Text("\(viewStore.count)")
              .font(.body.monospacedDigit())
            Button("+") { viewStore.send(.incrementButtonTapped) }
            Spacer()
          }
          .buttonStyle(.borderless)

          Button("Number fact") { viewStore.send(.numberFactButtonTapped) }
          if viewStore.isNumberFactRequestInFlight {
            ProgressView()
          }

          if let numberFact = viewStore.numberFact {
            Text(numberFact)
          }
        }
      }
    }
    .navigationBarTitle("Effects")
  }
}

// MARK: - Feature SwiftUI previews

struct EffectsBasicsView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      EffectsBasicsView(
        store: Store(
          initialState: EffectsBasics.State(),
          reducer: EffectsBasics()
        )
      )
    }
  }
}
