#if swift(>=5.4)
@testable import SwiftUICaseStudies
import XCTest

class StateBindingTests: XCTestCase {
  func testStateBindingWithStorage() {
    struct Feature {
      var external: String = ""
      var `internal`: Int = 0
    }
    struct State {
      var content: String = ""
      var _feature: Feature = .init()
      static var _feature = StateBinding(\Self._feature) {
        (\.content, \.external)
      }

      var feature: Feature {
        get { Self._feature.get(self) }
        set { Self._feature.set(&self, newValue) }
      }
    }
        
    var state = State()
    state.feature.internal = 1
    state.feature.external = "Hello!"
        
    XCTAssertEqual(state.feature.internal, 1)
    XCTAssertEqual(state.feature.external, "Hello!")
    XCTAssertEqual(state.content, "Hello!")

    state.content = "World!"
    XCTAssertEqual(state.feature.internal, 1)
    XCTAssertEqual(state.feature.external, "World!")
  }
    
  func testOptionalStateBindingWithStorage() {
    struct Feature {
      var external: String = ""
      var `internal`: Int = 0
    }
    struct State {
      var content: String = ""
      var _feature: Feature? = nil
      static var _feature = StateBinding(\Self._feature) {
        (\.content, \.external)
      }

      var feature: Feature? {
        get { Self._feature.get(self) }
        set { Self._feature.set(&self, newValue) }
      }
    }
        
    var state = State()
    state.feature = .init()
        
    state.feature?.internal = 1
    state.feature?.external = "Hello!"
        
    XCTAssertEqual(state.feature?.internal, 1)
    XCTAssertEqual(state.feature?.external, "Hello!")
    XCTAssertEqual(state.content, "Hello!")

    state.content = "World!"
    XCTAssertEqual(state.feature?.internal, 1)
    XCTAssertEqual(state.feature?.external, "World!")
        
    state._feature = nil
    state.feature?.external = "Test"
    // `content` should be unchanged as `feature` is nil.
    XCTAssertEqual(state.content, "World!")
  }
    
  func testComputedStateBinding() {
    struct Feature {
      var external: String = ""
      var `internal`: Int = 0
    }
    struct State {
      var content: String = ""
      var count = 0
            
      static var _feature = StateBinding(Self.self, with: Feature.init) {
        (\.content, \.external)
        (\.count, \.internal)
      }

      var feature: Feature {
        get { Self._feature.get(self) }
        set { Self._feature.set(&self, newValue) }
      }
    }
        
    var state = State()
    state.feature.internal = 1
    state.feature.external = "Hello!"
        
    XCTAssertEqual(state.feature.internal, 1)
    XCTAssertEqual(state.feature.external, "Hello!")
        
    state.content = "World!"
    state.count = 2
        
    XCTAssertEqual(state.feature.internal, 2)
    XCTAssertEqual(state.feature.external, "World!")
  }
    
  func testOptionalComputedStateBinding() {
    struct Feature {
      var external: String = ""
      var `internal`: Int = 0
    }
    struct State {
      var content: String = ""
      var count = 0
      var hasFeature = false
      static var _feature = StateBinding<State, Feature?>(with: { $0.hasFeature ? .init() : nil }) {
        (\.content, \.external)
        (\.count, \.internal)
      }

      var feature: Feature? {
        get { Self._feature.get(self) }
        set { Self._feature.set(&self, newValue) }
      }
    }
        
    var state = State()
    XCTAssertNil(state.feature)
        
    state.content = "World!"
    state.count = 2
        
    state.hasFeature = true

    XCTAssertEqual(state.feature?.internal, 2)
    XCTAssertEqual(state.feature?.external, "World!")
        
    state.feature?.internal = 1
    state.feature?.external = "Hello!"
        
    XCTAssertEqual(state.count, 1)
    XCTAssertEqual(state.content, "Hello!")
        
    state.hasFeature = false

    state.feature?.internal = 3
    state.feature?.external = "Test"
        
    // Should be unchanged as `feature` is nil.
    XCTAssertEqual(state.count, 1)
    XCTAssertEqual(state.content, "Hello!")
  }
  
  func testStateBindingDeDuplication() {
    struct Feature: Equatable {
      var external: String = ""
      var `internal`: Int = 0
    }
    struct State {
      var content: String = "" {
        didSet { XCTFail("`content` value was set") }
      }

      var _feature: Feature = .init() {
        didSet { XCTFail("`_feature` value was set") }
      }

      static var _feature = StateBinding(\Self._feature, removeDuplicateStorage: ==) {
        (\.content, \.external, removeDuplicates: ==)
      }

      var feature: Feature {
        get { Self._feature.get(self) }
        set { Self._feature.set(&self, newValue) }
      }
    }
        
    var state = State(content: "Hello!", _feature: .init(external: "Hello!", internal: 1))
    // This would hit didSet and fail if not deduplicated.
    state.feature.internal = 1
    state.feature.external = "Hello!"
  }
}
#endif
