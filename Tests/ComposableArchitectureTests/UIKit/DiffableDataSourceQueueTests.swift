#if canImport(UIKit) && !os(watchOS)
import Dispatch
import UIKit
import XCTest

@testable import ComposableArchitecture

class CollectionView: UICollectionView {
  override func reloadData() {
    super.reloadData()
    mainActorNow {
      XCTAssertTrue(Thread.isMainThread)
    }
  }
}

@available(iOS 13.0, *)
final class DiffableDataSourceQueueTests: BaseTCATestCase {
  @MainActor
  func testDiffableDataSourceWithMainActorNow() async {
    let collectionView = CollectionView(
      frame: .init(x: 0, y: 0, width: 10, height: 10),
      collectionViewLayout: UICollectionViewFlowLayout()
    )
    collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")

    let dataSource = UICollectionViewDiffableDataSource<Int, Int>(
      collectionView: collectionView
    ) { collectionView, indexPath, item in
      collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
    }

    var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
    snapshot.appendSections([0])
    snapshot.appendItems([1])
    dataSource.apply(snapshot, animatingDifferences: true)
  }
}

#endif
