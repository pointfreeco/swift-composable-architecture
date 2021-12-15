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
  case numberFactResponse(TaskResult<String>)
}

struct AsyncFactClient {
  var fetch: (Int) async throws -> String
}

extension AsyncFactClient {
  static let live = Self { number in
    let (data, _) = try await URLSession.shared
      .data(from: URL(string: "http://numbersapi.com/\(number)/trivia")!)
    return String(decoding: data, as: UTF8.self)
  }
}

struct EffectsBasicsEnvironment {
  var fact: AsyncFactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

// MARK: - Feature business logic

extension Scheduler {
  func sleep(_ duration: SchedulerTimeType.Stride) async {
    await withUnsafeContinuation { continuation in
      self.schedule(
        after: self.now.advanced(by: duration),
        continuation.resume
      )
    }
  }
}

enum Box<T> {}

protocol AnyEquatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
}

extension Box: AnyEquatable where T: Equatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    lhs as? T == rhs as? T
  }
}

func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
  func open<LHS>(_: LHS.Type) -> Bool? {
    (Box<LHS>.self as? AnyEquatable.Type)?.isEqual(lhs, rhs)
  }
  return _openExistential(type(of: lhs), do: open) ?? false
}

enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

  public init(catching body: () async throws -> Success) async {
    do {
      self = .success(try await body())
    } catch {
      self = .failure(error)
    }
  }
}

extension TaskResult: Equatable where Success: Equatable {
  static func == (lhs: Self, rhs: Self) -> Bool {
    switch (lhs, rhs) {
    case let (.success(lhs), .success(rhs)):
      return lhs == rhs
    case let (.failure(lhs), .failure(rhs)):
      return isEqual(lhs, rhs)
    case (.success, .failure), (.failure, .success):
      return false
    }
  }
}

let effectsBasicsReducer = Reducer<
  EffectsBasicsState, EffectsBasicsAction, EffectsBasicsEnvironment
> { state, action, environment in
  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    state.numberFact = nil
    // Return an effect that re-increments the count after 1 second.
//    return Effect(value: EffectsBasicsAction.incrementButtonTapped)
//      .delay(for: 1, scheduler: environment.mainQueue)
//      .eraseToEffect()
    return .task { @MainActor in
      await environment.mainQueue.sleep(.seconds(1))
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
    return .task { @MainActor [count = state.count] in
      await .numberFactResponse(.init { try await environment.fact.fetch(count) })
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

// MARK: - Feature view

struct EffectsBasicsView: View {
  let store: Store<EffectsBasicsState, EffectsBasicsAction>

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

          viewStore.numberFact.map(Text.init)
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
