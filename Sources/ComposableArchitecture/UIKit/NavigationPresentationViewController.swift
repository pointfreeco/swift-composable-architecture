//
//  NavigationPresentationViewController.swift
//  
//
//  Created by Andy Wen on 2023/7/31.
//

import UIKit

open class NavigationPresentationViewController: UINavigationController, ViewControllerPresentable {
	public var onDismiss: (() -> Void)? = nil
	
	open override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		checkDismissedIfNeeded()
	}
}
