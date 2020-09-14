import Combine
import ComposableArchitecture
import XCTest

final class QueuingTests: XCTestCase {

  func testQueuing() {
    let service = Service()

    let store = Store(
      initialState: State(toggle: .off),
      reducer: reducer,
      environment: Environment(
        service: service
      )
    )
    let viewStore = ViewStore(store)

    viewStore.send(.`init`)
    viewStore.send(.sendUUIDTapped)
    XCTAssertEqual(.init(toggle: .on), viewStore.state)

    viewStore.send(.sendNilTapped)
    XCTAssertEqual(.init(toggle: .off), viewStore.state)


//    store.assert(
//      .send(.`init`),
//      .send(.sendUUIDTapped),
//      .receive(.receiveServiceResult("A")) {
//        $0.toggle = .on
//      },
//      .send(.sendNilTapped),
//      .receive(.receiveServiceResult(nil)) {
//        $0.toggle = .off
//      },
//      .do { service.subject.send(completion: .finished)}
//    )
  }
}


final class Service {
  let subject = PassthroughSubject<String?, Never>()
  
  func publisher(for id: String) -> Effect<String?, Never> {
    subject.eraseToEffect()
  }
  
  func trigger(value: String?) {
    subject.send(value)
  }
}

enum Actions: Equatable {
  case `init`
  case sendNilTapped
  case sendUUIDTapped
  case receiveServiceResult(String?)
}

enum Toggle: String, Equatable {
  case on
  case off
}

struct State: Equatable {
  var toggle: Toggle
}

struct Environment {
  var service: Service
}

let reducer = Reducer<State, Actions, Environment> { state, action, environment in
  switch action {
  case .`init`:
    return environment.service.publisher(for: "my id")
      .map(Actions.receiveServiceResult)
    
  case .sendNilTapped:
    environment.service.trigger(value: nil)
    return .none
    
  case .sendUUIDTapped:
    environment.service.trigger(value: "A")
    return .none
    
  case let .receiveServiceResult(result):
    state.toggle = result != nil ? .on : .off
    return .none
  }
}
