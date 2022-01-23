#if compiler(>=5.4)
  import XCTest

  @testable import ComposableArchitecture
  final class EffectIDTests: XCTestCase {
    @EffectID var id1
    @EffectID var id2_1 = 1
    @EffectID var id2_2 = 1

    override func setUp() {
      super.setUp()
      // Set a context to avoid runtime warnings
      currentStoreContextID = 0
    }

    override func tearDown() {
      currentStoreContextID = nil
      super.tearDown()
    }

    func testEffectIdentifierEquality() {
      XCTAssertEqual(id1, id1)
      XCTAssertEqual(id2_1, id2_1)
      XCTAssertEqual(id2_2, id2_2)

      XCTAssertNotEqual(id1, id2_1)
      XCTAssertNotEqual(id1, id2_2)
      XCTAssertNotEqual(id2_1, id2_2)
    }
    
    #if compiler(>=5.5)
    func testLocalEffectIdentifierEquality() {
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
