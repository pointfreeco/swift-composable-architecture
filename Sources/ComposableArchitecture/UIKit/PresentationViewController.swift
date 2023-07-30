import UIKit
import Combine

open class PresentationViewController: UIViewController {
	typealias DismissAction = () -> Void
	private var dismissActions: Dictionary<UIViewController, DismissAction> = .init()
	
	func presentation<State, Action, DestinationState: Equatable, DestinationAction, ID: Hashable>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		id toID: @escaping (PresentationState<State>) -> ID?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		style presentationStyle: UIModalPresentationStyle,
		_ toDestinationController: @escaping (Store<DestinationState, DestinationAction>) -> UIViewController
	) -> AnyCancellable {
		var targetViewController: UIViewController?
		return store
			.invalidate { $0.wrappedValue.flatMap(toDestinationState) == nil }
			.publisher
			.receive(on: RunLoop.main)
			.sink { [weak self] in
				guard let self else { return }
				if $0.wrappedValue.flatMap(toDestinationState) != nil {
					let viewController = toDestinationController(store.scope(
						state: { $0.wrappedValue.flatMap(toDestinationState)! },	// force wrap because checked before
						action: { .presented(fromDestinationAction($0)) }
					))
					defer { targetViewController = viewController }
					viewController.presentationController?.delegate = self
					viewController.transitioningDelegate = self
					self.dismissActions[viewController] = { store.send(.dismiss) }
					viewController.modalPresentationStyle = presentationStyle
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
extension PresentationViewController {
	public func presentSheet<State, Action, DestinationState: Equatable, DestinationAction>(
		_ store: Store<PresentationState<State>, PresentationAction<Action>>,
		state toDestinationState: @escaping (State) -> DestinationState?,
		action fromDestinationAction: @escaping (DestinationAction) -> Action,
		_ destination: @escaping (Store<DestinationState, DestinationAction>) -> UIViewController
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
		_ destination: @escaping (Store<DestinationState, DestinationAction>) -> UIViewController
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
		_ destination: @escaping (Store<DestinationState, DestinationAction>) -> UIViewController
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

extension PresentationViewController: UIViewControllerTransitioningDelegate {
	/// This is required for dismissed programatically
	/// this will called everytime when you dismiss a presented view controller
	public func animationController(
		forDismissed dismissed: UIViewController
	) -> UIViewControllerAnimatedTransitioning? {
		guard let dismiss = dismissActions[dismissed] else { return nil }
		defer { dismissActions.removeValue(forKey: dismissed) }
		dismiss()
		return nil
	}
}

extension PresentationViewController: UIAdaptivePresentationControllerDelegate {
	/// This is required for interactively pull down dismiss
	/// this will not get called if you just call `dismiss(animated:, completion:)` from the presentedViewController
	public func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
		let targetViewController = presentationController.presentedViewController
		guard let dismiss = dismissActions[targetViewController] else { return }
		defer { dismissActions.removeValue(forKey: targetViewController) }
		dismiss()
	}
}

extension Store where State: Equatable {
	fileprivate func map<TargetState, Target>(
		_ transform: (Store<TargetState, Action>) -> Target
	) -> Target? where State == Optional<TargetState> {
		guard let state = ViewStore(self, observe: { $0 }).state else { return nil }
		return transform(self.scope(state: { $0 ?? state }, action: { $0 }))
	}
}
