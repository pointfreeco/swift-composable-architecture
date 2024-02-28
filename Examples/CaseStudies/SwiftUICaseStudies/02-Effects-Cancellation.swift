import ComposableArchitecture
import SwiftUI

private let readMe = """
  This screen demonstrates how one can cancel in-flight effects in the Composable Architecture.

  Use the stepper to count to a number, and then tap the "Number fact" button to fetch \
  a random fact about that number using an API.

  While the API request is in-flight, you can tap "Cancel" to cancel the effect and prevent \
  it from feeding data back into the application. Interacting with the stepper while a \
  request is in-flight will also cancel it.
  """

@Reducer
struct EffectsCancellation {
  @ObservableState
  struct State: Equatable {
    var count = 0
    var currentFact: String?
    var isFactRequestInFlight = false
  }

  enum Action {
    case cancelButtonTapped
    case stepperChanged(Int)
    case factButtonTapped
    case factResponse(Result<String, Error>)
  }

  @Dependency(\.factClient) var factClient
  private enum CancelID { case factRequest }

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .cancelButtonTapped:
        state.isFactRequestInFlight = false
        return .cancel(id: CancelID.factRequest)

      case let .stepperChanged(value):
        state.count = value
        state.currentFact = nil
        state.isFactRequestInFlight = false
        return .cancel(id: CancelID.factRequest)

      case .factButtonTapped:
        state.currentFact = nil
        state.isFactRequestInFlight = true

        return .run { [count = state.count] send in
          await send(.factResponse(Result { try await self.factClient.fetch(count) }))
        }
        .cancellable(id: CancelID.factRequest)

      case let .factResponse(.success(response)):
        state.isFactRequestInFlight = false
        state.currentFact = response
        return .none

      case .factResponse(.failure):
        state.isFactRequestInFlight = false
        return .none
      }
    }
  }
}

struct EffectsCancellationView: View {
  @Bindable var store: StoreOf<EffectsCancellation>
  @Environment(\.openURL) var openURL

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Section {
        Stepper("\(store.count)", value: $store.count.sending(\.stepperChanged))

        if store.isFactRequestInFlight {
          HStack {
            Button("Cancel") { store.send(.cancelButtonTapped) }
            Spacer()
            ProgressView()
              // NB: There seems to be a bug in SwiftUI where the progress view does not show
              // a second time unless it is given a new identity.
              .id(UUID())
          }
        } else {
          Button("Number fact") { store.send(.factButtonTapped) }
            .disabled(store.isFactRequestInFlight)
        }

        if let fact = store.currentFact {
          Text(fact).padding(.vertical, 8)
        }
      }

      Section {
        Button("Number facts provided by numbersapi.com") {
          self.openURL(URL(string: "http://numbersapi.com")!)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
      }
    }
    .buttonStyle(.borderless)
    .navigationTitle("Effect cancellation")
  }
}

#Preview {
  NavigationStack {
    EffectsCancellationView(
      store: Store(initialState: EffectsCancellation.State()) {
        EffectsCancellation()
      }
    )
  }
}
