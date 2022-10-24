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
  throttling and delaying), and they are typically difficult to test.

  This application has a simple side effect: tapping "Number fact" will trigger an API request to \
  load a piece of trivia about that number. This effect is handled by the reducer, and a full test \
  suite is written to confirm that the effect behaves in the way we expect.
  """

// MARK: - Feature domain

struct EffectsBasics: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var isNumberFactRequestInFlight = false
    var numberFact: String?
  }

  enum Action: Equatable {
    case decrementButtonTapped
    case decrementDelayResponse
    case incrementButtonTapped
    case numberFactButtonTapped
    case numberFactResponse(TaskResult<String>)
  }

  @Dependency(\.continuousClock) var clock
  @Dependency(\.factClient) var factClient
  private enum DelayID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .decrementButtonTapped:
      state.count -= 1
      state.numberFact = nil
      // Return an effect that re-increments the count after 1 second if the count is negative
      return state.count >= 0
        ? .none
        : .task {
          try await self.clock.sleep(for: .seconds(1))
          return .decrementDelayResponse
        }
        .cancellable(id: DelayID.self)

    case .decrementDelayResponse:
      if state.count < 0 {
        state.count += 1
      }
      return .none

    case .incrementButtonTapped:
      state.count += 1
      state.numberFact = nil
      return state.count >= 0
        ? .cancel(id: DelayID.self)
        : .none

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
      // NB: This is where we could handle the error is some way, such as showing an alert.
      state.isNumberFactRequestInFlight = false
      return .none
    }
  }
}

// MARK: - Feature view

struct EffectsBasicsView: View {
  let store: StoreOf<EffectsBasics>
  @Environment(\.openURL) var openURL

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Section {
          HStack {
            Button {
              viewStore.send(.decrementButtonTapped)
            } label: {
              Image(systemName: "minus")
            }

            Text("\(viewStore.count)")
              .monospacedDigit()

            Button {
              viewStore.send(.incrementButtonTapped)
            } label: {
              Image(systemName: "plus")
            }
          }
          .frame(maxWidth: .infinity)

          Button("Number fact") { viewStore.send(.numberFactButtonTapped) }
            .frame(maxWidth: .infinity)

          if viewStore.isNumberFactRequestInFlight {
            ProgressView()
              .frame(maxWidth: .infinity)
              // NB: There seems to be a bug in SwiftUI where the progress view does not show
              // a second time unless it is given a new identity.
              .id(UUID())
          }

          if let numberFact = viewStore.numberFact {
            Text(numberFact)
          }
        }

        Section {
          Button("Number facts provided by numbersapi.com") {
            self.openURL(URL(string: "http://numbersapi.com")!)
          }
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderless)
    }
    .navigationTitle("Effects")
  }
}

// MARK: - SwiftUI previews

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
