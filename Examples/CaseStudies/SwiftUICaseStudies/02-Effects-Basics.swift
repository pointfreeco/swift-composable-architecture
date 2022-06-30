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

  This application has a simple side effect: tapping "Number fact" will trigger an API request to \
  load a piece of trivia about that number. This effect is handled by the reducer, and a full test \
  suite is written to confirm that the effect behaves in the way we expect.
  """

// MARK: - Feature domain

struct EffectsBasicsState: Equatable {
  var count = 0
  var isNumberFactRequestInFlight = false
  var numberFact: String?
}

enum EffectsBasicsAction: Equatable {
  case decrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(Result<String, FactClient.Failure>)
}

struct EffectsBasicsEnvironment {
  var fact: FactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

// MARK: - Feature business logic

let effectsBasicsReducer = Reducer<
  EffectsBasicsState,
  EffectsBasicsAction,
  EffectsBasicsEnvironment
> { state, action, environment in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    state.numberFact = nil
    return .none

  case .incrementButtonTapped:
    state.count += 1
    state.numberFact = nil
    return .none

  case .numberFactButtonTapped:
    state.isNumberFactRequestInFlight = true
    state.numberFact = nil
    // Return an effect that fetches a number fact from the API and returns the
    // value back to the reducer's `numberFactResponse` action.

    return Effect.task { [count = state.count] in
      do {
        return .numberFactResponse(
          .success(
            try await environment.fact.fetchAsync(count)
          )
        )
      } catch {
        return .numberFactResponse(.failure(FactClient.Failure()))
      }
    }

//    return environment.fact.fetch(state.count)
//      .map { fact in fact + "!!!" }
//      .receive(on: environment.mainQueue)
//      .catchToEffect(EffectsBasicsAction.numberFactResponse)

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

// MARK: - Feature view

struct EffectsBasicsView: View {
  let store: Store<EffectsBasicsState, EffectsBasicsAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section {
          AboutView(readMe: readMe)
        }

        Section {
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
            UIApplication.shared.open(URL(string: "http://numbersapi.com")!)
          }
          .foregroundColor(.gray)
          .frame(maxWidth: .infinity)
        }
      }
      .buttonStyle(.borderless)
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
          initialState: EffectsBasicsState(),
          reducer: effectsBasicsReducer,
          environment: EffectsBasicsEnvironment(
            fact: .live,
            mainQueue: .main
          )
        )
      )
    }
  }
}
