//
//  InventoryFeature.swift
//  
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import ComposableArchitecture
import Item
import ItemRow
import Foundation

public struct InventoryFeature: ReducerProtocol {
    public struct State: Equatable {
        public var items: IdentifiedArrayOf<ItemRow.State>
        public var route: Route?
        
        public init(
            items: IdentifiedArrayOf<ItemRow.State>,
            route: Route?
        ) {
            self.items = items
            self.route = route
        }
    }
    
    public enum Route: Equatable {
        case add(Item.State)
        case row(id: ItemRow.State.ID, route: ItemRow.Route)
    }
    
    public enum Action {
        case itemRow(ItemRow.State.ID, ItemRow.Action)
        case addItem(Item.Action)
        case setRoute(Route?)
        case addButtonTapped
        case cancelButtonTapped
        case saveButtonTapped
    }
    
    public init() { }
    
    public var body: some ReducerProtocolOf<InventoryFeature> {
        _InventoryFeature()
            .ifLet(\.route, action: /.self) {
                EmptyReducer()
                    .ifCaseLet(/Route.add, action: /Action.addItem) {
                        Item()
                    }
            }
            .forEach(\.items, action: /Action.itemRow) {
                ItemRow()
            }
    }
}

struct _InventoryFeature: ReducerProtocol {
    typealias State = InventoryFeature.State
    typealias Action = InventoryFeature.Action
    
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .itemRow(let id, .deleteConfirmationButtonTapped):
            state.items.remove(id: id)
            return .none
            
        case .itemRow(let id, .addDuplicateButtonTapped):
            guard case let .duplicate(item) = state.items[id: id]?.route else {
                return .none
            }
            state.items.append(.init(item: item.duplicate(id: UUID()), route: nil))
            state.items[id: id]?.route = nil
            return .none
            
        case .itemRow:
            return .none
            
        case .addItem:
            return .none
            
        case .setRoute(let newRoute):
            state.route = newRoute
            return .none
            
        case .addButtonTapped:
            state.route = .add(.init(id: UUID(), name: "", color: nil, status: .inStock(quantity: 1)))
            return .none
            
        case .cancelButtonTapped:
            state.route = nil
            return .none
            
        case .saveButtonTapped:
            guard case let .add(item) = state.route else {
                return .none
            }
            state.items.append(.init(item: item, route: nil))
            state.route = nil
            return .none
        }
    }
}
