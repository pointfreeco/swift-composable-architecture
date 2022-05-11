import ComposableArchitecture
import XCTest

@testable import SwiftUICaseStudies

@MainActor
class DemoTests: XCTestCase {
  func testBasics() async {
    let store = TestStore(
      initialState: .init(),
      reducer: reducer,
      environment: .init(
        number: .init(
          fact: { "\($0) is a good number" },
          random: { 42 }
        )
      )
    )

    store.send(.incrementButtonTapped) {
      $0.count = 1
    }
    store.send(.incrementButtonTapped) {
      $0.count = 2
    }
    store.send(.factButtonTaped)
    // await Task.yield()
    await store.receive(.factResponse(.success("2 is a good number"))) {
      $0.fact = "2 is a good number"
    }
  }

  @MainActor
  func testRandom() async {
    let store = TestStore( 
      initialState: .init(),
      reducer: reducer,
      environment: .init(
        number: .init(
          fact: { @MainActor in "\($0) is a good number" },
          random: { @MainActor in 42 }
        )
      )
    ) 

    store.send(.randomButtonTapped)
    
    await store.receive(.progress(0)) {
      $0.progress = 0
    }
    await store.receive(.progress(0.5)) {
      $0.progress = 0.5
    }
    await store.receive(.factResponse(.success("42 is a good number"))) {
      $0.fact = "42 is a good number"
    }
    await store.receive(.progress(1)) {
      $0.progress = 1
    }
    await store.receive(.progress(nil)) {
      $0.progress = nil
    }
  }


  func testTime() async {
    let scheduler = DispatchQueue.test
    let store = TestStore(
      initialState: 0,
      reducer: .init { (state: inout Int, action: Bool, _: Void) in
        switch action {
        case true:
          state += 1
          return .task { @MainActor in 
            false
          }
          .delay(for: 1, scheduler: scheduler)
//          .debounce(id: "", for: 1, scheduler: scheduler)
          .eraseToEffect()

        case false:
          state -= 1
          return .none
        }
      },
      environment: ()
    )

    store.send(true) {
      $0 = 1
    }
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await Task.yield()
    scheduler.advance(by: .seconds(1))
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await Task.yield()
    await store.receive(false) {
      $0 = 0
    }
  }

  func testIsEquatable() {
    XCTAssertTrue(isEquatable(1))
    XCTAssertTrue(isEquatable("Hello"))
    XCTAssertTrue(isEquatable([1, 2, 3]))
    XCTAssertTrue(isEquatable([1: "one"]))
    XCTAssertTrue(isEquatable(["message": "Something went wrong."]))
    XCTAssertFalse(isEquatable(()))

    XCTAssertTrue(isEquatable([[1], [2], [3]]))
    XCTAssertTrue(isEquatable(["1", "2", "3"]))
    XCTAssertTrue(isEquatable([[[1]], [[2]], [[3]]]))

    XCTAssertTrue(SwiftUICaseStudiesTests.isEqual(1, 1))
    XCTAssertFalse(SwiftUICaseStudiesTests.isEqual((), ()))

    struct Foo: Error {}
    XCTAssertFalse(SwiftUICaseStudiesTests.isEqual(Foo(), Foo()))

    struct Bar: Error, Equatable {}
    XCTAssertTrue(SwiftUICaseStudiesTests.isEqual(Bar(), Bar()))
  }
}

protocol AnyEquatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
}

func isEquatable(_ a: Any) -> Bool {
  func `do`<A>(_: A.Type) -> Bool {
    Box<A>.self is AnyEquatable.Type
  }
  return _openExistential(type(of: a), do: `do`)
}

enum Box<A> {}
extension Box: AnyEquatable where A: Equatable {
  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool {
    guard
      let lhs = lhs as? A,
      let rhs = rhs as? A
    else { return false }
    return lhs == rhs
  }
}


func isEqual(_ a: Any, _ b: Any) -> Bool {
  guard type(of: a) == type(of: b)
  else { return false }

  func `do`<A>(_: A.Type) -> Bool {
    (Box<A>.self as? AnyEquatable.Type)?.isEqual(a, b) ?? false
  }
  return _openExistential(type(of: a), do: `do`)
}




//func isEquatable(_ a: Any) -> Bool {
//  func open<A>(_: A.Type) -> Bool {
//    let x = Box<A>.self as? AnyEquatable.Type
//    return x != nil
//  }
//  return _openExistential(type(of: a), do: open)
//}
//private enum Box<T> {}
//private protocol AnyEquatable {
////  static func isEqual(_ lhs: Any, _ rhs: Any) -> Bool
//}
//extension Box: AnyEquatable where T: Equatable {}

