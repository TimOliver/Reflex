//
//  SampleTypes.swift
//  ReflexTests
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation

struct Counter<T: Numeric> {
    var count: T = 5
}

struct Point: Equatable {
    var x: Int = 0
    var y: Int = 0
}

struct Size: Equatable {
    var width: Int = 0
    var height: Int = 0
}

struct Rect: Equatable {
    static let zero = Rect(origin: .init(), size: .init())
    var origin: Point
    var size: Size
}

class Sprite {
    let boundingBox: Rect = .zero
}

// Three-level nested struct for deep-recursion test
struct Segment {
    var start: Point
    var end: Point
}

struct Path {
    var first: Segment
}

class PathHolder {
    let path = Path(first: Segment(start: Point(), end: Point()))
}

// Enum type encoding tests
enum Direction { case north, south, east, west }

// Protocol inheritance for SwiftProtocol test
protocol Named {
    var name: String { get }
}

protocol FullyNamed: Named {
    var fullName: String { get }
}

class NamedThing: NSObject, FullyNamed {
    var name: String = ""
    var fullName: String = ""
}

// Payload enum for getTag/copyPayload tests
enum Tagged {
    case number(Int)
    case text(String)
    case nothing
}

// Class with an optional class-typed property for nil-class-optional tests
extension BoolHolder {
    // Declared in an extension so we don't break the initializer
}
class HolderWithRef {
    var value: Employee? = nil
}

class Person: Equatable {
    var name: String
    var age: Int
    
    var tuple: (String, Int) {
        return (self.name, self.age)
    }
    
    internal init(name: String, age: Int) {
        self.name = name
        self.age = age
    }
    
    static func == (lhs: Person, rhs: Person) -> Bool {
        return lhs.name == rhs.name && lhs.age == rhs.age
    }
    
    func sayHello() {
        print("Hello!")
    }
}

class Employee: Person {
    private(set) var position: String
    private(set) var salary: Double
    let cubicleSize = Size(width: 5, height: 7)
    
    var job: (position: String, salary: Double) {
        return (self.position, self.salary)
    }
    
    internal init(name: String, age: Int, position: String, salary: Double = 60_000) {
        self.position = position
        self.salary = salary
        super.init(name: name, age: age)
    }
    
    func promote() -> (position: String, salary: Double) {
        self.position += "+"
        self.salary *= 1.05
        
        return self.job
    }
}

class BoolHolder {
    var flag: Bool = false
    var optionalCount: Int? = nil
}

protocol Slidable {
    var value: Double { get set }
}

/// 1 protocol (`Slidable`, `Equatable` does not appear?)
/// 5 ivars (`smooth` is included)
/// 1 property (the `@objc smooth`)
/// 5 methods
///     - `initWithColor:frame:`
///     - `smooth`
///     - `init`
///     - `setRange:`
///     - `setSmooth:`
class RFSlider: RFView, Slidable {
    var value = 0.0
    var minValue = 0.0
    var maxValue = 1.0
    var step = 0.1
    @objc var smooth = false
    
    var title = ""
    var subtitle: String? = nil
    var tag = 0
    
    func zero() {
        value = self.minValue
    }
    
    @objc
    func setRange(_ range: NSRange) {
        self.minValue = Double(range.location)
        self.maxValue = self.minValue + Double(range.length)
        
        if self.value < self.minValue || self.value > self.maxValue {
            self.zero()
        }
    }
    
    static func == (l: RFSlider, r: RFSlider) -> Bool {
        return l.value == r.value
    }
}
