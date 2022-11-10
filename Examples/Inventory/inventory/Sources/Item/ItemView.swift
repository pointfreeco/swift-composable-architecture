//
//  ItemView.swift
//  
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import SwiftUI
import ComposableArchitecture

public struct ItemView: View {
    let store: StoreOf<Item>
    
    public init(store: StoreOf<Item>) {
        self.store = store
    }
    
    struct ViewState: Equatable {
        let name: String
        let color: Item.Color?
        
        init(state: Item.State) {
            self.name = state.name
            self.color = state.color
        }
    }
    
    public var body: some View {
        WithViewStore(store, observe: ViewState.init) { viewStore in
            Form {
                TextField(
                    "Name",
                    text: viewStore.binding(
                        get: \.name,
                        send: Item.Action.setName
                    )
                )

                Picker(
                    selection: viewStore.binding(
                        get: \.color,
                        send: Item.Action.setColor
                    ),
                    label: Text("Color")
                ) {
                    Text("None")
                        .tag(Item.Color?.none)

                    ForEach(Item.Color.defaults, id: \.name) { color in
                        Text(color.name)
                            .tag(Optional(color))
                    }
                }
                
                SwitchStore(store.scope(state: \.status)) {
                    CaseLet<Item.Status, Item.Action, Int, Item.Action, InStockView>(state: /Item.Status.inStock) { inStockStore in
                        InStockView(store: inStockStore)
                    }
                    CaseLet<Item.Status, Item.Action, Bool, Item.Action, OutOfStockView>(state: /Item.Status.outOfStock) { outOfStockStore in
                        OutOfStockView(store: outOfStockStore)
                    }
                }
            }
        }
    }
}

struct InStockView: View {
    var store: Store<Int, Item.Action>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Section(header: Text("In stock")) {
                Stepper(
                    "Quantity: \(viewStore.state)",
                    value: viewStore.binding(
                        get: { $0 },
                        send: Item.Action.setQuantity
                    )
                )
                Button("Mark as sold out") {
                    //withAnimation {
                    viewStore.send(.markAsSoldOutButtonTapped)
                    //}
                }
            }
            .transition(.opacity)
        }
    }
}

struct OutOfStockView: View {
    var store: Store<Bool, Item.Action>
    
    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            Section(header: Text("Out of stock")) {
                Toggle(
                    "Is on back order?",
                    isOn: viewStore.binding(
                        get: { $0 },
                        send: Item.Action.setIsOnBackOrder
                    )
                )
                Button("Is back in stock!") {
                    //withAnimation {
                    viewStore.send(.markAsBackInStock)
                    //}
                }
            }
            .transition(.opacity)
        }
    }
}

struct ItemView_Previews: PreviewProvider {
    static var previews: some View {
        ItemView(store: .init(
            initialState: .init(
                id: UUID(),
                name: "",
                color: nil,
                status: .inStock(quantity: 1)
            ),
            reducer: Item()
        ))
    }
}

