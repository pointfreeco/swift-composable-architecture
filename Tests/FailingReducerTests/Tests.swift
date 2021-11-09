import Combine
import CustomDump
import XCTest
@testable import ComposableArchitecture
import Foundation

enum CustomErrorType: Error {
	case test
}

final class FailingReduecrTests: XCTestCase {
	func testCompile() {
		let reducer = Reducer<Int, Void, Void, Error> { state, _, _ in
			return Effect(error: CustomErrorType.test)
		}
	}
}

extension Reducer {
	func assertNoFailure() -> Reducer<State, Action, Environment, Never> {
		return Reducer<State, Action, Environment, Never> { state, action, environment in
			return self.run(&state, action, environment)
				.assertNoFailure()
				.eraseToEffect()
		}
	}
}

extension Reducer where Failure: Error {
	func mapFailures(_ map: @escaping (Error) -> Action) -> Reducer<State, Action, Environment, Never> {
		return Reducer<State, Action, Environment, Never> { state, action, environment in
			return self.run(&state, action, environment)
				.catch { Just(map($0)).eraseToEffect() }
				.eraseToEffect()
		}
	}
}
