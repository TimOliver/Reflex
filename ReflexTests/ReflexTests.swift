//
//  ReflexTests.swift
//  ReflexTests
//
//  Created by Tanner Bennett on 4/8/21.
//
//  Shared test infrastructure. No test methods live here.
//

import XCTest
import Echo
@testable import Reflex

/// Base class for test suites that need a pre-built Employee/ClassMetadata fixture.
/// Contains no test methods — XCTest will not generate test cases for this class.
class ReflexTests: XCTestCase {
    var bob = Employee(name: "Bob", age: 55, position: "Programmer")
    lazy var employee = reflectClass(bob)!
    lazy var person = employee.superclassMetadata!
    lazy var employeeFields = employee.descriptor.fields
    lazy var personFields = person.descriptor.fields

    func assertFieldsEqual(
        _ expectedNames: [String],
        _ fields: FieldDescriptor,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let fieldNames = Set(fields.records.map(\.name))
        XCTAssertEqual(fieldNames, Set(expectedNames), file: file, line: line)
    }
}
