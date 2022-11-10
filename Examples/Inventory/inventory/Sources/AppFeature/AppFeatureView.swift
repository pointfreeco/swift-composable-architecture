//
//  AppFeatureView.swift
//  
//
//  Created by Jaap Wijnen on 10/11/2022.
//

import SwiftUI
import ComposableArchitecture
import InventoryFeature

public struct AppFeatureView: View {
    let store: StoreOf<AppFeature>
    
    public init(store: StoreOf<AppFeature>) {
        self.store = store
    }
    
    struct ViewState: Equatable {
        let tab: AppFeature.Tab
        
        init(state: AppFeature.State) {
            self.tab = state.selectedTab
        }
    }
    
    public var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            TabView(selection: viewStore.binding(
                get: \.tab,
                send: AppFeature.Action.setTab
            )) {
                InventoryFeatureView(store: store.scope(
                    state: \.inventory,
                    action: AppFeature.Action.inventory
                ))
                .tag(AppFeature.Tab.inventory)
                .tabItem {
                    Label("Inventory", systemImage: "building.2")
                }
            }
        }
    }
}

struct AppFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        AppFeatureView(store: .init(
            initialState: .init(
                selectedTab: .inventory,
                inventory: .init(
                    items: [
                        .init(
                            item: .init(
                                id: UUID(),
                                name: "Keyboard",
                                color: .red,
                                status: .inStock(quantity: 23)
                            ),
                            route: nil
                        )
                    ],
                    route: nil
                )
            ),
            reducer: AppFeature()
        ))
    }
}
