#if compiler(>=5.4)
  import XCTest

  @testable import ComposableArchitecture
  final class EffectIDTests: XCTestCase {
    @EffectID var id1
    @EffectID var id2_1 = 1
    @EffectID var id2_2 = 1

    override func setUp() {
      super.setUp()
      #if canImport(_Concurrency) && compiler(>=5.5.2)
      #else
        // Set a context to avoid runtime warnings
        mainThreadStoreCurrentContextID = 0
        currentStoreContextIDLock.sync {
          currentStoreContextID = 0
        }
      #endif
    }

    override func tearDown() {
      #if canImport(_Concurrency) && compiler(>=5.5.2)
      #else
        currentStoreContextIDLock.sync {
          currentStoreContextID = nil
        }
        mainThreadStoreCurrentContextID = nil
      #endif

      super.tearDown()
    }

    func testEffectIdentifierEquality() {
      #if canImport(_Concurrency) && compiler(>=5.5.2)
        EffectID.$currentContextID.withValue(0) {
          _testEffectIdentifierEquality()
        }
      #else
        _testEffectIdentifierEquality()
      #endif
    }
    
    func _testEffectIdentifierEquality(file: StaticString = #fileID, line: UInt = #line) {
      XCTAssertEqual(id1, id1)
      XCTAssertEqual(id2_1, id2_1)
      XCTAssertEqual(id2_2, id2_2)

      XCTAssertNotEqual(id1, id2_1)
      XCTAssertNotEqual(id1, id2_2)
      XCTAssertNotEqual(id2_1, id2_2)
    }

    #if compiler(>=5.5)
      func testLocalEffectIdentifierEquality() {
        #if canImport(_Concurrency) && compiler(>=5.5.2)
          EffectID.$currentContextID.withValue(0) {
            _testLocalEffectIdentifierEquality()
          }
        #else
          _testLocalEffectIdentifierEquality()
        #endif
      }

      func _testLocalEffectIdentifierEquality() {
        @EffectID var id1
        @EffectID var id2_1 = 1
        @EffectID var id2_2 = 1

        XCTAssertEqual(id1, id1)
        XCTAssertEqual(id2_1, id2_1)
        XCTAssertEqual(id2_2, id2_2)

        XCTAssertNotEqual(id1, id2_1)
        XCTAssertNotEqual(id1, id2_2)
        XCTAssertNotEqual(id2_1, id2_2)

        XCTAssertNotEqual(id1, self.id1)
      }
    #endif
  }
#endif
