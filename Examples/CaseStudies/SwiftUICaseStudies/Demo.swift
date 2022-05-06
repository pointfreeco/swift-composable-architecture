import ComposableArchitecture
import SwiftUI

enum TaskResult<Success> {
  case success(Success)
  case failure(Error)

  init(catching body: () async throws -> Success) async {
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
      return (lhs as NSError) == (rhs as NSError)
    case (.success, .failure):
      return false
    case (.failure, .success):
      return false
    }
  }
}
struct State: Equatable {
  var count = 0
  var fact: String?
  var progress: Double?
}
enum Action: Equatable {
  case decrementButtonTapped
  case factButtonTaped
  case factResponse(TaskResult<String>)
  case progress(Double?)
  case incrementButtonTapped
//  case onAppear
//  case onDisappear
  case task
  case randomButtonTapped
}
struct NumberClient {
  var fact: (Int) async throws -> String
  var random: () async throws -> Int
  enum Error: Swift.Error, Equatable {
    case url(URLError)
    case other
  }
}
extension NumberClient {
  static let live = Self(
    fact: { number in
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 1)
      let (data, _) = try await URLSession.shared
        .data(from: .init(string: "http://numbersapi.com/\(number)/trivia")!)
      return .init(decoding: data, as: UTF8.self)
    },
    random: {
      try await Task.sleep(nanoseconds: NSEC_PER_SEC * 1)
      return .random(in: 1...1_000)
    }
  )
}

struct Environment {
  var number: NumberClient
}

let reducer = Reducer<State, Action, Environment> { state, action, environment in
  struct CancelId: Hashable {}

  switch action {
  case .decrementButtonTapped:
    state.count -= 1
    return .none

  case .factButtonTaped:
    return .task { @MainActor [count = state.count] in
      await .factResponse(
        TaskResult { try await environment.number.fact(count) }
      )
    }

  case let .factResponse(.success(fact)):
    state.fact = fact
    return .none

  case let .factResponse(.failure(error as URLError)):
    // TODO: handle URL error
    return .none

  case .factResponse(.failure):
    // TODO: error handling
    return .none

  case .incrementButtonTapped:
    state.count += 1
    return .none

  case .task:
    return .task { @MainActor [count = state.count] in
      do {
        return .factResponse(.success(try await environment.number.fact(count)))
      } catch {
        return .factResponse(.failure(error))
      }
    }

  case let .progress(progress):
    state.progress = progress
    return .none

  case .randomButtonTapped:
    return .run { @MainActor send in
      send(.progress(0), animation: .default)
      defer {
        send(.progress(nil))
      }

      do {
        let number = try await environment.number.random()
        send(.progress(0.5), animation: .default)
        send(.factResponse(await TaskResult { try await environment.number.fact(number) }))
        send(.progress(1), animation: .default)
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC)
      } catch {
        send(.factResponse(.failure(error)))
      }
    }
  }
}
  .debugActions()

@MainActor
func withAnimation(_ animation: Animation? = nil, block: () -> Void) async {
  await MainActor.run {
    withAnimation(animation, block)
  }
}

struct FactView: View {
  let store: Store<State, Action>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      VStack {
        HStack {
          Button("-") { viewStore.send(.decrementButtonTapped) }
          Text("\(viewStore.count)")
          Button("+") { viewStore.send(.incrementButtonTapped) }
        }
        Button("Fact") { viewStore.send(.factButtonTaped) }
        Button("Random") { viewStore.send(.randomButtonTapped) }
        if let progress = viewStore.progress {
          ProgressView(value: progress)
            .progressViewStyle(.linear)
        }
        if let fact = viewStore.fact {
          Text(fact)
        }
      }
      .task {
        await viewStore.send(.task)
      }
//      .onAppear { viewStore.send(.onAppear) }
//      .onDisappear { viewStore.send(.onDisappear) }
    }
  }
}

struct FactViewProvider: PreviewProvider {
  static var previews: some View {
    FactView(
      store: .init(
        initialState: .init(),
        reducer: reducer,
        environment: .init(
          number: .live
        )
      )
    )
  }
}
