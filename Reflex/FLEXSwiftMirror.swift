//
//  FLEXSwiftMirror.swift
//  Reflex
//
//  Created by Tanner Bennett on 4/12/21.
//  Copyright © 2021 Tanner Bennett. All rights reserved.
//

import Foundation
import FLEX
import Echo

@objc(FLEXSwiftMirror)
public class SwiftMirror: NSObject, FLEXMirrorProtocol {
    
    /// Never a metaclass
    private let `class`: AnyClass
    private let metadata: ClassMetadata?
    private var flexMirror: FLEXMirror {
        .init(reflecting: self.value)
    }
    
    /// Really it's AnyObject
    public let value: Any
    public let isClass: Bool
    public let className: String
    
    private(set) public var properties: [FLEXProperty] = []
    private(set) public var classProperties: [FLEXProperty] = []
    private(set) public var ivars: [FLEXIvar] = []
    private(set) public var methods: [FLEXMethod] = []
    private(set) public var classMethods: [FLEXMethod] = []
    private(set) public var protocols: [FLEXProtocol] = []
    
    public var superMirror: FLEXMirrorProtocol? {
        guard let supercls = class_getSuperclass(self.class) else {
            return nil
        }

        if reflectClass(supercls)?.isSwiftClass == true {
            return Self.init(reflecting: supercls)
        } else {
            return FLEXMirror(reflecting: supercls)
        }
    }
    
    required public init(reflecting objectOrClass: Any) {
        self.value = objectOrClass

        guard let cls: AnyClass = object_getClass(objectOrClass) else {
            // No class at all (pure value type with no ObjC bridging)
            self.isClass = false
            self.className = String(describing: Swift.type(of: objectOrClass))
            self.class = NSObject.self
            self.metadata = nil
            super.init()
            return
        }

        // For class objects (e.g. Employee.self), cls is the metaclass; the class itself is objectOrClass.
        // For instances (e.g. Employee()), cls is the class.
        let isMetaClass = class_isMetaClass(cls)
        let actualClass: AnyClass = isMetaClass ? objectOrClass as! AnyClass : cls

        // Guard: only proceed for actual Swift classes.
        // ObjC classes and __SwiftValue boxes (which wrap non-bridgeable value types)
        // have isSwiftClass == false and crash when Echo accesses descriptor.
        guard let meta = reflectClass(actualClass), meta.isSwiftClass else {
            self.isClass = false
            self.className = String(describing: Swift.type(of: objectOrClass))
            self.class = NSObject.self
            self.metadata = nil
            super.init()
            return
        }

        self.isClass = isMetaClass
        self.className = NSStringFromClass(cls)
        self.class = actualClass
        self.metadata = meta
        super.init()
        self.examine()
    }
    
    private func examine() {
        guard let metadata = self.metadata else { return }

        let swiftIvars: [SwiftIvar] = metadata.shallowFields.map {
            .init(field: $0, class: metadata)
        }

        let swiftProtos: [SwiftProtocol] = metadata.conformances
            .map(\.protocol)
            .map { .init(protocol: $0) }

        let fm = self.flexMirror
        let ivarNames = Set(swiftIvars.map(\.name))
        self.ivars = swiftIvars + fm.ivars.filter { !ivarNames.contains($0.name) }
        self.protocols = swiftProtos + fm.protocols

        self.properties = fm.properties
        self.classProperties = fm.classProperties
        self.methods = fm.methods
        self.classMethods = fm.classMethods
    }
}
