//
//  File.swift
//  
//
//  Created by Joe Blau on 6/19/20.
//

import CoreMotion

public struct Acceleration: Equatable {
    public let rawValue: CMAcceleration?
    
    public var x: Double
    public var y: Double
    public var z: Double
    
    init(rawValue: CMAcceleration) {
        self.rawValue = rawValue
        self.x = rawValue.x
        self.y = rawValue.y
        self.z = rawValue.z
    }

    init(
      x: Double,
      y: Double,
      z: Double
    ) {
      self.rawValue = nil

      self.x = x
      self.y = y
      self.z = z
    }
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.x == rhs.x
        && lhs.y == rhs.y
        && lhs.z == rhs.z
    }
}

extension CMAcceleration: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.x == rhs.x
        && lhs.y == rhs.y
        && lhs.z == rhs.z
    }
}
