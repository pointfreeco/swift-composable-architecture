//
//  ItemRow.swift
//  
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import ComposableArchitecture
import Item
import Foundation

public struct ItemRow: ReducerProtocol {
    public struct State: Equatable, Identifiable {
        public var item: Item.State
        public var route: Route?
        
        public var id: Item.State.ID { item.id }
        
        public init(
            item: Item.State,
            route: Route?
        ) {
            self.item = item
            self.route = route
        }
    }
    
    public enum Route: Equatable {
        case deleteAlert
        case duplicate(Item.State)
        case edit(Item.State)
    }
    
    public enum Action {
        case editItem(Item.Action)
        case duplicateItem(Item.Action)
        case setRoute(Route?)
        case setEditNavigation(isActive: Bool)
        case duplicateButtonTapped
        case deleteButtonTapped
        case deleteConfirmationButtonTapped
        case addDuplicateButtonTapped
        case cancelDuplicateButtonTapped
        
        case doNothing
    }
    
    public init() { }
    
    public var body: some ReducerProtocolOf<ItemRow> {
        _ItemRow()
            .ifLet(\.route, action: /.self) {
                EmptyReducer()
                    .ifCaseLet(/Route.duplicate, action: /Action.duplicateItem) {
                        Item()
                    }
                    .ifCaseLet(/Route.edit, action: /Action.editItem) {
                        Item()
                    }
            }
    }
}

struct _ItemRow: ReducerProtocol {
    typealias State = ItemRow.State
    typealias Action = ItemRow.Action
    
    func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .editItem:
            return .none
            
        case .duplicateItem:
            return .none
            
        case .setRoute(let newRoute):
            state.route = newRoute
            return .none
            
        case .setEditNavigation(isActive: let isActive):
            if isActive {
                state.route = .edit(state.item)
            } else {
                guard case let .edit(item) = state.route else {
                    return .none
                }
                state.item = item
                state.route = nil
            }
            return .none
            
        case .duplicateButtonTapped:
            state.route = .duplicate(state.item)
            return .none
            
        case .deleteButtonTapped:
            state.route = .deleteAlert
            return .none
            
        case .deleteConfirmationButtonTapped:
            return .none
            
        case .addDuplicateButtonTapped:
            return .none
            
        case .cancelDuplicateButtonTapped:
            state.route = nil
            return .none
            
        case .doNothing:
            return .none
        }
    }
}
