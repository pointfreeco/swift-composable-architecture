import ComposableArchitecture
@preconcurrency import SwiftUI

private let readMe = """
  This application demonstrates how to make use of SwiftUI's `refreshable` API in the Composable \
  Architecture. Use the "-" and "+" buttons to count up and down, and then pull down to request \
  a fact about that number.

  There is an overload of the `.send` method that allows you to suspend and await while a piece \
  of state is true. You can use this method to communicate to SwiftUI that you are \
  currently fetching data so that it knows to continue showing the loading indicator.
  """

// MARK: - Feature domain

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

// MARK: - Feature view

struct RefreshableView: View {
  var store = Store(initialState: Refreshable.State()) {
    Refreshable()
  }
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

// MARK: - SwiftUI previews

struct Refreshable_Previews: PreviewProvider {
  static var previews: some View {
    RefreshableView(
      store: Store(initialState: Refreshable.State()) {
        Refreshable()
      }
    )
  }
}
