import UIKit

final class ActivityIndicatorViewController: UIViewController {
  override func viewDidLoad() {
    super.viewDidLoad()

    self.view.backgroundColor = .white

    let activityIndicator = UIActivityIndicatorView()
    activityIndicator.startAnimating()
    activityIndicator.translatesAutoresizingMaskIntoConstraints = false
    self.view.addSubview(activityIndicator)

    NSLayoutConstraint.activate([
      activityIndicator.centerXAnchor.constraint(
        equalTo: self.view.safeAreaLayoutGuide.centerXAnchor),
      activityIndicator.centerYAnchor.constraint(
        equalTo: self.view.safeAreaLayoutGuide.centerYAnchor),
    ])
  }
}
