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
  var fetchNumber: @Sendable () async throws -> Int
}

let multipleDependenciesReducer = Reducer<
  MultipleDependenciesState,
  MultipleDependenciesAction,
  SystemEnvironment<MultipleDependenciesEnvironment>
> { state, action, environment in

  switch action {
  case .alertButtonTapped:
    return .task {
      try await environment.mainQueue.sleep(for: 1)
      return .alertDelayReceived
    }

  case .alertDelayReceived:
    state.alert = AlertState(title: TextState("Here's an alert after a delay!"))
    return .none

  case .alertDismissed:
    state.alert = nil
    return .none

  case .dateButtonTapped:
    state.dateString = "\(environment.date())"
    return .none

  case .fetchNumberButtonTapped:
    state.isFetchInFlight = true
    return .task { .fetchNumberResponse(try await environment.fetchNumber()) }

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
    WithViewStore(self.store, observe: { $0 }) { viewStore in
      Form {
        AboutView(readMe: readMe)

        Section {
          HStack {
            Button("Date") { viewStore.send(.dateButtonTapped) }
            if let dateString = viewStore.dateString {
              Spacer()
              Text(dateString)
            }
          }

          HStack {
            Button("UUID") { viewStore.send(.uuidButtonTapped) }
            if let uuidString = viewStore.uuidString {
              Spacer()
              Text(uuidString)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            }
          }

          Button("Delayed Alert") { viewStore.send(.alertButtonTapped) }
            .alert(self.store.scope(state: \.alert), dismiss: .alertDismissed)
        } header: {
          Text(
            template: """
              The actions below make use of the dependencies in the `SystemEnvironment`.
              """, .caption
          )
          .textCase(.none)
        }

        Section {
          HStack {
            Button("Fetch Number") { viewStore.send(.fetchNumberButtonTapped) }
              .disabled(viewStore.isFetchInFlight)
            Spacer()

            if viewStore.isFetchInFlight {
              ProgressView()
            } else if let fetchedNumberString = viewStore.fetchedNumberString {
              Text(fetchedNumberString)
            }
          }
        } header: {
          Text(
            template: """
              The actions below make use of the custom environment for this screen, which holds a \
              dependency for fetching a random number.
              """, .caption
          )
          .textCase(.none)
        }

      }
      .buttonStyle(.borderless)
    }
    .navigationTitle("System Environment")
  }
}

struct MultipleDependenciesView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      MultipleDependenciesView(
        store: Store(
          initialState: MultipleDependenciesState(),
          reducer: multipleDependenciesReducer,
          environment: .live(
            environment: MultipleDependenciesEnvironment(
              fetchNumber: {
                try await Task.sleep(nanoseconds: NSEC_PER_SEC)
                return Int.random(in: 1...1_000)
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
  var date: @Sendable () -> Date
  var environment: Environment
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var uuid: @Sendable () -> UUID

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
      date: { Date() },
      environment: environment,
      mainQueue: .main,
      uuid: { UUID() }
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

extension SystemEnvironment: Sendable where Environment: Sendable {}

#if DEBUG
  import XCTestDynamicOverlay

  extension SystemEnvironment {
    static func unimplemented(
      date: @escaping @Sendable () -> Date = XCTUnimplemented(
        "\(Self.self).date", placeholder: Date()
      ),
      environment: Environment,
      mainQueue: AnySchedulerOf<DispatchQueue> = .unimplemented,
      uuid: @escaping @Sendable () -> UUID = XCTUnimplemented(
        "\(Self.self).uuid", placeholder: UUID()
      )
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
