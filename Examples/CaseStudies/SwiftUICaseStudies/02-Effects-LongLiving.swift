import Combine
@preconcurrency import ComposableArchitecture  // FIXME
import SwiftUI
import XCTestDynamicOverlay

private let readMe = """
  This application demonstrates how to handle long-living effects, for example notifications from \
  Notification Center.

  Run this application in the simulator, and take a few screenshots by going to \
  *Device › Screenshot* in the menu, and observe that the UI counts the number of times that \
  happens.

  Then, navigate to another screen and take screenshots there, and observe that this screen does \
  *not* count those screenshots.
  """


struct LongLivingEffects: ReducerProtocol {
  struct State: Equatable {
    var screenshotCount = 0
  }

  enum Action {
    case task
    case userDidTakeScreenshotNotification
  }

  @Dependency(\.screenshots) var screenshots

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
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

extension DependencyValues {
  var screenshots: @Sendable () async -> AsyncStream<Void> {
    get { self[ScreenshotsKey.self] }
    set { self[ScreenshotsKey.self] = newValue }
  }

  private enum ScreenshotsKey: DependencyKey {
    static let liveValue: @Sendable () async -> AsyncStream<Void> = {
      AsyncStream(
        NotificationCenter.default
          .notifications(named: await UIApplication.userDidTakeScreenshotNotification)
          .map { _ in }
      )
    }
    static let testValue: @Sendable () async -> AsyncStream<Void> = {
      XCTFail(#"@Dependency(\.screenshots)"#)
      return AsyncStream<Void> { _ in }
    }
  }
}

// MARK: - SwiftUI view

struct LongLivingEffectsView: View {
  let store: StoreOf<LongLivingEffects>

  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text(template: readMe, .body)) {
          Text("A screenshot of this screen has been taken \(viewStore.screenshotCount) times.")
            .font(.headline)
        }

        Section {
          NavigationLink(destination: self.detailView) {
            Text("Navigate to another screen")
          }
        }
      }
      .navigationBarTitle("Long-living effects")
      .task { await viewStore.send(.task).finish() }
    }
  }

  var detailView: some View {
    Text(
      """
      Take a screenshot of this screen a few times, and then go back to the previous screen to see \
      that those screenshots were not counted.
      """
    )
    .padding(.horizontal, 64)
  }
}

// MARK: - SwiftUI previews

struct EffectsLongLiving_Previews: PreviewProvider {
  static var previews: some View {
    let appView = LongLivingEffectsView(
      store: Store(
        initialState: .init(),
        reducer: LongLivingEffects()
      )
    )

    return Group {
      NavigationView { appView }
      NavigationView { appView.detailView }
    }
  }
}
