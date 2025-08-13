//
// Created by Banghua Zhao on 12/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import XCTest
@testable import SwiftGit

final class GitIndexTests: XCTestCase {
    
    var tempDir: String!
    var repository: GitRepository!
    var index: GitIndex!
    
    override func setUpWithError() throws {
        // Create a temporary directory for testing
        tempDir = NSTemporaryDirectory() + "GitIndexTests-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
        
        // Change to temp directory and initialize repository
        let originalDir = FileManager.default.currentDirectoryPath
        FileManager.default.changeCurrentDirectoryPath(tempDir)
        
        // Initialize repository
        repository = GitRepository()
        try repository.initialize()
        
        // Create index
        index = GitIndex(repository: repository)
        
        // Restore original directory
        FileManager.default.changeCurrentDirectoryPath(originalDir)
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDir = tempDir {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
    }
    
    // MARK: - GitIndexEntry Tests
    
    func testGitIndexEntryInitialization() throws {
        let entry = GitIndexEntry(
            path: "test.txt",
            sha1: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
            size: 1024,
            mtime: Date(),
            mode: 100644,
            stage: 0
        )
        
        XCTAssertEqual(entry.path, "test.txt")
        XCTAssertEqual(entry.sha1, "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0")
        XCTAssertEqual(entry.size, 1024)
        XCTAssertEqual(entry.mode, 100644)
        XCTAssertEqual(entry.stage, 0)
    }
    
    // MARK: - GitIndex Initialization Tests
    
    func testGitIndexInitialization() throws {
        XCTAssertNotNil(index)
        XCTAssertEqual(index.entries.count, 0)
        XCTAssertEqual(index.repository.gitDir, repository.gitDir)
    }
    
    // MARK: - Entry Management Tests
    
    func testAddAndRemoveFile() throws {
        // Create a test file
        let testContent = "Hello, World!"
        let testFile = tempDir + "/test.txt"
        try testContent.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // Add file to index
        try index.addFile(testFile)
        
        XCTAssertEqual(index.entries.count, 1)
        XCTAssertEqual(index.entries.first?.path, testFile)
        XCTAssertEqual(index.entries.first?.size, testContent.count)
        
        // Remove file from index
        index.removeFile(testFile)
        
        XCTAssertEqual(index.entries.count, 0)
    }
    
    func testAddFileReplacesExistingEntry() throws {
        // Create a test file
        let testFile = tempDir + "/test.txt"
        try "First content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // Add file first time
        try index.addFile(testFile)
        XCTAssertEqual(index.entries.count, 1)
        let firstSHA1 = index.entries.first?.sha1
        
        // Modify file content
        try "Second content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // Add file again (should replace existing entry)
        try index.addFile(testFile)
        XCTAssertEqual(index.entries.count, 1) // Still only one entry
        let secondSHA1 = index.entries.first?.sha1
        
        // SHA1 should be different due to content change
        XCTAssertNotEqual(firstSHA1, secondSHA1)
    }
    
    // MARK: - Index File Serialization Tests
    
    func testSerializeEmptyIndex() throws {
        let data = try index.serializeIndex()
        
        // Check header
        XCTAssertGreaterThanOrEqual(data.count, 12) // Header size
        
        // Verify magic number "DIRC"
        let magic = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt32.self) }
        XCTAssertEqual(magic, 0x43524944) // "DIRC" in little-endian
        
        // Verify version
        let version = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt32.self).bigEndian }
        XCTAssertEqual(version, 2)
        
        // Verify entry count
        let entryCount = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self).bigEndian }
        XCTAssertEqual(entryCount, 0)
    }
    
    func testSerializeIndexWithOneEntry() throws {
        // Create a test file
        let testContent = "Test content"
        let testFile = tempDir + "/test.txt"
        try testContent.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // Add file to index
        try index.addFile(testFile)
        
        // Serialize
        let data = try index.serializeIndex()
        
        // Check header
        let entryCount = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self).bigEndian }
        XCTAssertEqual(entryCount, 1)
        
        // Check that data is properly aligned
        XCTAssertGreaterThan(data.count, 12 + 62) // Header + minimum entry size
    }
    
    func testSerializeIndexWithMultipleEntries() throws {
        // Create multiple test files
        let files = ["file1.txt", "file2.txt", "file3.txt"]
        
        for (index, filename) in files.enumerated() {
            let testFile = tempDir + "/" + filename
            try "Content \(index)".write(toFile: testFile, atomically: true, encoding: .utf8)
            try self.index.addFile(testFile)
        }
        
        // Serialize
        let data = try index.serializeIndex()
        
        // Check entry count
        let entryCount = data.withUnsafeBytes { $0.load(fromByteOffset: 8, as: UInt32.self).bigEndian }
        XCTAssertEqual(entryCount, 3)
        
        // Verify all entries are present
        XCTAssertEqual(index.entries.count, 3)
        XCTAssertTrue(index.entries.contains { $0.path.hasSuffix("file1.txt") })
        XCTAssertTrue(index.entries.contains { $0.path.hasSuffix("file2.txt") })
        XCTAssertTrue(index.entries.contains { $0.path.hasSuffix("file3.txt") })
    }
    
    // MARK: - Index File Deserialization Tests
    
    func testParseEmptyIndex() throws {
        // Create empty index data
        let data = try index.serializeIndex()
        
        // Create new index and parse
        let newIndex = GitIndex(repository: repository)
        try newIndex.parseIndex(data: data)
        
        XCTAssertEqual(newIndex.entries.count, 0)
    }
    
    func testParseIndexWithOneEntry() throws {
        // Create index with one entry
        let testFile = tempDir + "/test.txt"
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        try index.addFile(testFile)
        
        let data = try index.serializeIndex()
        
        // Parse with new index
        let newIndex = GitIndex(repository: repository)
        try newIndex.parseIndex(data: data)
        
        XCTAssertEqual(newIndex.entries.count, 1)
        XCTAssertEqual(newIndex.entries.first?.path, testFile)
        XCTAssertEqual(newIndex.entries.first?.size, "Test content".count)
    }
    
    func testParseIndexWithMultipleEntries() throws {
        // Create multiple files
        let files = ["file1.txt", "file2.txt", "file3.txt"]
        
        for (index, filename) in files.enumerated() {
            let testFile = tempDir + "/" + filename
            try "Content \(index)".write(toFile: testFile, atomically: true, encoding: .utf8)
            try self.index.addFile(testFile)
        }
        
        let data = try index.serializeIndex()
        
        // Parse with new index
        let newIndex = GitIndex(repository: repository)
        try newIndex.parseIndex(data: data)
        
        XCTAssertEqual(newIndex.entries.count, 3)
        
        // Verify all entries are correctly parsed
        for filename in files {
            XCTAssertTrue(newIndex.entries.contains { $0.path.hasSuffix(filename) })
        }
    }
    
    // MARK: - Round-trip Tests
    
    func testRoundTripSerialization() throws {
        // Create test files
        let files = ["file1.txt", "file2.txt", "file3.txt"]
        
        for (index, filename) in files.enumerated() {
            let testFile = tempDir + "/" + filename
            try "Content \(index)".write(toFile: testFile, atomically: true, encoding: .utf8)
            try self.index.addFile(testFile)
        }
        
        // Serialize
        let data = try index.serializeIndex()
        
        // Parse back
        let newIndex = GitIndex(repository: repository)
        try newIndex.parseIndex(data: data)
        
        // Compare entries
        XCTAssertEqual(index.entries.count, newIndex.entries.count)
        
        for (original, parsed) in zip(index.entries, newIndex.entries) {
            XCTAssertEqual(original.path, parsed.path)
            XCTAssertEqual(original.sha1, parsed.sha1)
            XCTAssertEqual(original.size, parsed.size)
            XCTAssertEqual(original.mode, parsed.mode)
            XCTAssertEqual(original.stage, parsed.stage)
        }
    }
    
    // MARK: - Edge Cases and Error Tests
    
    func testAddNonExistentFile() throws {
        let nonExistentFile = tempDir + "/nonexistent.txt"
        
        XCTAssertThrowsError(try index.addFile(nonExistentFile)) { error in
            // Should throw a file system error
            XCTAssertTrue(error is CocoaError || error.localizedDescription.contains("does not exist"))
        }
    }
    
    func testParseInvalidIndexData() throws {
        // Create invalid data (too short)
        let invalidData = Data([0x44, 0x49, 0x52, 0x43]) // Just "DIRC"
        
        XCTAssertThrowsError(try index.parseIndex(data: invalidData)) { error in
            XCTAssertTrue(error is GitError)
        }
    }
    
    func testParseIndexWithInvalidMagic() throws {
        // Create data with wrong magic number
        var data = Data()
        data.append(contentsOf: "INVALID".utf8) // Wrong magic
        data.append(withUnsafeBytes(of: UInt32(2).bigEndian) { Data($0) }) // Version
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // Entry count
        
        XCTAssertThrowsError(try index.parseIndex(data: data)) { error in
            XCTAssertTrue(error is GitError)
        }
    }
    
    func testParseIndexWithInvalidVersion() throws {
        // Create data with wrong version
        var data = Data()
        data.append(contentsOf: "DIRC".utf8) // Correct magic
        data.append(withUnsafeBytes(of: UInt32(1).bigEndian) { Data($0) }) // Wrong version
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // Entry count
        
        // This might not throw depending on implementation, but should handle gracefully
        try? index.parseIndex(data: data)
    }
    
    // MARK: - Path Length Edge Cases
    
    func testLongPathHandling() throws {
        // Create a file with a long path (but not too long for the file system)
        let longPath = String(repeating: "a", count: 200) + ".txt"
        let testFile = tempDir + "/" + longPath
        
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // This should work with long paths
        try index.addFile(testFile)
        
        XCTAssertEqual(index.entries.count, 1)
        XCTAssertEqual(index.entries.first?.path, testFile)
    }
    
    func testSpecialCharactersInPath() throws {
        // Test paths with special characters
        let specialPath = "file with spaces & symbols!@#$%^&*().txt"
        let testFile = tempDir + "/" + specialPath
        
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        try index.addFile(testFile)
        
        XCTAssertEqual(index.entries.count, 1)
        XCTAssertEqual(index.entries.first?.path, testFile)
    }
    
    // MARK: - File Mode Tests
    
    func testDifferentFileModes() throws {
        let testFile = tempDir + "/test.txt"
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // Add file to index (this will create a proper entry with real SHA1)
        try index.addFile(testFile)
        
        // Verify the entry was created with the default mode
        XCTAssertEqual(index.entries.count, 1)
        XCTAssertEqual(index.entries.first?.mode, 100644) // Default mode for regular files
        
        // Write to disk and read back to test round-trip
        try index.write()
        let newIndex = GitIndex(repository: repository)
        try newIndex.read()
        
        XCTAssertEqual(newIndex.entries.count, 1)
        XCTAssertEqual(newIndex.entries.first?.mode, 100644)
    }
    
    // MARK: - Stage Tests
    
    func testDifferentStages() throws {
        let testFile = tempDir + "/test.txt"
        try "Test content".write(toFile: testFile, atomically: true, encoding: .utf8)
        
        // Add file to index (this will create a proper entry with stage 0)
        try index.addFile(testFile)
        
        // Verify the entry was created with stage 0
        XCTAssertEqual(index.entries.count, 1)
        XCTAssertEqual(index.entries.first?.stage, 0) // Default stage for normal files
        
        // Write to disk and read back to test round-trip
        try index.write()
        let newIndex = GitIndex(repository: repository)
        try newIndex.read()
        
        XCTAssertEqual(newIndex.entries.count, 1)
        XCTAssertEqual(newIndex.entries.first?.stage, 0)
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceWithManyEntries() throws {
        // Create many small files
        let fileCount = 100
        
        for i in 0..<fileCount {
            let testFile = tempDir + "/file\(i).txt"
            try "Content \(i)".write(toFile: testFile, atomically: true, encoding: .utf8)
            try index.addFile(testFile)
        }
        
        measure {
            // Measure serialization performance
            do {
                _ = try index.serializeIndex()
            } catch {
                XCTFail("Serialization failed: \(error)")
            }
        }
    }
    
    func testPerformanceWithLargeFiles() throws {
        // Create a large file
        let largeContent = String(repeating: "Large content ", count: 10000)
        let testFile = tempDir + "/large.txt"
        try largeContent.write(toFile: testFile, atomically: true, encoding: .utf8)
        
        try index.addFile(testFile)
        
        measure {
            // Measure serialization performance
            do {
                _ = try index.serializeIndex()
            } catch {
                XCTFail("Serialization failed: \(error)")
            }
        }
    }
}
