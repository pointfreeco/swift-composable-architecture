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
  var count = 50_000
  var isNumberFactRequestInFlight = false
  var isTimerRunning = false
  var nthPrimeProgress: Double?
  var numberFact: String?
}

enum EffectsBasicsAction: Equatable {
  case decrementButtonTapped
  case decrementDelayResponse
  case incrementButtonTapped
  case nthPrime(NthPrimeAction)
  case nthPrimeButtonTapped
  case numberFactButtonTapped
  case numberFactResponse(Result<String, FactClient.Failure>)
  case startTimerButtonTapped
  case stopTimerButtonTapped
  case task
  case timerTick

  enum NthPrimeAction: Equatable {
    case progress(Double)
    case response(Int)
  }
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
  enum DelayID {}

  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    state.numberFact = nil
    return state.count >= 0
    ? .none
    : .task {
//      try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
      print("Task started")
      try? await environment.mainQueue.sleep(for: .seconds(1))
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

  case .task:
    return nthPrime(number: state.count)

  case .nthPrimeButtonTapped:
    return nthPrime(number: state.count)

  case let .nthPrime(.progress(progress)):
    state.nthPrimeProgress = progress
    return .none

  case let .nthPrime(.response(answer)):
    state.numberFact = "The \(state.count)th prime is \(answer)."
    state.nthPrimeProgress = nil
    return .none

  case .numberFactButtonTapped:
    state.isNumberFactRequestInFlight = true
    state.numberFact = nil
    // Return an effect that fetches a number fact from the API and returns the
    // value back to the reducer's `numberFactResponse` action.

    return .task { [count = state.count] in
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

  case .startTimerButtonTapped:
    state.isTimerRunning = true

    return .run { send in
      var count = 0
      while true {
        try? await environment.mainQueue.sleep(
          for: .milliseconds(max(10, 1000 - count * 50))
        )
        await send(.timerTick)
        count += 1
      }
    }
    .cancellable(id: TimerID.self)

  case .stopTimerButtonTapped:
    state.isTimerRunning = false
    return .cancel(id: TimerID.self)

  case .timerTick:
    state.count += 1
    return .none
  }

  enum TimerID {}
}
.debug()


private func isPrime(_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
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
          if viewStore.isTimerRunning {
            Button("Stop timer") {
              viewStore.send(.stopTimerButtonTapped)
            }
            .frame(maxWidth: .infinity)
          } else {
            Button("Start timer") {
              viewStore.send(.startTimerButtonTapped)
            }
            .frame(maxWidth: .infinity)
          }
        }

        Section {
          Button("Compute \(viewStore.count)th prime") {
            viewStore.send(.nthPrimeButtonTapped)
          }
          .frame(maxWidth: .infinity)

          if let nthPrimeProgress = viewStore.nthPrimeProgress {
            ProgressView(value: nthPrimeProgress)
              .progressViewStyle(.linear)
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
      .task {
        await viewStore.send(.task)
        print("Done!")
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
          initialState: EffectsBasicsState(count: 50_000),
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

extension Effect where Failure == Never {
  public static func run(
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable (_ send: Send<Output>) async throws -> Void,
    catching: (@Sendable (Error, Send<Output>) async -> Void)? = nil
  ) -> Self {
    .run { subscriber in
      let task = Task(priority: priority) { @MainActor in
        let send = Send(send: { subscriber.send($0) })
        do {
          try await operation(send)
        } catch {
          // TODO: runtimeWarning if `catching` is nil and error is not CancellationError
          await catching?(error, send)
        }
        subscriber.send(completion: .finished)
      }
      return AnyCancellable {
        task.cancel()
      }
    }
  }
}


@MainActor
public struct Send<Action> {
  fileprivate let send: @Sendable (Action) -> Void

  public func callAsFunction(_ action: Action) {
    self.send(action)
  }

  public func callAsFunction(_ action: Action, animation: Animation? = nil) {
    withAnimation(animation) {
      self.send(action)
    }
  }
}

extension Send: Sendable where Action: Sendable {}

extension Scheduler {
  public func sleep(
    for duration: SchedulerTimeType.Stride
  ) async throws {
    await withUnsafeContinuation { continuation in
      self.schedule(after: self.now.advanced(by: duration)) {
        continuation.resume()
      }
    }
    try Task.checkCancellation()
  }
}

func nthPrime(number: Int) -> Effect<EffectsBasicsAction, Never> {
  .run { send in
    var primeCount = 0
    var prime = 2
    while primeCount < number {
      guard !Task.isCancelled
      else { return }

      defer { prime += 1 }
      if isPrime(prime) {
        primeCount += 1
      } else if prime.isMultiple(of: 1_000) {
        await send(.nthPrime(.progress(Double(primeCount) / Double(number))), animation: .default)
        await Task.yield()
      }
    }
    await send(.nthPrime(.response(prime - 1)), animation: .default)
  }
}
