#if canImport(Perception) && canImport(ObjectiveC) && !canImport(UIKit)
  import Foundation
  import ObjectiveC
  import SwiftNavigation

  extension NSObject {
    /// Observe access to properties of a `@Perceptible` or `@Observable` object.
    ///
    /// This tool allows you to set up an observation loop so that you can access fields from an
    /// observable model in order to populate your view, and also automatically track changes to
    /// any accessed fields so that the view is always up-to-date.
    ///
    /// It is most useful when dealing with non-SwiftUI views, such as UIKit views and controller.
    /// You can invoke the ``observe(_:)`` method a single time in the `viewDidLoad` and update all
    /// the view elements:
    ///
    /// ```swift
    /// override func viewDidLoad() {
    ///   super.viewDidLoad()
    ///
    ///   let countLabel = UILabel()
    ///   let incrementButton = UIButton(primaryAction: .init { _ in
    ///     store.send(.incrementButtonTapped)
    ///   })
    ///
    ///   observe { [weak self] in
    ///     guard let self
    ///     else { return }
    ///
    ///     countLabel.text = "\(store.count)"
    ///   }
    /// }
    /// ```
    ///
    /// This closure is immediately called, allowing you to set the initial state of your UI
    /// components from the feature's state. And if the `count` property in the feature's state is
    /// ever mutated, this trailing closure will be called again, allowing us to update the view
    /// again.
    ///
    /// Generally speaking you can usually have a single ``observe(_:)`` in the entry point of your
    /// view, such as `viewDidLoad` for `UIViewController`. This works even if you have many UI
    /// components to update:
    ///
    /// ```swift
    /// override func viewDidLoad() {
    ///   super.viewDidLoad()
    ///
    ///   observe { [weak self] in
    ///     guard let self
    ///     else { return }
    ///
    ///     countLabel.isHidden = store.isObservingCount
    ///     if !countLabel.isHidden {
    ///       countLabel.text = "\(store.count)"
    ///     }
    ///     factLabel.text = store.fact
    ///   }
    /// }
    /// ```
    ///
    /// This does mean that you may execute the line `factLabel.text = store.fact` even when something
    /// unrelated changes, such as `store.count`, but that is typically OK for simple properties of
    /// UI components. It is not a performance problem to repeatedly set the `text` of a label or
    /// the `isHidden` of a button.
    ///
    /// However, if there is heavy work you need to perform when state changes, then it is best to
    /// put that in its own ``observe(_:)``. For example, if you needed to reload a table view or
    /// collection view when a collection changes:
    ///
    /// ```swift
    /// override func viewDidLoad() {
    ///   super.viewDidLoad()
    ///
    ///   observe { [weak self] in
    ///     guard let self
    ///     else { return }
    ///
    ///     self.dataSource = store.items
    ///     self.tableView.reloadData()
    ///   }
    /// }
    /// ```
    ///
    /// ## Navigation
    ///
    /// The ``observe(_:)`` method makes it easy to drive navigation from state. To do so you need
    /// a reference to the controller that you are presenting (held as an optional), and when state
    /// becomes non-`nil` you assign and present the controller, and when state becomes `nil` you
    /// dismiss the controller and `nil` out the reference.
    ///
    /// For example, if your feature's state holds onto alert state, then an alert can be presented
    /// and dismissed with the following:
    ///
    /// ```swift
    /// override func viewDidLoad() {
    ///   super.viewDidLoad()
    ///
    ///   var alertController: UIAlertController?
    ///
    ///   observe { [weak self] in
    ///     guard let self
    ///     else { return }
    ///
    ///     if
    ///       let store = store.scope(state: \.alert, action: \.alert),
    ///       alertController == nil
    ///     {
    ///       alertController = UIAlertController(store: store)
    ///       present(alertController!, animated: true, completion: nil)
    ///     } else if store.alert == nil, alertController != nil {
    ///       alertController?.dismiss(animated: true)
    ///       alertController = nil
    ///     }
    ///   }
    /// }
    /// ```
    ///
    /// Here we are using the ``Store/scope(state:action:)-36e72`` operator for optional state in
    /// order to detect when the `alert` state flips from `nil` to non-`nil` and vice-versa.
    ///
    /// ## Cancellation
    ///
    /// The method returns a ``ObserveToken`` that can be used to cancel observation. For example,
    /// if you only want to observe while a view controller is visible, you can start observation in
    /// the `viewWillAppear` and then cancel observation in the `viewWillDisappear`:
    ///
    /// ```swift
    /// var observation: ObserveToken?
    ///
    /// func viewWillAppear() {
    ///   super.viewWillAppear()
    ///   self.observation = observe { [weak self] in
    ///     // ...
    ///   }
    /// }
    /// func viewWillDisappear() {
    ///   super.viewWillDisappear()
    ///   self.observation?.cancel()
    /// }
    /// ```
    @discardableResult
    @_disfavoredOverload
    public func observe(_ apply: @escaping () -> Void) -> ObserveToken {
      let token = ObserveToken()
      self.tokens.insert(token)
      @Sendable func onChange() {
        guard !token.isCancelled
        else { return }

        withPerceptionTracking(apply) {
          Task { @MainActor in
            guard !token.isCancelled
            else { return }
            onChange()
          }
        }
      }
      onChange()
      return token
    }

    fileprivate var tokens: Set<ObserveToken> {
      get {
        (objc_getAssociatedObject(self, &NSObject.tokensHandle) as? Set<ObserveToken>) ?? []
      }
      set {
        objc_setAssociatedObject(
          self,
          &NSObject.tokensHandle,
          newValue,
          .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
      }
    }

    private static var tokensHandle: UInt8 = 0
  }
#endif
