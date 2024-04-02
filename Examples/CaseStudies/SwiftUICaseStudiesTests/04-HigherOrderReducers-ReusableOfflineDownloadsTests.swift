import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

final class ReusableComponentsDownloadComponentTests: XCTestCase {
  @MainActor
  func testDownloadFlow() async {
    let download = AsyncThrowingStream.makeStream(of: DownloadClient.Event.self)
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      )
    ) {
      DownloadComponent()
    } withDependencies: {
      $0.downloadClient.download = { @Sendable _ in download.stream }
    }

    await store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    download.continuation.yield(.updateProgress(0.2))
    await store.receive(\.downloadClient.success.updateProgress) {
      $0.mode = .downloading(progress: 0.2)
    }

    download.continuation.yield(.response(Data()))
    download.continuation.finish()
    await store.receive(\.downloadClient.success.response) {
      $0.mode = .downloaded
    }
  }

  @MainActor
  func testCancelDownloadFlow() async {
    let download = AsyncThrowingStream.makeStream(of: DownloadClient.Event.self)
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      )
    ) {
      DownloadComponent()
    } withDependencies: {
      $0.downloadClient.download = { @Sendable _ in download.stream }
    }

    await store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    download.continuation.yield(.updateProgress(0.2))
    await store.receive(\.downloadClient.success.updateProgress) {
      $0.mode = .downloading(progress: 0.2)
    }

    await store.send(.buttonTapped) {
      $0.alert = AlertState {
        TextState("Do you want to stop downloading this map?")
      } actions: {
        ButtonState(role: .destructive, action: .send(.stopButtonTapped, animation: .default)) {
          TextState("Stop")
        }
        ButtonState(role: .cancel) {
          TextState("Nevermind")
        }
      }
    }

    await store.send(\.alert.stopButtonTapped) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }

  @MainActor
  func testDownloadFinishesWhileTryingToCancel() async {
    let download = AsyncThrowingStream.makeStream(of: DownloadClient.Event.self)
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      )
    ) {
      DownloadComponent()
    } withDependencies: {
      $0.downloadClient.download = { @Sendable _ in download.stream }
    }

    let task = await store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    await store.send(.buttonTapped) {
      $0.alert = AlertState {
        TextState("Do you want to stop downloading this map?")
      } actions: {
        ButtonState(role: .destructive, action: .send(.stopButtonTapped, animation: .default)) {
          TextState("Stop")
        }
        ButtonState(role: .cancel) {
          TextState("Nevermind")
        }
      }
    }

    download.continuation.yield(.response(Data()))
    download.continuation.finish()
    await store.receive(\.downloadClient.success.response) {
      $0.alert = nil
      $0.mode = .downloaded
    }

    await task.finish()
  }

  @MainActor
  func testDeleteDownloadFlow() async {
    let download = AsyncThrowingStream.makeStream(of: DownloadClient.Event.self)
    let store = TestStore(
      initialState: DownloadComponent.State(
        id: 1,
        mode: .downloaded,
        url: URL(string: "https://www.pointfree.co")!
      )
    ) {
      DownloadComponent()
    } withDependencies: {
      $0.downloadClient.download = { @Sendable _ in download.stream }
    }

    await store.send(.buttonTapped) {
      $0.alert = AlertState {
        TextState("Do you want to delete this map from your offline storage?")
      } actions: {
        ButtonState(role: .destructive, action: .send(.deleteButtonTapped, animation: .default)) {
          TextState("Delete")
        }
        ButtonState(role: .cancel) {
          TextState("Nevermind")
        }
      }
    }

    await store.send(\.alert.deleteButtonTapped) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }
}
