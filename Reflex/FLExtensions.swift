//
//  FLExtensions.swift
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

import FLEX

extension FLEXTypeEncoding {
    /// Returns the Objective-C type encoding string for an object of the given class name.
    ///
    /// For example, `encodeObjcObject(typeName: "NSString")` produces `@"NSString"`.
    ///
    /// - Parameter typeName: The Objective-C class name to embed in the encoding.
    /// - Returns: A type encoding string of the form `@"TypeName"`.
    static func encodeObjcObject(typeName: String) -> String {
        return "@\"\(typeName)\""
    }

    /// Returns the Objective-C type encoding string for a struct with the given field encodings.
    ///
    /// When `typeName` is provided the result has the form `{TypeName=fields...}`.
    /// When `typeName` is `nil` the type name is omitted and the result has the form `{fields...}`.
    ///
    /// - Parameters:
    ///   - typeName: An optional name to embed in the struct encoding. Pass `nil` to omit it.
    ///   - fields: An array of type encoding strings for each field, in declaration order.
    /// - Returns: A struct type encoding string.
    static func encodeStruct(typeName: String? = nil, fields: [String]) -> String {
        if let typeName = typeName {
            return "{\(typeName)=\(fields.joined())}"
        }

        return "{\(fields.joined())}"
    }
}
