//
//  AppFeature.swift
//  
//
//  Created by Jaap Wijnen on 10/11/2022.
//

import ComposableArchitecture
import InventoryFeature

public struct AppFeature: ReducerProtocol {
    public struct State: Equatable {
        public var selectedTab: Tab
        public var inventory: InventoryFeature.State
        
        public init(
            selectedTab: Tab,
            inventory: InventoryFeature.State
        ) {
            self.selectedTab = selectedTab
            self.inventory = inventory
        }
    }
    
    public enum Tab: Equatable {
        case inventory
    }
    
    public enum Action {
        case inventory(InventoryFeature.Action)
        case setTab(Tab)
    }
    
    public init() { }
    
    public var body: some ReducerProtocolOf<AppFeature> {
        Scope(state: \.inventory, action: /Action.inventory) {
            InventoryFeature()
        }
        _AppFeature()
    }
}

struct _AppFeature: ReducerProtocol {
    typealias State = AppFeature.State
    typealias Action = AppFeature.Action
    
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .inventory:
            return .none
            
        case .setTab(let newTab):
            state.selectedTab = newTab
            return .none
        }
    }
}
