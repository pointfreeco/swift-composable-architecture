import UIKit
import Combine

public protocol ViewControllerPresentable: UIViewController {
	var onDismiss: (@MainActor () -> Void)? { get set }
}

extension ViewControllerPresentable {
	@MainActor
	func checkDismissedIfNeeded() {
		guard self.isBeingDismissed else { return }
		defer { onDismiss = nil }
		onDismiss?()
	}
}

extension ViewControllerPresentable {
	@MainActor
	public func presentation<State: Equatable, Action>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		_ toDestinationController: @escaping (State, Store<State, Action>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		self.presentation(store, id: { $0.id }, toDestinationController)
	}
	
	@MainActor
	func presentation<State: Equatable, Action, ID: Hashable>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		id toID: @escaping (PresentationState<State>) -> ID?,
		_ toDestinationController: @escaping (State, Store<State, Action>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		ViewStore(store, observe: { $0 }, removeDuplicates: { toID($0) == toID($1) })
			.publisher
			.withPrevious()
			.receive(on: RunLoop.main)
			.sink { [weak self] (prevState, presentationState) in
				guard let self else { return }
				Task { @MainActor in
					var shouldDismiss: Bool = false
					var wrappedState: State? = nil
					
					switch (prevState?.wrappedValue, presentationState.wrappedValue) {
					case (.none, .none):
						return
					
					case let (.none, .some(_state)):
						shouldDismiss = false
						wrappedState = _state
					
					case let (.some, .some(_state)):
						shouldDismiss = true
						wrappedState = _state
						
					case (.some, .none):
						guard self.presentedViewController != nil else { return }
						await self.dismissAsync(animated: self.canAnimate)
						return
					}
					guard let wrappedState else { return }
					let originalId = toID(presentationState)
					let freshViewController = store.scope(
						state: returningLastNonNilValue { originalId == toID(store.state.value) ? $0.wrappedValue : nil },
						action: { .presented($0) }
					).map { toDestinationController(wrappedState, $0) } ?? PresentationViewController(nibName: nil, bundle: nil)
					freshViewController.onDismiss = { @MainActor [weak store] in
						guard let _store = store, toID(_store.state.value) == originalId else { return }
						_store.send(.dismiss)
					}
					if shouldDismiss {
						await self.dismissAsync(animated: self.canAnimate)
					}
					await self.presentAsync(freshViewController, animated: self.canAnimate)
				}
			}
	}
}

extension UIViewController {
	fileprivate var canAnimate: Bool { self.viewIfLoaded?.window != nil }
	
	@MainActor
	fileprivate func presentAsync(_ viewControllerToPresent: UIViewController, animated: Bool) async {
		await withCheckedContinuation { continuation in
			self.present(viewControllerToPresent, animated: animated) {
				continuation.resume()
			}
		}
	}
	
	@MainActor
	fileprivate func dismissAsync(animated: Bool) async {
		await withCheckedContinuation { continuation in
			self.dismiss(animated: animated) {
				continuation.resume()
			}
		}
	}
	
}

extension Store where State: Equatable {
	@MainActor
	public func map<TargetState, Target>(
		_ transform: @MainActor (Store<TargetState, Action>) -> Target
	) -> Target? where State == Optional<TargetState> {
		guard let state = ViewStore(self, observe: { $0 }).state else { return nil }
		return transform(self.scope(state: { $0 ?? state }, action: { $0 }))
	}
}

extension Publisher {
	fileprivate func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
		scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
			.compactMap { $0 }
			.eraseToAnyPublisher()
	}
	
	fileprivate func withPrevious(
		_ initialPreviousValue: Output) -> AnyPublisher<(previous: Output,
		current: Output
	), Failure> {
		scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
	}
}
