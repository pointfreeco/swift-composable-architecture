import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to make use of SwiftUI's `refreshable` API in the Composable \
  Architecture. Use the "-" and "+" buttons to count up and down, and then pull down to request \
  a fact about that number.

  There is an overload of the `.send` method that allows you to suspend and await while a piece \
  of state is true. You can use this method to communicate to SwiftUI that you are \
  currently fetching data so that it knows to continue showing the loading indicator.
  """

// MARK: - Feature domain

struct Refreshable: ReducerProtocol {
  struct State: Equatable {
    var count = 0
    var fact: String?
  }

  enum Action: Equatable {
    case cancelButtonTapped
    case decrementButtonTapped
    case factResponse(TaskResult<String>)
    case incrementButtonTapped
    case refresh
  }

  @Dependency(\.factClient) var factClient
  private enum FactRequestID {}

  func reduce(into state: inout State, action: Action) -> EffectTask<Action> {
    switch action {
    case .cancelButtonTapped:
      return .cancel(id: FactRequestID.self)

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
      return .task { [count = state.count] in
        await .factResponse(TaskResult { try await self.factClient.fetch(count) })
      }
      .animation()
      .cancellable(id: FactRequestID.self)
    }
  }
}

// MARK: - Feature view

struct RefreshableView: View {
  @State var isLoading = false
  let store: StoreOf<Refreshable>

  var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      List {
        Section {
          AboutView(readMe: readMe)
        }

        HStack {
          Button {
            viewStore.send(.decrementButtonTapped)
          } label: {
            Image(systemName: "minus")
          }

          Text("\(viewStore.count)")
            .monospacedDigit()

          Button {
            viewStore.send(.incrementButtonTapped)
          } label: {
            Image(systemName: "plus")
          }
        }
        .frame(maxWidth: .infinity)
        .buttonStyle(.borderless)

        if let fact = viewStore.fact {
          Text(fact)
            .bold()
        }
        if self.isLoading {
          Button("Cancel") {
            viewStore.send(.cancelButtonTapped, animation: .default)
          }
        }
      }
      .refreshable {
        self.isLoading = true
        defer { self.isLoading = false }
        await viewStore.send(.refresh).finish()
      }
    }
  }
}

// MARK: - SwiftUI previews

struct Refreshable_Previews: PreviewProvider {
  static var previews: some View {
    RefreshableView(
      store: Store(
        initialState: Refreshable.State(),
        reducer: Refreshable()
      )
    )
  }
}
