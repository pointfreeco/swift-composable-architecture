import Combine
import ComposableArchitecture
import SwiftUI

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
    case userDidTakeScreenshotNotification
    case onAppear
    case onDisappear
  }

  @Dependency(\.notificationCenter) var notificationCenter

  func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
    enum UserDidTakeScreenshotNotificationId {}

    switch action {
    case .userDidTakeScreenshotNotification:
      state.screenshotCount += 1
      return .none

    case .onAppear:
      // When the view appears, start the effect that emits when screenshots are taken.
      return self.notificationCenter
        .publisher(for: UIApplication.userDidTakeScreenshotNotification)
        .map { _ in .userDidTakeScreenshotNotification }
        .eraseToEffect()
        .cancellable(id: UserDidTakeScreenshotNotificationId.self)

    case .onDisappear:
      // When view disappears, stop the effect.
      return .cancel(id: UserDidTakeScreenshotNotificationId.self)
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
      .onAppear { viewStore.send(.onAppear) }
      .onDisappear { viewStore.send(.onDisappear) }
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
