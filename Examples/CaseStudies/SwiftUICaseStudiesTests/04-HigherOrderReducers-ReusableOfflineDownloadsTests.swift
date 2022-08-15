import Combine
import ComposableArchitecture
import XCTest
import XCTestDynamicOverlay

@testable import SwiftUICaseStudies

@MainActor
final class ReusableComponentsDownloadComponentTests: XCTestCase {
  let download = AsyncThrowingStream<DownloadClient.Event, Error>.streamWithContinuation()
  let reducer = Reducer<
    DownloadComponentState<Int>,
    DownloadComponentAction,
    DownloadComponentEnvironment
  >
  .empty
  .downloadable(
    state: \.self,
    action: .self,
    environment: { $0 }
  )
  let mainQueue = DispatchQueue.test

  func testDownloadFlow() async {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.download.stream }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(downloadClient: downloadClient)
    )

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
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.download.stream }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(downloadClient: downloadClient)
    )

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
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.download.stream }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(downloadClient: downloadClient)
    )

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
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.download.stream }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .downloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(downloadClient: downloadClient)
    )

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

extension DownloadClient {
  static let unimplemented = Self(
    download: XCTUnimplemented("\(Self.self).asyncDownload")
  )
}
