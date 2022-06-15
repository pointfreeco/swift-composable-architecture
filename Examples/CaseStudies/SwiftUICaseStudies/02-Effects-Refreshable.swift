@preconcurrency import ComposableArchitecture  // FIXME
import SwiftUI

private let readMe = """
  This application demonstrates how to make use of SwiftUI's `refreshable` API in the Composable \
  Architecture. Use the "-" and "+" buttons to count up and down, and then pull down to request \
  a fact about that number.

  There is an overload of the `.send` method that allows you to suspend and await while a piece \
  of state is true. You can use this method to communicate to SwiftUI that you are \
  currently fetching data so that it knows to continue showing the loading indicator.
  """

struct Refreshable: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var fact: String?
    var isLoading = false
  }

  enum Action: Equatable {
    case cancelButtonTapped
    case decrementButtonTapped
    case factResponse(TaskResult<String>)
    case incrementButtonTapped
    case refresh
  }

  @Dependency(\.factClient) var factClient
  @Dependency(\.mainQueue) var mainQueue

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    enum CancelId {}

    switch action {
    case .cancelButtonTapped:
      state.isLoading = false
      return .cancel(id: CancelId.self)

    case .decrementButtonTapped:
      state.count -= 1
      return .none

    case let .factResponse(.success(fact)):
      state.isLoading = false
      state.fact = fact
      return .none

    case .factResponse(.failure):
      state.isLoading = false
      // TODO: do some error handling
      return .none

    case .incrementButtonTapped:
      state.count += 1
      return .none

    case .refresh:
      state.fact = nil
      state.isLoading = true
      return .task { [count = state.count] in
        try? await self.mainQueue.sleep(for: 2)
        return await .factResponse(.init { try await self.factClient.fetch(count) })
      }
      .animation()
      .cancellable(id: CancelId.self)
    }
  }
}

#if compiler(>=5.5)
  struct RefreshableView: View {
    let store: StoreOf<Refreshable>

    var body: some View {
      WithViewStore(self.store) { viewStore in
        List {
          Text(template: readMe, .body)

          HStack {
            Button("-") { viewStore.send(.decrementButtonTapped) }
            Text("\(viewStore.count)")
            Button("+") { viewStore.send(.incrementButtonTapped) }
          }
          .buttonStyle(.plain)

          if let fact = viewStore.fact {
            Text(fact)
              .bold()
          }
          if viewStore.isLoading {
            Button("Cancel") {
              viewStore.send(.cancelButtonTapped, animation: .default)
            }
          }
        }
        .refreshable {
          await viewStore.send(.refresh)
        }
      }
    }
  }

  struct Refreshable_Previews: PreviewProvider {
    static var previews: some View {
      RefreshableView(
        store: .init(
          initialState: .init(),
          reducer: Refreshable()
        )
      )
    }
  }
#endif
