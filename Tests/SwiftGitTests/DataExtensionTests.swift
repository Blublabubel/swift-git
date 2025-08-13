//
// Created by Banghua Zhao on 12/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import XCTest
@testable import SwiftGit

final class DataExtensionTests: XCTestCase {
    
    // MARK: - Hex String Conversion Tests
    
    func testHexStringToDataConversion() throws {
        // Test valid hex strings
        let testCases = [
            ("", Data()),
            ("00", Data([0x00])),
            ("ff", Data([0xff])),
            ("0102", Data([0x01, 0x02])),
            ("deadbeef", Data([0xde, 0xad, 0xbe, 0xef])),
            ("a1b2c3d4e5f6", Data([0xa1, 0xb2, 0xc3, 0xd4, 0xe5, 0xf6])),
            ("000102030405060708090a0b0c0d0e0f", Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert hex string: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for hex string: \(hexString)")
        }
    }
    
    func testHexStringToDataWithUppercase() throws {
        // Test uppercase hex strings
        let testCases = [
            ("FF", Data([0xff])),
            ("DEADBEEF", Data([0xde, 0xad, 0xbe, 0xef])),
            ("A1B2C3D4", Data([0xa1, 0xb2, 0xc3, 0xd4]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert uppercase hex string: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for uppercase hex string: \(hexString)")
        }
    }
    
    func testHexStringToDataWithMixedCase() throws {
        // Test mixed case hex strings
        let testCases = [
            ("DeAdBeEf", Data([0xde, 0xad, 0xbe, 0xef])),
            ("a1B2c3D4", Data([0xa1, 0xb2, 0xc3, 0xd4])),
            ("00FFaaBB", Data([0x00, 0xff, 0xaa, 0xbb]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert mixed case hex string: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for mixed case hex string: \(hexString)")
        }
    }
    
    func testInvalidHexStrings() throws {
        // Test invalid hex strings
        let invalidHexStrings = [
            "0",      // Odd length
            "123",    // Odd length
            "0g",     // Invalid character
            "12 34",  // Contains space
            "12-34",  // Contains dash
            "12_34",  // Contains underscore
            "12.34",  // Contains dot
            "12\n34", // Contains newline
            "12\t34", // Contains tab
            "12\r34", // Contains carriage return
            "12\034", // Contains control character
            "12\u{7f}34" // Contains DEL character
        ]
        
        for hexString in invalidHexStrings {
            let result = Data(hexString: hexString)
            XCTAssertNil(result, "Should fail for invalid hex string: '\(hexString)'")
        }
    }
    
    func testSHA1HexStringConversion() throws {
        // Test SHA1 hash conversion (40 characters)
        let sha1Hex = "74fe44604b5f01220080db08c13843a2f2ba4c76"
        let expectedBytes: [UInt8] = [
            0x74, 0xfe, 0x44, 0x60, 0x4b, 0x5f, 0x01, 0x22, 0x00, 0x80,
            0xdb, 0x08, 0xc1, 0x38, 0x43, 0xa2, 0xf2, 0xba, 0x4c, 0x76
        ]
        
        let result = Data(hexString: sha1Hex)
        XCTAssertNotNil(result, "Failed to convert SHA1 hex string")
        XCTAssertEqual(result?.count, 20, "SHA1 should be 20 bytes")
        XCTAssertEqual(result, Data(expectedBytes), "SHA1 conversion mismatch")
    }
    
    func testEmptyHexString() throws {
        let result = Data(hexString: "")
        XCTAssertNotNil(result, "Empty hex string should return empty Data")
        XCTAssertEqual(result, Data(), "Empty hex string should return empty Data")
    }
    
    func testSingleByteHexString() throws {
        let testCases = [
            ("00", Data([0x00])),
            ("01", Data([0x01])),
            ("ff", Data([0xff])),
            ("FF", Data([0xff])),
            ("a5", Data([0xa5])),
            ("5a", Data([0x5a]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert single byte hex string: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for single byte hex string: \(hexString)")
        }
    }
    
    func testLargeHexString() throws {
        // Test with a large hex string (1KB of data)
        var largeHexString = ""
        var expectedBytes: [UInt8] = []
        
        for i in 0..<1024 {
            let byte = UInt8(i % 256)
            largeHexString += String(format: "%02x", byte)
            expectedBytes.append(byte)
        }
        
        let result = Data(hexString: largeHexString)
        XCTAssertNotNil(result, "Failed to convert large hex string")
        XCTAssertEqual(result?.count, 1024, "Large hex string should be 1024 bytes")
        XCTAssertEqual(result, Data(expectedBytes), "Large hex string conversion mismatch")
    }
    
    func testPerformanceHexStringConversion() throws {
        // Test performance with medium-sized hex string
        let mediumHexString = String(repeating: "deadbeef", count: 100) // 400 bytes
        
        measure {
            for _ in 0..<100 {
                let result = Data(hexString: mediumHexString)
                XCTAssertNotNil(result)
                XCTAssertEqual(result?.count, 400)
            }
        }
    }
    
    func testHexStringWithLeadingZeros() throws {
        let testCases = [
            ("0000", Data([0x00, 0x00])),
            ("0001", Data([0x00, 0x01])),
            ("000000", Data([0x00, 0x00, 0x00])),
            ("000001", Data([0x00, 0x00, 0x01]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert hex string with leading zeros: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for hex string with leading zeros: \(hexString)")
        }
    }
    
    func testHexStringWithTrailingZeros() throws {
        let testCases = [
            ("0000", Data([0x00, 0x00])),
            ("1000", Data([0x10, 0x00])),
            ("000000", Data([0x00, 0x00, 0x00])),
            ("100000", Data([0x10, 0x00, 0x00]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert hex string with trailing zeros: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for hex string with trailing zeros: \(hexString)")
        }
    }
    
    func testHexStringWithAllZeros() throws {
        let testCases = [
            ("00", Data([0x00])),
            ("0000", Data([0x00, 0x00])),
            ("000000", Data([0x00, 0x00, 0x00])),
            ("00000000", Data([0x00, 0x00, 0x00, 0x00]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert all-zeros hex string: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for all-zeros hex string: \(hexString)")
        }
    }
    
    func testHexStringWithAllOnes() throws {
        let testCases = [
            ("ff", Data([0xff])),
            ("ffff", Data([0xff, 0xff])),
            ("ffffff", Data([0xff, 0xff, 0xff])),
            ("ffffffff", Data([0xff, 0xff, 0xff, 0xff]))
        ]
        
        for (hexString, expectedData) in testCases {
            let result = Data(hexString: hexString)
            XCTAssertNotNil(result, "Failed to convert all-ones hex string: \(hexString)")
            XCTAssertEqual(result, expectedData, "Mismatch for all-ones hex string: \(hexString)")
        }
    }
}
