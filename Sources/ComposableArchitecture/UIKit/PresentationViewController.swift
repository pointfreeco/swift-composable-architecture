import UIKit
import Combine

public protocol ViewControllerPresentable: UIViewController {
	typealias DismissAction = () -> Void

	var onDismiss: (() -> Void)? { get set }
	var dismissActions: Dictionary<UIViewController, DismissAction> { get set }
}

extension ViewControllerPresentable {
	func presentation<State, Action, DestinationState: Equatable, DestinationAction, ID: Hashable>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		id toID: @escaping (PresentationState<State>) -> ID?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		style presentationStyle: UIModalPresentationStyle,
		_ toDestinationController: @escaping (Store<DestinationState, DestinationAction>) -> any ViewControllerPresentable
	) -> AnyCancellable {
		var targetViewController: UIViewController?
		return store
			.invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
			.publisher
			.receive(on: RunLoop.main)
			.sink { [weak self] in
				guard let self else { return }
				if $0.wrappedValue.flatMap(toDestinationState) != nil {
					let viewController: UIViewController = store.scope(
						state: { $0.wrappedValue.flatMap(toDestinationState) },
						action: { .presented(fromDestinationAction($0)) }
					).map(toDestinationController) ?? UIViewController()
					defer { targetViewController = viewController }
					self.dismissActions[viewController] = { store.send(.dismiss) }
					viewController.modalPresentationStyle = presentationStyle
					(viewController as? ViewControllerPresentable)?.onDismiss = { [weak store] in store?.send(.dismiss) }
					self.present(viewController, animated: self.viewIfLoaded?.window != nil)
				} else {
					guard let _presentedViewController = targetViewController else { return }
					defer { targetViewController = nil }	// remove capture
					self.dismissActions.removeValue(forKey: _presentedViewController)
					_presentedViewController.dismiss(animated: self.viewIfLoaded?.window != nil)
				}
			}
	}
}

// Some handy tools for modal presentation
extension ViewControllerPresentable {
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
	public func map<TargetState, Target>(
		_ transform: (Store<TargetState, Action>) -> Target
	) -> Target? where State == Optional<TargetState> {
		guard let state = ViewStore(self, observe: { $0 }).state else { return nil }
		return transform(self.scope(state: { $0 ?? state }, action: { $0 }))
	}
}

open class PresentationViewController: UIViewController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	public var dismissActions: Dictionary<UIViewController, DismissAction> = .init()
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if isBeingDismissed { self.onDismiss?() }
	}
}

open class NavigationPresentationViewController: UINavigationController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	public var dismissActions: Dictionary<UIViewController, DismissAction> = .init()
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		if isBeingDismissed { self.onDismiss?() }
	}
}
