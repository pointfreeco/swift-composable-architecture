//
//  InventoryFeatureView.swift
//  
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import SwiftUI
import ComposableArchitecture
import SwiftUINavigation
import ItemRow
import Item

public struct InventoryFeatureView: View {
    let store: StoreOf<InventoryFeature>
    
    public init(store: StoreOf<InventoryFeature>) {
        self.store = store
    }
    
    struct ViewState: Equatable {
        let route: InventoryFeature.Route?
        
        init(state: InventoryFeature.State) {
            self.route = state.route
        }
    }
    
    public var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in

            List {
                ForEachStore(store.scope(
                    state: \.items,
                    action: InventoryFeature.Action.itemRow
                )) { itemRowStore in
                    ItemRowView(store: itemRowStore)
                }
            }.toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") { viewStore.send(.addButtonTapped) }
                }
            }
            .navigationTitle("Inventory")
            .sheet(
                unwrapping: viewStore.binding(
                    get: \.route,
                    send: InventoryFeature.Action.setRoute
                ),
                case: /InventoryFeature.Route.add
            ) { _ in
                IfLetStore(store.scope(state: \.route)) { routedStore in
                    SwitchStore(routedStore) {
                        ComposableArchitecture.CaseLet<
                            InventoryFeature.Route,
                            InventoryFeature.Action,
                            Item.State,
                            Item.Action,
                            NavigationView
                        >(
                            state: /InventoryFeature.Route.add,
                            action: InventoryFeature.Action.addItem
                        ) { addItemStore in
                            NavigationView {
                                ItemView(store: addItemStore)
                                    .navigationTitle("Add")
                                    .toolbar {
                                        ToolbarItem(placement: .cancellationAction) {
                                            Button("Cancel") {
                                                viewStore.send(.cancelButtonTapped)
                                            }
                                        }
                                        ToolbarItem(placement: .primaryAction) {
                                            Button("Save") {
                                                viewStore.send(.saveButtonTapped)
                                                //self.viewModel.add(item: itemToAdd)
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct InventoryFeatureView_Previews: PreviewProvider {
    static var previews: some View {
        let keyboard = Item.State(
            id: UUID(),
            name: "Keyboard",
            color: .blue,
            status: .inStock(quantity: 100)
        )
        NavigationView {
            InventoryFeatureView(store: .init(
                initialState: .init(
                    items: [
                        .init(item: keyboard, route: nil),
                        .init(
                            item: Item.State(
                                id: UUID(),
                                name: "Charger",
                                color: .yellow,
                                status: .inStock(quantity: 20)
                            ),
                            route: nil
                        ),
                        .init(
                            item: Item.State(
                                id: UUID(),
                                name: "Phone",
                                color: .green,
                                status: .outOfStock(isOnBackOrder: true)
                            ),
                            route: nil
                        ),
                        .init(
                            item: Item.State(
                                id: UUID(),
                                name: "Headphones",
                                color: .green,
                                status: .outOfStock(isOnBackOrder: false)
                            ),
                            route: nil
                        ),
                    ],
                    route: nil
                ),
                reducer: InventoryFeature()
            ))
        }
    }
}
