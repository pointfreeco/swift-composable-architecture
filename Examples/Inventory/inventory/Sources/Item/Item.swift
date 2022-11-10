//
//  Item.swift
//  
//
//  Created by Jaap Wijnen on 09/11/2022.
//

import ComposableArchitecture
import SwiftUI

public struct Item: ReducerProtocol {
    public struct State: Equatable, Identifiable {
        public var id: UUID
        public var name: String
        public var color: Color?
        public var status: Status
        
        public init(
            id: UUID,
            name: String,
            color: Color?,
            status: Status
        ) {
            self.id = id
            self.name = name
            self.color = color
            self.status = status
        }
        
        public func duplicate(id: UUID) -> State {
            .init(id: id, name: self.name, color: self.color, status: self.status)
        }
    }
    
    public enum Status: Equatable {
        case inStock(quantity: Int)
        case outOfStock(isOnBackOrder: Bool)
        
        public var isInStock: Bool {
            guard case .inStock = self else { return false }
            return true
        }
    }
    
    public struct Color: Equatable, Hashable {
        var name: String
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        
        static var defaults: [Self] = [
            .red,
            .green,
            .blue,
            .black,
            .yellow,
            .white
        ]
        
        public static let red = Self(name: "Red", red: 1)
        public static let green = Self(name: "Green", green: 1)
        public static let blue = Self(name: "Blue", blue: 1)
        public static let black = Self(name: "Black")
        public static let yellow = Self(name: "Yellow", red: 1, green: 1)
        public static let white = Self(name: "White", red: 1, green: 1, blue: 1)
        
        public var swiftUIColor: SwiftUI.Color {
            .init(red: self.red, green: self.green, blue: self.blue)
        }
    }
    
    public enum Action {
        case setName(String)
        case setQuantity(Int)
        case setColor(Color?)
        case setIsOnBackOrder(Bool)
        case markAsSoldOutButtonTapped
        case markAsBackInStock
    }
    
    public init() { }
    
    public func reduce(into state: inout State, action: Action) -> Effect<Action, Never> {
        switch action {
        case .setName(let newName):
            state.name = newName
            return .none
            
        case .setQuantity(let newQuantity):
            state.status = .inStock(quantity: newQuantity)
            return .none
            
        case .setColor(let newColor):
            state.color = newColor
            return .none
            
        case .setIsOnBackOrder(let isOnBackOrder):
            state.status = .outOfStock(isOnBackOrder: isOnBackOrder)
            return .none
            
        case .markAsSoldOutButtonTapped:
            state.status = .outOfStock(isOnBackOrder: false)
            return .none
            
        case .markAsBackInStock:
            state.status = .inStock(quantity: 1)
            return .none
        }
    }
}
