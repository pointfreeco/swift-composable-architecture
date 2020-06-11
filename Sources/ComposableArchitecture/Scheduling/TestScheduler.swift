import Foundation
import RxSwift
import RxTest

private let testSchedulerResultion = 0.01

public extension TestScheduler {

    static func `default`(withInitialClock initialClock: Int = 0) -> TestScheduler {
        TestScheduler(initialClock: initialClock, resolution: testSchedulerResultion, simulateProcessingDelay: false)
    }

    func advance(by: TimeInterval = 0) {
        self.advanceTo(self.clock + Int(by * (1 / testSchedulerResultion)))
    }

    func tick() {
        self.advanceTo(self.clock + 1)
    }

    func run() {
        self.advanceTo(Int(Date.distantFuture.timeIntervalSince1970))
    }

}
