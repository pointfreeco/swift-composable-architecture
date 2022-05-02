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
}
enum Action: Equatable {
  case decrementButtonTapped
  case factButtonTaped
  case factResponse(TaskResult<String>)
  case incrementButtonTapped
  case onAppear
  case onDisappear
}
struct NumberClient {
  var fact: (Int) async throws -> String
  enum Error: Swift.Error, Equatable {
    case url(URLError)
    case other
  }
}
extension NumberClient {
  static let live = Self(
    fact: { number in
      let (data, _) = try await URLSession.shared
        .data(from: .init(string: "http://numbersapi.com/\(number)/trivia")!)
      return .init(decoding: data, as: UTF8.self)
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

  case .onAppear:
    return .task { @MainActor [count = state.count] in
      do {
        return .factResponse(.success(try await environment.number.fact(count)))
      } catch {
        return .factResponse(.failure(error))
      }
    }
    .cancellable(id: CancelId())

  case .onDisappear:
    return .cancel(id: CancelId())
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
        if let fact = viewStore.fact {
          Text(fact)
        }
      }
      .onAppear { viewStore.send(.onAppear) }
      .onDisappear { viewStore.send(.onDisappear) }
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
