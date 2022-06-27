import Combine
import ComposableArchitecture
import Foundation
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
  var isTimerActive = false
  var numberFact: String?
  var nthPrimeEvent: NthPrimeEvent?
}

enum EffectsBasicsAction: Equatable {
  case decrementButtonTapped
  case delayedDecrementButtonTapped
  case incrementButtonTapped
  case megaIncrementButtonTapped
  case nthPrimeButtonTapped
  case nthPrimeEvent(NthPrimeEvent)
  case numberFactButtonTapped
  case numberFactResponse(TaskResult<String>)
  case startTimerButtonTapped
  case stopTimerButtonTapped
  case timerTicked(increment: Int)
}

struct EffectsBasicsEnvironment {
  var fact: FactClient
  var mainQueue: AnySchedulerOf<DispatchQueue>
}

// MARK: - Feature business logic

extension Scheduler {
  public func sleep(
    for duration: SchedulerTimeType.Stride
  ) async throws {
    await withUnsafeContinuation { c in
      self.schedule(after: self.now.advanced(by: duration)) {
        c.resume()
      }
    }
    try Task.checkCancellation()
  }

  public func timer(
    interval: SchedulerTimeType.Stride
  ) -> AsyncStream<SchedulerTimeType> {
    .init { continuation in
      let cancellable = self.schedule(
        after: self.now.advanced(by: interval),
        interval: interval
      ) {
        continuation.yield(self.now)
      }
      continuation.onTermination = { _ in
        cancellable.cancel()
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
    : .task {
      try? await environment.mainQueue.sleep(for: .seconds(1))
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

  case .megaIncrementButtonTapped:
    state.count += 10_000
    return .none

  case .nthPrimeButtonTapped:
    return .run { [count = state.count] send in
      for await event in nthPrime(count) {
        await send(.nthPrimeEvent(event), animation: .default)
      }
    }

  case let .nthPrimeEvent(event):
    state.nthPrimeEvent = event
    return .none

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

  case .startTimerButtonTapped:
    state.isTimerActive = true
    return .run { send in
      var n = 0
      for await _ in environment.mainQueue.timer(interval: .seconds(1)) {
        n += 1
        await send(.timerTicked(increment: Int(pow(3, Double(n)))))
      }
    }
    .cancellable(id: TimerID.self)

    return .run { subscriber in
      var n = 0
      let cancellable = environment.mainQueue.schedule(
        after: .init(.now()),
        interval: .seconds(1)
      ) {
        n += 1
        subscriber.send(.timerTicked(increment: Int(pow(3, Double(n)))))
      }

      return cancellable
    }
    .cancellable(id: TimerID.self)

//    return Effect.timer(id: TimerID.self, every: .seconds(1), on: environment.mainQueue)
//      .map { _ in EffectsBasicsAction.timerTicked }

  case .stopTimerButtonTapped:
    state.isTimerActive = false
    return .cancel(id: TimerID.self)

  case let .timerTicked(increment):
    state.count += increment
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
            Button("++") { viewStore.send(.megaIncrementButtonTapped) }
              .bold()
            Spacer()
          }
          .buttonStyle(.borderless)

          if viewStore.isTimerActive {
            Button("Stop timer") { viewStore.send(.stopTimerButtonTapped) }
              .frame(maxWidth: .infinity)
              .buttonStyle(.borderless)
          } else {
            Button("Start timer") { viewStore.send(.startTimerButtonTapped) }
              .frame(maxWidth: .infinity)
              .buttonStyle(.borderless)
          }

          Button("Number fact") { viewStore.send(.numberFactButtonTapped) }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderless)

          Button("\(viewStore.count)th prime") { viewStore.send(.nthPrimeButtonTapped) }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderless)
        }

        if let nthPrimeEvent = viewStore.nthPrimeEvent {
          self.nthPrime(event: nthPrimeEvent)
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

  func nthPrime(event: NthPrimeEvent) -> some View {
    Section {
      switch event {
      case let .progress(progress):
        VStack {
          Text("Computing prime")
          ProgressView("", value: progress)
            .progressViewStyle(.linear)
        }
      case let .finished(nthPrime):
        Text("Prime: \(nthPrime)")
      }
    }
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


@testable import ComposableArchitecture
extension Reducer {
  func cancellable(
    id: @escaping (State) -> AnyHashable,
    taskAction: @escaping (Action) -> Bool
  ) -> Self {
    .init { state, action, environment in
      let id = id(state)
      let effect: Effect<Action, Never>
      if taskAction(action) {
        effect = .fireAndForget {
          await withTaskCancellationHandler(
            handler: {
              cancellationCancellables[CancelToken(id: id)] = nil
            },
            operation: {
              for await _ in AsyncStream<Void> { _ in } {}
            }
          )
        }
      } else {
        effect = .none
      }

      return .merge(
        effect,
        self.run(&state, action, environment).cancellable(id: id)
      )
    }
  }
}

extension Effect {
  public static func run(
    priority: TaskPriority? = nil,
    _ operation: @escaping @Sendable (_ send: Send<Output>) async -> Void
  ) -> Self {
    .run { subscriber in
      let task = Task(priority: priority) { @MainActor in
        await operation(Send(send: { subscriber.send($0) }))
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

enum NthPrimeEvent: Equatable {
  case progress(Double)
  case finished(Int)
}
private func nthPrime(_ n: Int) -> AsyncStream<NthPrimeEvent> {
  .init { continuation in
    Task {
      var primeCount = 0
      var prime = 2
      var lastProgress = 0
      while primeCount < n {
        defer { prime += 1 }
        if isPrime(prime) {
          primeCount += 1
        } else if prime.isMultiple(of: 1_000) {
          await Task.yield()
        }

        let progress = Int(Double(primeCount) / Double(n) * 100)
        defer { lastProgress = progress }
        if progress != lastProgress {
          continuation.yield(.progress(Double(progress) / 100))
        }
      }
      continuation.yield(.finished(prime - 1))
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
