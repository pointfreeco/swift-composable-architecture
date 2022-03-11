import Combine
import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class ReusableComponentsDownloadComponentTests: XCTestCase {
  let downloadSubject = PassthroughSubject<DownloadClient.Action, Error>()

  let (downloadContinuation, downloadStream): (
    AsyncThrowingStream<DownloadClient.Action, Error>.Continuation,
    AsyncThrowingStream<DownloadClient.Action, Error>
  ) = {
    var c: AsyncThrowingStream<DownloadClient.Action, Error>.Continuation!
    let s = AsyncThrowingStream<DownloadClient.Action, Error> { c = $0 }
    return (c, s)
  }()

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
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _ in self.downloadStream }

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

    self.downloadContinuation.yield(.updateProgress(0.2))
    await self.scheduler.advance()
    await store.receive(.downloadClient(.success(.updateProgress(0.2)))) {
      $0.mode = .downloading(progress: 0.2)
    }

    self.downloadContinuation.yield(.response(Data()))
    self.downloadContinuation.finish(throwing: nil)
    await self.scheduler.advance(by: .seconds(1))
    await store.receive(.downloadClient(.success(.response(Data())))) {
      $0.mode = .downloaded
    }
  }

  func testDownloadThrottling() async {
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _ in self.downloadStream }

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

    self.downloadContinuation.yield(.updateProgress(0.5))
    await self.scheduler.advance()
    await store.receive(.downloadClient(.success(.updateProgress(0.5)))) {
      $0.mode = .downloading(progress: 0.5)
    }

    self.downloadContinuation.yield(.updateProgress(0.6))
    await self.scheduler.advance(by: 0.5)

    self.downloadContinuation.yield(.updateProgress(0.7))
    await self.scheduler.advance(by: 0.5)
    await store.receive(.downloadClient(.success(.updateProgress(0.7)))) {
      $0.mode = .downloading(progress: 0.7)
    }

    self.downloadContinuation.finish(throwing: nil)
    await self.scheduler.run()
  }

  func testCancelDownloadFlow() async {
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _ in self.downloadStream }

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
      $0.alert = .init(
        title: .init("Do you want to cancel downloading this map?"),
        primaryButton: .destructive(.init("Cancel"), action: .send(.cancelButtonTapped)),
        secondaryButton: .default(.init("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    store.send(.alert(.cancelButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }

    await self.scheduler.run()
  }

  func testDownloadFinishesWhileTryingToCancel() async {
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _ in self.downloadStream }

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
      $0.alert = .init(
        title: .init("Do you want to cancel downloading this map?"),
        primaryButton: .destructive(.init("Cancel"), action: .send(.cancelButtonTapped)),
        secondaryButton: .default(.init("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    self.downloadContinuation.yield(.response(Data()))
    self.downloadContinuation.finish(throwing: nil)
    await self.scheduler.advance(by: 1)
    await store.receive(.downloadClient(.success(.response(Data())))) {
      $0.alert = nil
      $0.mode = .downloaded
    }
  }

  func testDeleteDownloadFlow() async {
    var downloadClient = DownloadClient.failing
    downloadClient.download = { _ in self.downloadStream }

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
      $0.alert = .init(
        title: .init("Do you want to delete this map from your offline storage?"),
        primaryButton: .destructive(.init("Delete"), action: .send(.deleteButtonTapped)),
        secondaryButton: .default(.init("Nevermind"), action: .send(.nevermindButtonTapped))
      )
    }

    store.send(.alert(.deleteButtonTapped)) {
      $0.alert = nil
      $0.mode = .notDownloaded
    }
  }
}

extension DownloadClient {
  static let failing = Self(
    download: { _ in .failing("DownloadClient.download") }
  )
}

extension AsyncThrowingStream where Failure == Error {
  public static func failing(_ message: String) -> Self {
    .init {
      XCTFail("Unimplemented: \(message)")
      return nil
    }
  }
}
