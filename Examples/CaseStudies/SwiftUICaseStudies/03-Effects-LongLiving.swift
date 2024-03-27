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
struct LongLivingEffects {
  @ObservableState
  struct State: Equatable {
    var screenshotCount = 0
  }

  enum Action {
    case task
    case userDidTakeScreenshotNotification
  }

  @Dependency(\.screenshots) var screenshots

  var body: some Reducer<State, Action> {
    Reduce { state, action in
      switch action {
      case .task:
        // When the view appears, start the effect that emits when screenshots are taken.
        return .run { send in
          for await _ in await self.screenshots() {
            await send(.userDidTakeScreenshotNotification)
          }
        }

      case .userDidTakeScreenshotNotification:
        state.screenshotCount += 1
        return .none
      }
    }
  }
}

extension DependencyValues {
  var screenshots: @Sendable () async -> AsyncStream<Void> {
    get { self[ScreenshotsKey.self] }
    set { self[ScreenshotsKey.self] = newValue }
  }
}

private enum ScreenshotsKey: DependencyKey {
  static let liveValue: @Sendable () async -> AsyncStream<Void> = {
    await AsyncStream(
      NotificationCenter.default
        .notifications(named: UIApplication.userDidTakeScreenshotNotification)
        .map { _ in }
    )
  }
}

struct LongLivingEffectsView: View {
  let store: StoreOf<LongLivingEffects>

  var body: some View {
    Form {
      Section {
        AboutView(readMe: readMe)
      }

      Text("A screenshot of this screen has been taken \(store.screenshotCount) times.")
        .font(.headline)

      Section {
        NavigationLink {
          detailView
        } label: {
          Text("Navigate to another screen")
        }
      }
    }
    .navigationTitle("Long-living effects")
    .task { await store.send(.task).finish() }
  }

  var detailView: some View {
    Text(
      """
      Take a screenshot of this screen a few times, and then go back to the previous screen to see \
      that those screenshots were not counted.
      """
    )
    .padding(.horizontal, 64)
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    LongLivingEffectsView(
      store: Store(initialState: LongLivingEffects.State()) {
        LongLivingEffects()
      }
    )
  }
}
