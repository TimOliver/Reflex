//
//  PointerExtensions.swift
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
import Echo

typealias RawPointer = UnsafeMutableRawPointer

extension UnsafeRawPointer {
    subscript<T>(offset: Int) -> T {
        get {
            return self.load(fromByteOffset: offset, as: T.self)
        }
    }
}

extension RawPointer {
    /// Generic subscript. Do not use when T = Any unless you mean it...
    subscript<T>(offset: Int) -> T {
        get {
            return self.load(fromByteOffset: offset, as: T.self)
        }
        
        set {
            self.storeBytes(of: newValue, toByteOffset: offset, as: T.self)
        }
    }

    /// Allocates space for a structure (or enum?) without an initial value
    static func allocateBuffer(for type: Metadata) -> Self {
        return RawPointer.allocate(
            byteCount: type.vwt.size,
            alignment: type.vwt.flags.alignment
        )
    }
    
    /// Allocates space for and stores a value.
    /// You should probably use AnyExistentialContainer instead.
    init(wrapping value: Any, withType metadata: Metadata) {
        self = RawPointer.allocateBuffer(for: metadata)
        self.storeBytes(of: value, type: metadata)
    }
    
    /// For storing a value from an Any container
    func storeBytes(of value: Any, type: Metadata, offset: Int = 0) {
        var box = container(for: value)
        type.vwt.initializeWithCopy((self + offset), box.projectValue()~)
//        (self + offset).copyMemory(from: box.projectValue(), byteCount: type.vwt.size)
    }
    
    /// For copying a tuple element instance from a pointer
    func copyMemory(ofTupleElement valuePtr: UnsafeRawPointer, layout e: TupleMetadata.Element) {
        e.metadata.vwt.initializeWithCopy((self + e.offset), valuePtr~)
//        (self + e.offset).copyMemory(from: valuePtr, byteCount: e.metadata.vwt.size)
    }
    
    /// For copying a type instance from a pointer
    func copyMemory(from pointer: RawPointer, type: Metadata, offset: Int = 0) {
        type.vwt.initializeWithCopy((self + offset), pointer)
//        (self + offset).copyMemory(from: pointer, byteCount: type.vwt.size)
    }
}

extension Unmanaged where Instance == AnyObject {
    /// Quickly retain an object before you write its address to memory or something
    @discardableResult
    static func retainIfObject(_ thing: Any) -> Bool {
        if container(for: thing).metadata.kind.isObject {
            _ = self.passRetained(thing as AnyObject).retain()
            return true
        }
        
        return false
    }
}

postfix operator ~
postfix func ~<T>(target: T) -> RawPointer {
    return unsafeBitCast(target, to: RawPointer.self)
}
prefix func ~<T,U>(target: T) -> U {
    return unsafeBitCast(target, to: U.self)
}
