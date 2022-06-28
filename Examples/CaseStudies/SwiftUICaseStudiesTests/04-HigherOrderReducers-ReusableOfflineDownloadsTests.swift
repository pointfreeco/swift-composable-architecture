import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class ReusableComponentsDownloadComponentTests: XCTestCase {
  let downloadSubject = PassthroughSubject<DownloadClient.Action, DownloadClient.Error>()
  let reducer = Reducer<
    DownloadComponentState<Int>, DownloadComponentAction, DownloadComponentEnvironment
  >
  .empty
  .downloadable(
    state: \.self,
    action: .self,
    environment: { $0 }
  )
  let scheduler = DispatchQueue.test

  func testDownloadFlow() async {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.eraseToEffect() }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.downloadSubject.send(.updateProgress(0.2))
    await self.scheduler.advance()
    await store.receive(.downloadClient(.success(.updateProgress(0.2)))) {
      $0.mode = .downloading(progress: 0.2)
    }

    self.downloadSubject.send(.response(Data()))
    self.downloadSubject.send(completion: .finished)
    await self.scheduler.advance(by: 1)
    await store.receive(.downloadClient(.success(.response(Data())))) {
      $0.mode = .downloaded
    }
  }

  func testDownloadThrottling() async {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.eraseToEffect() }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    self.downloadSubject.send(.updateProgress(0.5))
    await self.scheduler.advance()
    await store.receive(.downloadClient(.success(.updateProgress(0.5)))) {
      $0.mode = .downloading(progress: 0.5)
    }

    self.downloadSubject.send(.updateProgress(0.6))
    await self.scheduler.advance(by: 0.5)

    self.downloadSubject.send(.updateProgress(0.7))
    await self.scheduler.advance(by: 0.5)
    await store.receive(.downloadClient(.success(.updateProgress(0.7)))) {
      $0.mode = .downloading(progress: 0.7)
    }

    self.downloadSubject.send(completion: .finished)
    await self.scheduler.run()
  }

  func testCancelDownloadFlow() async {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.eraseToEffect() }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to stop downloading this map?"),
        primaryButton: .destructive(TextState("Stop"), action: .send(.stopButtonTapped)),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    store.send(.alert(.stopButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }

    await self.scheduler.run()
  }

  func testDownloadFinishesWhileTryingToCancel() async {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.eraseToEffect() }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .notDownloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.buttonTapped) {
      $0.mode = .startingToDownload
    }

    store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to stop downloading this map?"),
        primaryButton: .destructive(TextState("Stop"), action: .send(.stopButtonTapped)),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    self.downloadSubject.send(.response(Data()))
    self.downloadSubject.send(completion: .finished)
    await self.scheduler.advance(by: 1)
    await store.receive(.downloadClient(.success(.response(Data())))) {
      $0.alert = nil
      $0.mode = .downloaded
    }
  }

  func testDeleteDownloadFlow() {
    var downloadClient = DownloadClient.unimplemented
    downloadClient.download = { _ in self.downloadSubject.eraseToEffect() }

    let store = TestStore(
      initialState: DownloadComponentState(
        id: 1,
        mode: .downloaded,
        url: URL(string: "https://www.pointfree.co")!
      ),
      reducer: reducer,
      environment: DownloadComponentEnvironment(
        downloadClient: downloadClient,
        mainQueue: self.scheduler.eraseToAnyScheduler()
      )
    )

    store.send(.buttonTapped) {
      $0.alert = AlertState(
        title: TextState("Do you want to delete this map from your offline storage?"),
        primaryButton: .destructive(TextState("Delete"), action: .send(.deleteButtonTapped)),
        secondaryButton: .cancel(TextState("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    store.send(.alert(.deleteButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }
}

extension DownloadClient {
  static let unimplemented = Self(
    download: { _ in .unimplemented("\(Self.self).download") }
  )
}
