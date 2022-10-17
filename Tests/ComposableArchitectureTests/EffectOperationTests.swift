#if DEBUG
  import XCTest

  @testable import ComposableArchitecture

  @MainActor
  class EffectOperationTests: XCTestCase {
    func testMergeDiscardsNones() async {
      var effect = EffectTask<Int>.none
        .merge(with: .none)
      switch effect.operation {
      case .none:
        XCTAssertTrue(true)
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.run { await $0(42) }
        .merge(with: .none)
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.none
        .merge(with: .run { await $0(42) })
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.run { await $0(42) }
        .merge(with: .none)
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.none
        .merge(with: .run { await $0(42) })
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }
    }

    func testConcatenateDiscardsNones() async {
      var effect = EffectTask<Int>.none
        .concatenate(with: .none)
      switch effect.operation {
      case .none:
        XCTAssertTrue(true)
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.run { await $0(42) }
        .concatenate(with: .none)
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.none
        .concatenate(with: .run { await $0(42) })
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.run { await $0(42) }
        .concatenate(with: .none)
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }

      effect = EffectTask<Int>.none
        .concatenate(with: .run { await $0(42) })
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, 42) }))
      default:
        XCTFail()
      }
    }

    func testMergeFuses() async {
      var values = [Int]()

      let effect = EffectTask<Int>.run { send in
        try await Task.sleep(nanoseconds: NSEC_PER_SEC / 10)
        await send(42)
      }
      .merge(
        with: .run { send in
          try await Task.sleep(nanoseconds: NSEC_PER_SEC / 2)
          await send(1729)
        }
      )
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { values.append($0) }))
      default:
        XCTFail()
      }

      XCTAssertEqual(values, [42, 1729])
    }

    func testConcatenateFuses() async {
      var values = [Int]()

      let effect = EffectTask<Int>.run { await $0(42) }
        .concatenate(with: .run { await $0(1729) })
      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { values.append($0) }))
      default:
        XCTFail()
      }

      XCTAssertEqual(values, [42, 1729])
    }

    func testMap() async {
      let effect = EffectTask<Int>.run { await $0(42) }
        .map { "\($0)" }

      switch effect.operation {
      case let .run(_, send):
        await send(.init(send: { XCTAssertEqual($0, "42") }))
      default:
        XCTFail()
      }
    }
  }
#endif
