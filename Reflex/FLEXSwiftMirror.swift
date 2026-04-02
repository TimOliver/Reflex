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

/// A `FLEXMirrorProtocol`-conforming mirror for Swift class types.
///
/// `SwiftMirror` bridges Echo's Swift runtime metadata into the FLEX inspection model.
/// It is exposed to Objective-C as `FLEXSwiftMirror` and can therefore be constructed
/// from any Objective-C context that has a `FLEXMirrorProtocol` reference.
///
/// For pure Swift class instances and class metatypes, `SwiftMirror` uses Echo to
/// enumerate ivars (including inherited Swift fields) and Swift protocol conformances.
/// Properties, methods, and class-level members are delegated to an underlying `FLEXMirror`.
/// For non-Swift types (ObjC classes, plain value types), the mirror is returned empty
/// rather than crashing.
@objc(FLEXSwiftMirror)
public class SwiftMirror: NSObject, FLEXMirrorProtocol {

    /// The object or class metatype passed to ``init(reflecting:)``.
    ///
    /// For instance mirrors this is the object itself; for class mirrors it is the
    /// class metatype (e.g. `Employee.self`).
    public let value: Any

    /// `true` when `value` is a class metatype rather than a class instance.
    public let isClass: Bool

    /// The Objective-C class name of the reflected type, as returned by `NSStringFromClass`.
    public let className: String

    /// Never a metaclass; always the non-meta class of the reflected type.
    private let `class`: AnyClass

    /// Echo metadata for the reflected Swift class, or `nil` for non-Swift types.
    private let metadata: ClassMetadata?

    /// A FLEX mirror for the same object, used to populate ObjC-side properties,
    /// methods, and class members.
    private var flexMirror: FLEXMirror {
        .init(reflecting: self.value)
    }

    public private(set) var properties: [FLEXProperty] = []
    public private(set) var classProperties: [FLEXProperty] = []
    public private(set) var ivars: [FLEXIvar] = []
    public private(set) var methods: [FLEXMethod] = []
    public private(set) var classMethods: [FLEXMethod] = []
    public private(set) var protocols: [FLEXProtocol] = []

    /// A mirror for the direct superclass of the reflected type, or `nil` if there is none.
    ///
    /// - If the superclass is itself a Swift class, returns a `SwiftMirror`.
    /// - If the superclass is an Objective-C class, returns a `FLEXMirror`.
    /// - Returns `nil` when the reflected class has no superclass (e.g. `NSObject`).
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

    /// Creates a mirror for the given object or class metatype.
    ///
    /// The initializer handles four distinct cases without crashing:
    ///
    /// 1. **Pure value types / nil ObjC pointers** — `object_getClass` returns `nil`.
    ///    Returns an empty mirror with `isClass == false`.
    /// 2. **Non-Swift types** (ObjC classes, `__SwiftValue` boxes) — `reflectClass` returns
    ///    `nil` or `isSwiftClass == false`. Returns an empty mirror with `isClass == false`.
    /// 3. **Swift class instances** — fully populated via ``examine()``.
    /// 4. **Swift class metatypes** (e.g. `Employee.self`) — same as (3), with `isClass == true`.
    ///
    /// - Parameter objectOrClass: A Swift class instance, a class metatype, or any other value.
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

    /// Populates the mirror's `ivars`, `protocols`, `properties`, and `methods` arrays.
    ///
    /// Swift ivars are sourced from Echo's `shallowFields` and deduplicated against the
    /// ObjC-side ivar list from `FLEXMirror`. Swift protocol conformances are sourced from
    /// Echo and merged with any ObjC protocols reported by `FLEXMirror`. Properties,
    /// methods, and class-level members are taken entirely from `FLEXMirror`.
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

extension SwiftMirror {
    /// Returns the file-system path of the binary image that contains the given pointer.
    ///
    /// Uses `dladdr` to look up the image containing `pointer`. This is used to populate
    /// `imagePath` on ``SwiftIvar`` and ``SwiftProtocol`` instances.
    ///
    /// - Parameter pointer: A pointer into the binary image to look up (typically a metadata pointer).
    /// - Returns: The absolute path of the containing image, or `nil` if `dladdr` fails.
    static func imagePath(for pointer: UnsafeRawPointer) -> String? {
        var exeInfo = Dl_info()
        if (dladdr(pointer, &exeInfo) != 0) {
            if let fname = exeInfo.dli_fname {
                return String(cString: fname)
            }
        }

        return nil
    }
}
