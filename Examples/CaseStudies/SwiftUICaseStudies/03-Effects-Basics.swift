import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how to introduce side effects into a feature built with the \
  Composable Architecture.

  A side effect is a unit of work that needs to be performed in the outside world. For example, an \
  API request needs to reach an external service over HTTP, which brings with it lots of \
  uncertainty and complexity.

  Many things we do in our applications involve side effects, such as timers, database requests, \
  file access, socket connections, and anytime a clock is involved (such as debouncing, \
  throttling, and delaying), and they are typically difficult to test.

  This application has a simple side effect: tapping "Number fact" will trigger an API request to \
  load a piece of trivia about that number. This effect is handled by the reducer, and a full test \
  suite is written to confirm that the effect behaves in the way we expect.
  """

@Reducer
struct EffectsBasics {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var isNumberFactRequestInFlight = false
    var numberFact: String?
  }

  enum Action {
    case decrementButtonTapped
    case decrementDelayResponse
    case incrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(Result<String, Error>)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.factClient) var factClient
  private enum CancelID { case delay }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1
        state.numberFact = nil
        // Return an effect that re-increments the count after 1 second if the count is negative
        return state.count >= 0
          ? .none
          : .run { send in
            try await self.clock.sleep(for: .seconds(1))
            await send(.decrementDelayResponse)
          }
          .cancellable(id: CancelID.delay)

      case .decrementDelayResponse:
        if state.count < 0 {
          state.count += 1
        }
        return .none

      case .incrementButtonTapped:
        state.count += 1
        state.numberFact = nil
        return state.count >= 0
          ? .cancel(id: CancelID.delay)
          : .none

      case .numberFactButtonTapped:
        state.isNumberFactRequestInFlight = true
        state.numberFact = nil
        // Return an effect that fetches a number fact from the API and returns the
        // value back to the reducer's `numberFactResponse` action.
        return .run { [count = state.count] send in
          await send(.numberFactResponse(Result { try await self.factClient.fetch(count) }))
        }

      case let .numberFactResponse(.success(response)):
        state.isNumberFactRequestInFlight = false
        state.numberFact = response
        return .none

      case .numberFactResponse(.failure):
        // NB: This is where we could handle the error is some way, such as showing an alert.
        state.isNumberFactRequestInFlight = false
        return .none
      }
    }
  }
}

struct EffectsBasicsView: View {
  let store: StoreOf<EffectsBasics>
  @Environment(\.openURL) var openURL

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        HStack {
          Button {
            store.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(store.count)")
            .monospacedDigit()

          Button {
            store.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
        .frame(maxWidth: .infinity)

        Button("Number fact") { store.send(.numberFactButtonTapped) }
          .frame(maxWidth: .infinity)

        if store.isNumberFactRequestInFlight {
          ProgressView()
            .frame(maxWidth: .infinity)
            // NB: There seems to be a bug in SwiftUI where the progress view does not show
            // a second time unless it is given a new identity.
            .id(UUID())
        }

        if let numberFact = store.numberFact {
          Text(numberFact)
        }
      }

      Section {
        Button("Number facts provided by numbersapi.com") {
          openURL(URL(string: "http://numbersapi.com")!)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Effects")
  }
}

#Preview {
  NavigationStack {
    EffectsBasicsView(
      store: Store(initialState: EffectsBasics.State()) {
        EffectsBasics()
      }
    )
  }
}
