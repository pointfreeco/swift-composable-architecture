import ComposableArchitecture
import Foundation
import SwiftUI

private let readMe = """
  This screen demonstrates how one can share system-wide dependencies across many features with \
  very little work. The idea is to create a `SystemEnvironment` generic type that wraps an \
  environment, and then implement dynamic member lookup so that you can seamlessly use the \
  dependencies in both environments.

  Then, throughout your application you can wrap your environments in the `SystemEnvironment` \
  to get instant access to all of the shared dependencies. Some good candidates for dependencies \
  to share are things like date initializers, schedulers (especially `DispatchQueue.main`), `UUID` \
  initializers, and any other dependency in your application that you want every reducer to have \
  access to.
  """

struct MultipleDependenciesState: Equatable {
  var alert: AlertState<MultipleDependenciesAction>?
  var dateString: String?
  var fetchedNumberString: String?
  var isFetchInFlight = false
  var uuidString: String?
}

enum MultipleDependenciesAction: Equatable {
  case alertButtonTapped
  case alertDelayReceived
  case alertDismissed
  case dateButtonTapped
  case fetchNumberButtonTapped
  case fetchNumberResponse(Int)
  case uuidButtonTapped
}

struct MultipleDependenciesEnvironment {
  var fetchNumber: () -> Effect<Int, Never>
}

let multipleDependenciesReducer = Reducer<
  MultipleDependenciesState,
  MultipleDependenciesAction,
  SystemEnvironment<MultipleDependenciesEnvironment>
> { state, action, environment in

  switch action {
  case .alertButtonTapped:
    return Effect(value: .alertDelayReceived)
      .delay(for: 1, scheduler: environment.mainQueue)
      .eraseToEffect()

  case .alertDelayReceived:
    state.alert = .init(title: .init("Here's an alert after a delay!"))
    return .none

  case .alertDismissed:
    state.alert = nil
    return .none

  case .dateButtonTapped:
    state.dateString = "\(environment.date())"
    return .none

  case .fetchNumberButtonTapped:
    state.isFetchInFlight = true
    return environment.fetchNumber()
      .map(MultipleDependenciesAction.fetchNumberResponse)

  case let .fetchNumberResponse(number):
    state.isFetchInFlight = false
    state.fetchedNumberString = "\(number)"
    return .none

  case .uuidButtonTapped:
    state.uuidString = "\(environment.uuid())"
    return .none
  }
}

struct MultipleDependenciesView: View {
  let store: Store<MultipleDependenciesState, MultipleDependenciesAction>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(
          header: Text(template: readMe, .caption)
        ) {
          EmptyView()
        }

        Section(
          header: Text(
            template: """
              The actions below make use of the dependencies in the `SystemEnvironment`.
              """, .caption)
        ) {
          HStack {
            Button("Date") { viewStore.send(.dateButtonTapped) }
            viewStore.dateString.map(Text.init)
          }

          HStack {
            Button("UUID") { viewStore.send(.uuidButtonTapped) }
            viewStore.uuidString.map(Text.init)
          }

          Button("Delayed Alert") { viewStore.send(.alertButtonTapped) }
            .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
        }

        Section(
          header: Text(
            template: """
              The actions below make use of the custom environment for this screen, which holds a \
              dependency for fetching a random number.
              """, .caption)
        ) {
          HStack {
            Button("Fetch Number") { viewStore.send(.fetchNumberButtonTapped) }
            viewStore.fetchedNumberString.map(Text.init)

            Spacer()

            if viewStore.isFetchInFlight {
              ProgressView()
            }
          }
        }
      }
      .buttonStyle(.borderless)
    }
    .navigationBarTitle("System Environment")
  }
}

struct MultipleDependenciesView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      MultipleDependenciesView(
        store: Store(
          initialState: .init(),
          reducer: multipleDependenciesReducer,
          environment: .live(
            environment: MultipleDependenciesEnvironment(
              fetchNumber: {
                Effect(value: Int.random(in: 1...1_000))
                  .delay(for: 1, scheduler: DispatchQueue.main)
                  .eraseToEffect()
              }
            )
          )
        )
      )
    }
  }
}

@dynamicMemberLookup
struct SystemEnvironment<Environment> {
  var date: () -> Date
  var environment: Environment
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: () -> UUID

  subscript<Dependency>(
    dynamicMember keyPath: WritableKeyPath<Environment, Dependency>
  ) -> Dependency {
    get { self.environment[keyPath: keyPath] }
    set { self.environment[keyPath: keyPath] = newValue }
  }

  /// Creates a live system environment with the wrapped environment provided.
  ///
  /// - Parameter environment: An environment to be wrapped in the system environment.
  /// - Returns: A new system environment.
  static func live(environment: Environment) -> Self {
    Self(
      date: Date.init,
      environment: environment,
      mainQueue: .main,
      uuid: UUID.init
    )
  }

  /// Transforms the underlying wrapped environment.
  func map<NewEnvironment>(
    _ transform: @escaping (Environment) -> NewEnvironment
  ) -> SystemEnvironment<NewEnvironment> {
    .init(
      date: self.date,
      environment: transform(self.environment),
      mainQueue: self.mainQueue,
      uuid: self.uuid
    )
  }
}

#if DEBUG
  import XCTestDynamicOverlay

  extension SystemEnvironment {
    static func failing(
      date: @escaping () -> Date = {
        XCTFail("date dependency is unimplemented.")
        return Date()
      },
      environment: Environment,
      mainQueue: AnySchedulerOf<DispatchQueue> = .failing,
      uuid: @escaping () -> UUID = {
        XCTFail("UUID dependency is unimplemented.")
        return UUID()
      }
    ) -> Self {
      Self(
        date: date,
        environment: environment,
        mainQueue: mainQueue,
        uuid: uuid
      )
    }
  }
#endif

extension UUID {
  /// A deterministic, auto-incrementing "UUID" generator for testing.
  static var incrementing: () -> UUID {
    var uuid = 0
    return {
      defer { uuid += 1 }
      return UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012x", uuid))")!
    }
  }
}
