import ComposableArchitecture
import SwiftUI

struct State: Equatable {
  var count = 0
  var fact: String?
}
enum Action: Equatable {
  case decrementButtonTapped
  case factButtonTaped
  case factResponse(String)
  case incrementButtonTapped
  case randomButtonTapped
  case onAppear
  case onDisappear
}
struct NumberClient {
  var fact: (Int) async throws -> String
  var random: () async throws -> Int
}
extension NumberClient {
  static let live = Self(
    fact: { number in
      let (data, _) = try await URLSession.shared
        .data(from: .init(string: "http://numbersapi.com/\(number)/trivia")!)
      return .init(decoding: data, as: UTF8.self)
    },
    random: {
      let (data, _) = try await URLSession.shared
        .data(from: .init(string: "https://www.random.org/integers/?num=1&min=1&max=100&col=1&base=10&format=plain")!)
      return Int(
        String(decoding: data, as: UTF8.self)
          .trimmingCharacters(in: .newlines)
      ) ?? 0
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
      do {
        return .factResponse(try await environment.number.fact(count))
      } catch {
        return .factResponse("\(count) is a good number")
      }
    }

  case let .factResponse(fact):
    state.fact = fact
    return .none

  case .incrementButtonTapped:
    state.count += 1
    return .none

  case .randomButtonTapped:
    return .task { @MainActor in
      do {
        let number = try await environment.number.random()
        let fact = try await environment.number.fact(number)
        return .factResponse(fact)
      } catch {
        return .factResponse("0 is a good number")
      }
    }

  case .onAppear:
    return .task { @MainActor [count = state.count] in
      do {
        try? await Task.sleep(nanoseconds: NSEC_PER_SEC * 2)
        return .factResponse(try await environment.number.fact(count))
      } catch {
        return .factResponse("\(count) is a good number")
      }
    }
    .cancellable(id: CancelId())

  case .onDisappear:
    return .cancel(id: CancelId())
  }
}
  .debug()

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
