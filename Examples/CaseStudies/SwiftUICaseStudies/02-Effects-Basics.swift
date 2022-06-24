import Combine
import ComposableArchitecture
import SwiftUI

func equals(_ lhs: Any, _ rhs: Any) -> Bool {
  func open<A: Equatable>(_ lhs: A, _ rhs: any Equatable) -> Bool {
    lhs == (rhs as? A)
  }

  guard
    let lhs = lhs as? any Equatable,
    let rhs = rhs as? any Equatable
  else { return false }

  return open(lhs, rhs)
}
public enum TaskResult<Success: Sendable>: Sendable {
  case success(Success)
  case failure(Error)


  init(catching body: @Sendable () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
}
extension TaskResult: Equatable where Success: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
      return lhs == rhs
    case let (.failure(lhs), .failure(rhs)):
      return equals(lhs, rhs)
    default:
      return false
    }
  }
}




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

// MARK: - Feature domain

struct EffectsBasicsState: Equatable {
  var count = 0
  var isNumberFactRequestInFlight = false
  var numberFact: String?
}

enum EffectsBasicsAction: Equatable {
  case decrementButtonTapped
  case delayedDecrementButtonTapped
  case incrementButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(TaskResult<String>)
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
  struct DelayID {}

  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    state.numberFact = nil
    return state.count >= 0
    ? .none
    : .task {
      try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
      return .delayedDecrementButtonTapped
    }
    .cancellable(id: DelayID.self)

  case .delayedDecrementButtonTapped:
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
      await .numberFactResponse(TaskResult { try await environment.fact.fetchAsync(count) })
    }

  case let .numberFactResponse(.success(response)):
    state.isNumberFactRequestInFlight = false
    state.numberFact = response
    return .none

  case .numberFactResponse(.failure):
    // TODO: error handling
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
//        Section {
//          Text(readMe)
//        }

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
        }

        Section {
          if viewStore.isNumberFactRequestInFlight {
            ProgressView()
              .frame(maxWidth: .infinity)
              .id(UUID()) // TODO: Progress view doesn't show a second time without this?
          }
          if let fact = viewStore.numberFact {
            Text(fact)
          }
        } footer: {
          Button("Number facts provided by numbersapi.com") {
            UIApplication.shared.open(URL(string: "http://numbersapi.com")!)
          }
          .frame(maxWidth: .infinity)
          .foregroundColor(.gray)
        }
      }
    }
    .navigationBarTitle("Effect basics")
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
