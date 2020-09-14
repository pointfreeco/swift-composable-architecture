import Combine
import ComposableArchitecture
import XCTest

final class QueuingTests: XCTestCase {

  func testQueuing() {
    let subject = PassthroughSubject<Void, Never>()

    enum Action: Equatable {
      case incrementTapped
      case `init`
      case doIncrement
    }

    let store = TestStore(
      initialState: 0,
      reducer: Reducer<Int, Action, Void> { state, action, _ in
        switch action {
        case .incrementTapped:
          subject.send()
          return .none

        case .`init`:
          return subject.map { .doIncrement }.eraseToEffect()

        case .doIncrement:
          state += 1
          return .none
        }
      },
      environment: ()
    )

    store.assert(
      .send(.`init`),
      .send(.incrementTapped),
      .receive(.doIncrement) {
        $0 = 1
      },
      .send(.incrementTapped),
      .receive(.doIncrement) {
        $0 = 2
      },
      .do { subject.send(completion: .finished) }
    )
  }
}
