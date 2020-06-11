import RxSwift
import RxTest
import XCTest

@testable import ComposableArchitecture

final class EffectTests: XCTestCase {
  var disposeBag = DisposeBag()
  let scheduler = TestScheduler.default()

  func testConcatenate() {
    var values: [Int] = []

    let effect = Effect<Int>.concatenate(
        Effect(value: 1).delay(.seconds(1), scheduler: scheduler).eraseToEffect(),
        Effect(value: 2).delay(.seconds(2), scheduler: scheduler).eraseToEffect(),
        Effect(value: 3).delay(.seconds(3), scheduler: scheduler).eraseToEffect()
    )

    effect
      .subscribe(onNext: { values.append($0) })
      .disposed(by: disposeBag)

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: 2)
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: 3)
    XCTAssertEqual(values, [1, 2, 3])

    self.scheduler.run()
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testConcatenateOneEffect() {
    var values: [Int] = []

    let effect = Effect<Int>.concatenate(
        Effect(value: 1).delay(.seconds(1), scheduler: scheduler).eraseToEffect()
    )

    effect
      .subscribe(onNext: { values.append($0) })
      .disposed(by: disposeBag)

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.run()
    XCTAssertEqual(values, [1])
  }

  func testMerge() {
    let effect = Effect<Int>.merge(
        Effect(value: 1).delay(.seconds(1), scheduler: scheduler).eraseToEffect(),
        Effect(value: 2).delay(.seconds(2), scheduler: scheduler).eraseToEffect(),
        Effect(value: 3).delay(.seconds(3), scheduler: scheduler).eraseToEffect()
    )

    var values: [Int] = []
    effect
      .subscribe(onNext: { values.append($0) })
      .disposed(by: disposeBag)

    XCTAssertEqual(values, [])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1, 2])

    self.scheduler.advance(by: 1)
    XCTAssertEqual(values, [1, 2, 3])
  }

  func testEffectSubscriberInitializer() {
    let effect = Effect<Int>.run { subscriber in
      subscriber.onNext(1)
      subscriber.onNext(2)

      self.scheduler.scheduleRelative((), dueTime: .seconds(1)) {
        subscriber.onNext(3)
        return Disposables.create()
      }
      .disposed(by: self.disposeBag)

      self.scheduler.scheduleRelative((), dueTime: .seconds(2)) {
        subscriber.onNext(4)
        subscriber.onCompleted()
        return Disposables.create()
      }
      .disposed(by: self.disposeBag)

      return Disposables.create()
    }

    var values: [Int] = []
    var isComplete = false
    effect
        .subscribe(onNext: { values.append($0) }, onCompleted: { isComplete = true })
        .disposed(by: disposeBag)

    XCTAssertEqual(values, [1, 2])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3])
    XCTAssertEqual(isComplete, false)

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1, 2, 3, 4])
    XCTAssertEqual(isComplete, true)
  }

  func testEffectSubscriberInitializer_WithCancellation() {
    struct CancelId: Hashable {}

    let effect = Effect<Int>.run { observer in
      observer.onNext(1)

      self.scheduler.scheduleRelative((), dueTime: .seconds(1)) {
        observer.onNext(2)
        return Disposables.create()
      }
      .disposed(by: self.disposeBag)

      return Disposables.create()
    }
    .cancellable(id: CancelId())

    var values: [Int] = []
    var isComplete = false
    effect
        .subscribe(onNext: { values.append($0) }, onCompleted: { isComplete = true })
        .disposed(by: disposeBag)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, false)

    Effect<Void>.cancel(id: CancelId())
      .subscribe(onNext: {})
      .disposed(by: disposeBag)

    self.scheduler.advance(by: 1)

    XCTAssertEqual(values, [1])
    XCTAssertEqual(isComplete, true)
  }
}
