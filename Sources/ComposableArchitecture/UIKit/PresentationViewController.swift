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
					switch (prevState?.wrappedValue, presentationState.wrappedValue) {
					case (.none, .none): return
					case (.some, .none):
						guard self.presentedViewController != nil else { return }
						await self.dismissAsync(animated: self.canAnimate)

					case let (.none, .some(wrappedState)):
						let freshViewController = store.scope(
							state: returningLastNonNilValue { $0.wrappedValue },
							action: { .presented($0) }
						).map { toDestinationController(wrappedState, $0) } ?? PresentationViewController(nibName: nil, bundle: nil)
						let originalId = toID(presentationState)
						freshViewController.onDismiss = { @MainActor [weak store] in
							guard let _store = store, toID(_store.state.value) == originalId else { return }
							_store.send(.dismiss)
						}
						await self.presentAsync(freshViewController, animated: self.canAnimate)
						
					case let (.some, .some(wrappedState)):
						let freshViewController = store.scope(
							state: returningLastNonNilValue { $0.wrappedValue },
							action: { .presented($0) }
						).map { toDestinationController(wrappedState, $0) } ?? PresentationViewController(nibName: nil, bundle: nil)
						let originalId = toID(presentationState)
						freshViewController.onDismiss = { @MainActor [weak store] in
							guard let _store = store, toID(_store.state.value) == originalId else { return }
							_store.send(.dismiss)
						}
						await self.dismissAsync(animated: self.canAnimate)
						await self.presentAsync(freshViewController, animated: self.canAnimate)
					}
				}
			}
	}
	
	@MainActor
	func presentation<State, Action, DestinationState: Equatable, DestinationAction, ID: Hashable>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		id toID: @escaping (PresentationState<State>) -> ID?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		style presentationStyle: UIModalPresentationStyle,
		_ toDestinationController: @escaping (Store<DestinationState, DestinationAction>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		var targetViewController: UIViewController?
		let store = store.invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
		let viewStore = ViewStore(store, observe: { $0 }, removeDuplicates: { toID($0) == toID($1) })
		return viewStore.publisher
			.receive(on: RunLoop.main)
			.sink { [weak self] (presentationState: PresentationState<State>) in
				guard let self else { return }
				Task { @MainActor in
					if presentationState.wrappedValue.flatMap(toDestinationState) != nil {
						let viewController: UIViewController = store.scope(
							state: returningLastNonNilValue { $0.wrappedValue.flatMap(toDestinationState) },
							action: { .presented(fromDestinationAction($0)) }
						).map(toDestinationController) ?? UIViewController()
						defer { targetViewController = viewController }
						viewController.modalPresentationStyle = presentationStyle
						(viewController as? ViewControllerPresentable)?.onDismiss = { @MainActor [weak store] in
							guard let _store = store,
										let _state = _store.state.value.wrappedValue,
										toDestinationState(_state) != nil
							else { return }
							_store.send(.dismiss)
						}
						if self.presentedViewController != nil {
							await self.dismissAsync(animated: self.canAnimate)
						}
						await self.presentAsync(viewController, animated: self.canAnimate)
					} else {
						guard let _presentedViewController = targetViewController,
									self.presentedViewController == _presentedViewController,
									!_presentedViewController.isBeingDismissed
						else { return }
						defer { targetViewController = nil }	// remove capture
						await _presentedViewController.dismissAsync(animated: self.canAnimate)
					}
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

// Some handy tools for modal presentation
extension ViewControllerPresentable {
	@MainActor
	public func presentSheet<State, Action, DestinationState: Equatable, DestinationAction>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		_ destination: @escaping (Store<DestinationState, DestinationAction>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		return self.presentation(
			store,
			state: toDestinationState,
			id: { $0.id },
			action: fromDestinationAction,
			style: .pageSheet,
			destination
		)
	}
	
	@MainActor
	public func presentFullScreen<State, Action, DestinationState: Equatable, DestinationAction>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		_ destination: @escaping (Store<DestinationState, DestinationAction>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		return self.presentation(
			store,
			state: toDestinationState,
			id: { $0.id },
			action: fromDestinationAction,
			style: .fullScreen,
			destination
		)
	}
	
	@MainActor
	public func presentOverFullScreen<State, Action, DestinationState: Equatable, DestinationAction>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		_ destination: @escaping (Store<DestinationState, DestinationAction>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		return self.presentation(
			store,
			state: toDestinationState,
			id: { $0.id },
			action: fromDestinationAction,
			style: .overFullScreen,
			destination
		)
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

open class PresentationViewController: UIViewController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	public var presentationSemaphore: DispatchSemaphore = .init(value: 1)
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}

open class NavigationPresentationViewController: UINavigationController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	public var presentationSemaphore: DispatchSemaphore = .init(value: 1)
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}

extension Publisher {
	func withPrevious() -> AnyPublisher<(previous: Output?, current: Output), Failure> {
		scan(Optional<(Output?, Output)>.none) { ($0?.1, $1) }
			.compactMap { $0 }
			.eraseToAnyPublisher()
	}

	func withPrevious(_ initialPreviousValue: Output) -> AnyPublisher<(previous: Output, current: Output), Failure> {
		scan((initialPreviousValue, initialPreviousValue)) { ($0.1, $1) }.eraseToAnyPublisher()
	}
}
