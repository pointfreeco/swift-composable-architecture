import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to make use of SwiftUI's `refreshable` API in the Composable \
  Architecture. Use the "-" and "+" buttons to count up and down, and then pull down to request \
  a fact about that number.

  There is a discardable task that is returned from the store's `.send` method representing any \
  effects kicked off by the reducer. You can `await` this task using its `.finish` method, which \
  will suspend while the effects remain in flight. This suspension communicates to SwiftUI that \
  you are currently fetching data so that it knows to continue showing the loading indicator.
  """

@Reducer
struct Refreshable {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var fact: String?
  }

  enum Action {
    case cancelButtonTapped
    case decrementButtonTapped
    case factResponse(Result<String, Error>)
    case incrementButtonTapped
    case refresh
  }

  @Dependency(\.factClient) var factClient
  private enum CancelID { case factRequest }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .cancelButtonTapped:
        return .cancel(id: CancelID.factRequest)

      case .decrementButtonTapped:
        state.count -= 1
        return .none

      case let .factResponse(.success(fact)):
        state.fact = fact
        return .none

      case .factResponse(.failure):
        // NB: This is where you could do some error handling.
        return .none

      case .incrementButtonTapped:
        state.count += 1
        return .none

      case .refresh:
        state.fact = nil
        return .run { [count = state.count] send in
          await send(
            .factResponse(Result { try await self.factClient.fetch(count) }),
            animation: .default
          )
        }
        .cancellable(id: CancelID.factRequest)
      }
    }
  }
}

struct RefreshableView: View {
  let store: StoreOf<Refreshable>
  @State var isLoading = false

  var body: some View {
    List {
      Section {
        AboutView(readMe: readMe)
      }

      HStack {
        Button {
          store.send(.decrementButtonTapped)
        } label: {
          Image(systemName: "minus")
        }

        Text("\(store.count)")
          .monospacedDigit()

        Button {
          store.send(.incrementButtonTapped)
        } label: {
          Image(systemName: "plus")
        }
      }
      .frame(maxWidth: .infinity)
      .buttonStyle(.borderless)

      if let fact = store.fact {
        Text(fact)
          .bold()
      }
      if self.isLoading {
        Button("Cancel") {
          store.send(.cancelButtonTapped, animation: .default)
        }
      }
    }
    .refreshable {
      isLoading = true
      defer { isLoading = false }
      await store.send(.refresh).finish()
    }
  }
}

#Preview {
  RefreshableView(
    store: Store(initialState: Refreshable.State()) {
      Refreshable()
    }
  )
}
