//
//  ItemRowView.swift
//  
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import SwiftUI
import ComposableArchitecture
import Item
import SwiftUINavigation

public struct ItemRowView: View {
    let store: StoreOf<ItemRow>
    
    public init(store: StoreOf<ItemRow>) {
        self.store = store
    }
    
    struct ViewState: Equatable {
        let name: String
        let status: Item.Status
        let color: Item.Color?
        let route: ItemRow.Route?
        
        init(state: ItemRow.State) {
            self.name = state.item.name
            self.status = state.item.status
            self.color = state.item.color
            self.route = state.route
        }
    }
    
    public var body: some View {
        WithViewStore(store, observe: \.route) { viewStore in
            NavigationLink(
                unwrapping: viewStore.binding(
                    get: { $0 },
                    send: ItemRow.Action.doNothing
                ),
                case: /ItemRow.Route.edit
            ) { isActive in
                viewStore.send(.setEditNavigation(isActive: isActive))
            } destination: { _ in
                IfLetStore(store.scope(state: \.route)) { routedStore in
                    SwitchStore(routedStore) {
                        ComposableArchitecture.CaseLet<
                            ItemRow.Route,
                            ItemRow.Action,
                            Item.State,
                            Item.Action,
                            _
                        >(
                            state: /ItemRow.Route.edit,
                            action: ItemRow.Action.editItem
                        ) { itemStore in
                            ItemView(store: itemStore)
                        }
                    }
                }
            } label: {
                WithViewStore(store, observe: ViewState.init) { viewStore in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(viewStore.name)
                            
                            switch viewStore.status {
                            case let .inStock(quantity):
                                Text("In stock: \(quantity)")
                            case let .outOfStock(isOnBackOrder):
                                Text("Out of stock\(isOnBackOrder ? ": on back order" : "")")
                            }
                        }
                        
                        Spacer()
                        
                        if let color = viewStore.color {
                            Rectangle()
                                .frame(width: 30, height: 30)
                                .foregroundColor(color.swiftUIColor)
                                .border(Color.black, width: 1)
                        }
                        
                        Button(action: { viewStore.send(.duplicateButtonTapped) }) {
                            Image(systemName: "square.fill.on.square.fill")
                        }
                        .padding(.leading)
                        
                        Button(action: { viewStore.send(.deleteButtonTapped) }) {
                            Image(systemName: "trash.fill")
                        }
                        .padding(.leading)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewStore.status.isInStock ? nil : Color.gray)
                    .alert(
                        title: { Text(viewStore.name) },
                        unwrapping: viewStore.binding(
                            get: \.route,
                            send: ItemRow.Action.setRoute
                        ),
                        case: /ItemRow.Route.deleteAlert,
                        actions: { _ in
                            Button("Delete", role: .destructive) {
                                viewStore.send(.deleteConfirmationButtonTapped)
                            }
                        },
                        message: { Text("Are you sure you want to delete this item?") }
                    )
                    .popover(
                        unwrapping: viewStore.binding(
                            get: \.route,
                            send: ItemRow.Action.setRoute
                        ),
                        case: /ItemRow.Route.duplicate
                    ) { _ in
                        NavigationView {
                            IfLetStore(store.scope(state: \.route)) { routedStore in
                                SwitchStore(routedStore) {
                                    ComposableArchitecture.CaseLet<
                                        ItemRow.Route,
                                        ItemRow.Action,
                                        Item.State,
                                        Item.Action,
                                        _
                                    >(
                                        state: /ItemRow.Route.duplicate,
                                        action: ItemRow.Action.duplicateItem
                                    ) { duplicateItemStore in
                                        ItemView(store: duplicateItemStore)
                                            .navigationBarTitle("Duplicate")
                                            .toolbar {
                                                ToolbarItem(placement: .cancellationAction) {
                                                    Button("Cancel") {
                                                        viewStore.send(.cancelDuplicateButtonTapped)
                                                    }
                                                }
                                                ToolbarItem(placement: .primaryAction) {
                                                    Button("Add") {
                                                        viewStore.send(.addDuplicateButtonTapped)
                                                    }
                                                }
                                            }
                                    }
                                }
                            }
                        }.frame(minWidth: 300, minHeight: 500)
                    }
                }
            }
        }
    }
}

struct ItemRowView_Previews: PreviewProvider {
    static var previews: some View {
        ItemRowView(store: .init(
            initialState: .init(
                item: .init(
                    id: UUID(),
                    name: "keyboard",
                    color: .red,
                    status: .inStock(quantity: 4)
                ),
                route: nil
            ),
            reducer: ItemRow()
        ))
    }
}
