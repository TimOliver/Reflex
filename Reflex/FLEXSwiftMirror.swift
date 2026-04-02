//
//  FLEXSwiftMirror.swift
//
//  Copyright (c) Flipboard, Inc. (2014–2016); Tanner Bennett (2021-2026)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or
//  other materials provided with the distribution.
//
//  * Neither the name of Flipboard nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  * You must NOT include this project in an application to be submitted
//  to the App Store™, as this project uses too many private APIs.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
