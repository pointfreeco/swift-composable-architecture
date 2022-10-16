import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
final class ReusableComponentsDownloadComponentTests: XCTestCase {
  let download = AsyncThrowingStream<DownloadClient.Event, Error>.streamWithContinuation()

  func testDownloadFlow() async {
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: DownloadComponent()
    )

    store.dependencies.downloadClient.download = { _ in self.download.stream }

    await store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.download.continuation.yield(.updateProgress(0.2))
    await store.receive(.downloadClient(.success(.updateProgress(0.2)))) {
      $0.mode = .downloading(progress: 0.2)
    }

    self.download.continuation.yield(.response(Data()))
    self.download.continuation.finish()
    await store.receive(.downloadClient(.success(.response(Data())))) {
      $0.mode = .downloaded
    }
  }

  func testCancelDownloadFlow() async {
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: DownloadComponent()
    )

    store.dependencies.downloadClient.download = { _ in self.download.stream }

    await store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.download.continuation.yield(.updateProgress(0.2))
    await store.receive(.downloadClient(.success(.updateProgress(0.2)))) {
      $0.mode = .downloading(progress: 0.2)
    }

    await store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to stop downloading this map?"),
        primaryButton: .destructive(
          TextState("Stop"),
          action: .send(.stopButtonTapped, animation: .default)
        ),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    await store.send(.alert(.stopButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }

  func testDownloadFinishesWhileTryingToCancel() async {
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: DownloadComponent()
    )

    store.dependencies.downloadClient.download = { _ in self.download.stream }

    let task = await store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    await store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to stop downloading this map?"),
        primaryButton: .destructive(
          TextState("Stop"),
          action: .send(.stopButtonTapped, animation: .default)
        ),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    self.download.continuation.yield(.response(Data()))
    self.download.continuation.finish()
    await store.receive(.downloadClient(.success(.response(Data())))) {
      $0.alert = nil
      $0.mode = .downloaded
    }

    await task.finish()
  }

  func testDeleteDownloadFlow() async {
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .downloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: DownloadComponent()
    )

    store.dependencies.downloadClient.download = { _ in self.download.stream }

    await store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to delete this map from your offline storage?"),
        primaryButton: .destructive(
          TextState("Delete"),
          action: .send(.deleteButtonTapped, animation: .default)
        ),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    await store.send(.alert(.deleteButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }
}
