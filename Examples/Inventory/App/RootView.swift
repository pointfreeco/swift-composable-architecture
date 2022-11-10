//
//  RootView.swift
//  Inventory
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import ComposableArchitecture
import AppFeature
import SwiftUI

private let readMe = """
  
  """

struct RootView: View {
    let store = Store(
        initialState: AppFeature.State(
            selectedTab: .inventory,
            inventory: .init(
                items: [],
                route: nil
            )
        ),
        reducer: AppFeature()._printChanges()
    )
    
    var body: some View {
        NavigationView {
            AppFeatureView(store: store)
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
