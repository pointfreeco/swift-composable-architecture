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
  var isTimerRunning = false
  var nthPrimeProgress: Double?
  var numberFact: String?
}

enum EffectsBasicsAction: Equatable {
  case decrementButtonTapped
  case decrementDelayResponse
  case incrementButtonTapped
  case nthPrimeButtonTapped
  case nthPrimeProgress(Double)
  case nthPrimeResponse(Int)
  case numberFactButtonTapped
  case numberFactResponse(TaskResult<String>)
  case startTimerButtonTapped
  case stopTimerButtonTapped
  case timerTick
}

struct EffectsBasicsEnvironment {
  var fact: FactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

// MARK: - Feature business logic

extension Scheduler {
  func sleep(
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

@MainActor
struct Send<Action> {
  let send: (Action) -> Void

  func callAsFunction(_ action: Action) {
    self.send(action)
  }
  func callAsFunction(_ action: Action, animation: Animation?) {
    withAnimation(animation) {
      self.send(action)
    }
  }
}

extension Effect {
  static func run(
    operation: @escaping @Sendable (_ send: Send<Output>) async -> Void
  ) -> Self {
    .run { subscriber in
      let task = Task { @MainActor in
        await operation(Send { subscriber.send($0) })
        subscriber.send(completion: .finished)
      }
      return AnyCancellable {
        task.cancel()
      }
    }
  }
}

let effectsBasicsReducer = Reducer<
  EffectsBasicsState,
  EffectsBasicsAction,
  EffectsBasicsEnvironment
> { state, action, environment in
  enum DelayID {}
  enum TimerID {}

  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    state.numberFact = nil
    return state.count >= 0
    ? .none
//    : Effect(value: .decrementDelayResponse)
//      .delay(for: 1, scheduler: environment.mainQueue)
//      .eraseToEffect()
//      .cancellable(id: DelayID.self)
    : .task {
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

  case .nthPrimeButtonTapped:
    return .run { [count = state.count] send in
      var primeCount = 0
      var prime = 2
      while primeCount < count {

        defer { prime += 1 }
        if isPrime(prime) {
          primeCount += 1
        } else if prime.isMultiple(of: 1_000) {

          await send(.nthPrimeProgress(Double(primeCount) / Double(count)), animation: .default)
          await Task.yield()
        }
      }

      await send(.nthPrimeResponse(prime - 1), animation: .default)

      // viewStore.send(action, animation: .default)
    }

  case let .nthPrimeProgress(progress):
    state.nthPrimeProgress = progress
    return .none

  case let .nthPrimeResponse(prime):
    state.numberFact = "The \(state.count)th prime is \(prime)."
    state.nthPrimeProgress = nil
    return .none

  case .numberFactButtonTapped:
    state.isNumberFactRequestInFlight = true
    state.numberFact = nil
    // Return an effect that fetches a number fact from the API and returns the
    // value back to the reducer's `numberFactResponse` action.

    return .task { [count = state.count] in
      .numberFactResponse(await TaskResult { try await environment.fact.fetchAsync(count) })
    }

  case let .numberFactResponse(.success(response)):
    state.isNumberFactRequestInFlight = false
    state.numberFact = response
    return .none

  case let .numberFactResponse(.failure(failure as URLError)):
    // TODO: Handle the URL error
    state.isNumberFactRequestInFlight = false
    return .none

  case .numberFactResponse(.failure):
    // NB: This is where we could handle the error is some way, such as showing an alert.
    state.isNumberFactRequestInFlight = false
    return .none

  case .startTimerButtonTapped:
    state.isTimerRunning = true
    return .run { send in
      var count = 0
      do {
        while true {
          print("Hello!")
          defer { count += 1 }
          try await environment.mainQueue.sleep(
            for: .milliseconds(max(50, 1_000 - count * 50))
          )
          await send(.timerTick)
        }
      } catch {}
    }
    .cancellable(id: TimerID.self)
//    return Effect.timer(
//      id: TimerID.self,
//      every: .seconds(1),
//      on: environment.mainQueue
//    )
//    .map { _ in .timerTick }

  case .stopTimerButtonTapped:
    state.isTimerRunning = false
    return .cancel(id: TimerID.self)

  case .timerTick:
    state.count += 1
    return .none
  }
}
.debug()

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

private func isPrime(_ p: Int) -> Bool {
  if p <= 1 { return false }
  if p <= 3 { return true }
  for i in 2...Int(sqrtf(Float(p))) {
    if p % i == 0 { return false }
  }
  return true
}
private func asyncNthPrime(_ n: Int) async {
  let start = Date()
  var primeCount = 0
  var prime = 2
  while primeCount < n {
    defer { prime += 1 }
    if isPrime(prime) {
      primeCount += 1
    } else if prime.isMultiple(of: 1_000) {
      await Task.yield()
    }
  }
  print(
    "\(n)th prime", prime-1,
    "time", Date().timeIntervalSince(start)
  )
}
