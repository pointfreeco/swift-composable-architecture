import ComposableArchitecture
import SwiftUI

private let readMe = """
  This application demonstrates how to handle long-living effects, for example notifications from \
  Notification Center, and how to tie an effect's lifetime to the lifetime of the view.

  Run this application in the simulator, and take a few screenshots by going to \
  *Device › Screenshot* in the menu, and observe that the UI counts the number of times that \
  happens.

  Then, navigate to another screen and take screenshots there, and observe that this screen does \
  *not* count those screenshots. The notifications effect is automatically cancelled when leaving \
  the screen, and restarted when entering the screen.
  """

@Reducer
struct SharedStateNotifications {
  @ObservableState
  struct State: Equatable {
    var fact: String?
    @SharedReader(.screenshotCount) var screenshotCount = 0
  }
  enum Action {
    case factResponse(Result<String, Error>)
    case onAppear
  }
  @Dependency(\.factClient) var factClient
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .factResponse(.success(fact)):
        state.fact = fact
        return .none

      case .factResponse(.failure):
        return .none

      case .onAppear:
        return .run { [screenshotCount = state.$screenshotCount] send in
          for await count in screenshotCount.publisher.values {
            await send(.factResponse(Result { try await factClient.fetch(count) }))
          }
        }
      }
    }
  }
}

struct SharedStateNotificationsView: View {
  let store: StoreOf<SharedStateNotifications>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Text("A screenshot of this screen has been taken \(store.screenshotCount) times.")
        .font(.headline)

      if let fact = store.fact {
        Text("\(fact)")
      }

      Section {
        NavigationLink {
          Text(
            """
            Take a screenshot of this screen a few times, and then go back to the previous screen \
            to see that those screenshots were not counted.
            """
          )
          .padding(.horizontal, 64)
          .navigationBarTitleDisplayMode(.inline)
        } label: {
          Text("Navigate to another screen")
        }
      }
    }
    .navigationTitle("Long-living effects")
    .task { await store.send(.onAppear).finish() }
  }
}

extension PersistenceReaderKey where Self == NotificationReaderKey<Int> {
  static var screenshotCount: Self {
    NotificationReaderKey(
      initialValue: 0,
      name: MainActor.assumeIsolated {
        UIApplication.userDidTakeScreenshotNotification
      }
    ) { value, _ in
      value += 1
    }
  }
}

//extension PersistenceReaderKey where Self == NotificationReaderKey<Bool> {
//  static var isLowPowerEnabled: Self {
//    NotificationReaderKey(
//      initialValue: false,
//      name: .NSProcessInfoPowerStateDidChange
//    ) { value, _ in
//      value = ProcessInfo.processInfo.isLowPowerModeEnabled
//    }
//  }
//}

struct NotificationReaderKey<Value: Sendable>: PersistenceReaderKey {
  let name: Notification.Name
  private let transform: @Sendable (Notification) -> Value

  init(
    initialValue: Value,
    name: Notification.Name,
    transform: @Sendable @escaping (inout Value, Notification) -> Void
  ) {
    self.name = name
    let value = LockIsolated(initialValue)
    self.transform = { notification in
      value.withValue { [notification = UncheckedSendable(notification)] in
        transform(&$0, notification.wrappedValue)
      }
      return value.value
    }
  }

  func load(initialValue: Value?) -> Value? { nil }

  func subscribe(
    initialValue: Value?,
    didSet: @Sendable @escaping (Value?) -> Void
  ) -> Shared<Value>.Subscription {
    let token = NotificationCenter.default.addObserver(
      forName: name,
      object: nil,
      queue: nil,
      using: { notification in
        didSet(self.transform(notification))
      }
    )
    return Shared.Subscription {
      NotificationCenter.default.removeObserver(token)
    }
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.name == rhs.name
  }
  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
  }
}
