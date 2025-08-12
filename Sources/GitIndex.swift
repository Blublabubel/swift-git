//
// Created by Banghua Zhao on 12/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/**
 * GitIndexEntry represents a single file entry in the Git index (staging area).
 *
 * The index is a binary file that contains metadata about staged files, including:
 * - File path and name
 * - SHA1 hash of the file content
 * - File size and modification time
 * - File permissions (mode)
 * - Stage information (for merge conflicts)
 *
 * Example:
 * ```swift
 * let entry = GitIndexEntry(
 *     path: "src/main.swift",
 *     sha1: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
 *     size: 1024,
 *     mtime: Date(),
 *     mode: 100644,  // Regular file
 *     stage: 0       // Normal stage
 * )
 * ```
 */
struct GitIndexEntry {
    /// File path relative to repository root
    let path: String

    /// SHA1 hash of the file content (40-character hex string)
    let sha1: String

    /// File size in bytes
    let size: Int

    /// File modification time
    let mtime: Date

    /// File mode (permissions) - 100644 for regular files, 100755 for executables
    let mode: UInt32

    /// Stage number (0 = normal, 1-3 = merge conflict stages)
    let stage: UInt32
}

// MARK: - Git Index

/**
 * GitIndex manages the Git index file, which represents the staging area.
 *
 * The index is a binary file that tracks:
 * - Which files are staged for the next commit
 * - File metadata (size, modification time, permissions)
 * - SHA1 hashes of file contents
 * - Stage information for merge conflicts
 *
 * Index file format:
 * ```
 * Header (12 bytes):
 * - Magic number: "DIRC"
 * - Version: 2
 * - Entry count: number of files
 *
 * Entries (variable):
 * - Each entry contains file metadata and path
 * - Entries are sorted by path
 *
 * Footer:
 * - SHA1 checksum of the entire index
 * ```
 *
 * Example usage:
 * ```swift
 * let repo = GitRepository(path: ".")
 * let index = GitIndex(repository: repo)
 *
 * try index.addFile("main.swift")  // Stage a file
 * try index.removeFile("old.txt")  // Unstage a file
 * try index.write()                // Save changes to disk
 * ```
 */
class GitIndex {
    /// Reference to the Git repository
    let repository: GitRepository

    /// Array of staged file entries
    var entries: [GitIndexEntry] = []

    /**
     * Initialize a new GitIndex instance.
     *
     * @param repository The Git repository this index belongs to
     */
    init(repository: GitRepository) {
        self.repository = repository
    }

    /**
     * Add a file to the staging area.
     *
     * This method:
     * 1. Reads the file content
     * 2. Calculates the SHA1 hash
     * 3. Creates a blob object in the object database
     * 4. Adds an entry to the index
     *
     * Example:
     * ```swift
     * let index = GitIndex(repository: repo)
     * try index.addFile("src/main.swift")
     * // File is now staged and ready for commit
     * ```
     *
     * @param path Path to the file to add (relative to repository root)
     * @throws File system errors if file cannot be read
     */
    func addFile(_ path: String) throws {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
        let sha1 = calculateSHA1(fileData)

        // Store the blob object in the object database
        // This creates a compressed file at .swiftgit/objects/<hash>
        try repository.createBlob(data: fileData, hash: sha1)

        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let mtime = attributes[.modificationDate] as? Date ?? Date()

        // Determine file mode (100644 for regular files, 100755 for executables)
        // Git uses Unix-style file modes
        let mode: UInt32 = 100644 // Default to regular file (rw-r--r--)

        let entry = GitIndexEntry(
            path: path,
            sha1: sha1,
            size: fileData.count,
            mtime: mtime,
            mode: mode,
            stage: 0 // Normal stage (0 = staged, 1-3 = merge conflict stages)
        )

        // Remove existing entry if exists (replace with new version)
        entries.removeAll { $0.path == path }
        entries.append(entry)
    }

    /**
     * Remove a file from the staging area.
     *
     * This removes the file from the index but doesn't delete it from the working directory.
     * The file will no longer be included in the next commit.
     *
     * Example:
     * ```swift
     * let index = GitIndex(repository: repo)
     * index.removeFile("temp.txt")
     * // File is no longer staged
     * ```
     *
     * @param path Path to the file to remove from staging
     */
    func removeFile(_ path: String) {
        entries.removeAll { $0.path == path }
    }

    /**
     * Read the index file from disk.
     *
     * This method parses the binary index file and populates the entries array.
     * If no index file exists, entries will be empty.
     *
     * Example:
     * ```swift
     * let index = GitIndex(repository: repo)
     * try index.read()
     * print("Staged files: \(index.entries.count)")
     * ```
     *
     * @throws GitError.invalidIndexFormat if the index file is corrupted
     * @throws File system errors if the index file cannot be read
     */
    func read() throws {
        let indexPath = "\(repository.gitDir)/index"
        guard FileManager.default.fileExists(atPath: indexPath) else {
            entries = []
            return
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
        try parseIndex(data: data)
    }

    /**
     * Write the index to disk.
     *
     * This method serializes the entries array into the binary index file format
     * and writes it to `.swiftgit/index`.
     *
     * Example:
     * ```swift
     * let index = GitIndex(repository: repo)
     * try index.addFile("new.txt")
     * try index.write()  // Save changes to disk
     * ```
     *
     * @throws File system errors if the index file cannot be written
     */
    func write() throws {
        let indexPath = "\(repository.gitDir)/index"
        let data = try serializeIndex()
        try data.write(to: URL(fileURLWithPath: indexPath))
    }

    /**
     * Parse the binary index file data into entries.
     *
     * Index file format:
     * ```
     * Header (12 bytes):
     * - Magic: "DIRC" (4 bytes)
     * - Version: 2 (4 bytes, big-endian)
     * - Entry count: N (4 bytes, big-endian)
     *
     * Entries (N * variable bytes):
     * - Each entry contains metadata and path
     * - Entries are padded to 8-byte boundaries
     *
     * Footer:
     * - SHA1 checksum (20 bytes)
     * ```
     *
     * @param data Raw binary data from the index file
     * @throws GitError.invalidIndexFormat if the data is not a valid index file
     */
    private func parseIndex(data: Data) throws {
        entries = []

        guard data.count >= 12 else {
            throw GitError.invalidIndexFormat
        }

        var offset = 0

        // Read header
        let magic = data[offset ..< offset + 4]
        guard String(data: magic, encoding: .ascii) == "DIRC" else {
            throw GitError.invalidIndexFormat
        }
        offset += 4

        let version = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4

        let entryCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4

        // Read entries
        for _ in 0 ..< entryCount {
            guard offset + 62 <= data.count else {
                throw GitError.invalidIndexFormat
            }

            let entry = try parseIndexEntry(data: data, offset: &offset)
            entries.append(entry)
        }
    }

    /**
     * Parse a single index entry from binary data.
     *
     * Entry format (62 bytes + variable path):
     * ```
     * ctime (4 bytes)      - Creation time
     * ctime_nano (4 bytes) - Creation time nanoseconds
     * mtime (4 bytes)      - Modification time
     * mtime_nano (4 bytes) - Modification time nanoseconds
     * dev (4 bytes)        - Device ID
     * ino (4 bytes)        - Inode number
     * mode (4 bytes)       - File mode
     * uid (4 bytes)        - User ID
     * gid (4 bytes)        - Group ID
     * file_size (4 bytes)  - File size
     * sha1 (20 bytes)      - SHA1 hash
     * flags (2 bytes)      - File flags
     * path_len (2 bytes)   - Path length
     * path (variable)      - File path
     * padding (variable)   - 8-byte alignment padding
     * ```
     *
     * @param data Raw binary data
     * @param offset Current position in data (will be updated)
     * @return Parsed GitIndexEntry
     * @throws GitError.invalidIndexFormat if entry cannot be parsed
     */
    private func parseIndexEntry(data: Data, offset: inout Int) throws -> GitIndexEntry {
        // Read entry header (62 bytes)
        let ctime = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let ctimeNano = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let mtime = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let mtimeNano = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let dev = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let ino = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let mode = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let uid = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let gid = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        let fileSize = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4

        // Read SHA1 hash (20 bytes)
        let sha1Data = data[offset ..< offset + 20]
        let sha1 = sha1Data.map { String(format: "%02hhx", $0) }.joined()
        offset += 20

        // Read flags
        let flags = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        offset += 2

        // Read path length
        let pathLength = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        offset += 2

        // Read path
        let pathData = data[offset ..< offset + Int(pathLength)]
        guard let path = String(data: pathData, encoding: .utf8) else {
            throw GitError.invalidIndexFormat
        }
        offset += Int(pathLength)

        // Align to 8-byte boundary
        let padding = (8 - (offset % 8)) % 8
        offset += padding

        let stage = (flags >> 12) & 0x3
        let mtimeDate = Date(timeIntervalSince1970: TimeInterval(mtime))

        return GitIndexEntry(
            path: path,
            sha1: sha1,
            size: Int(fileSize),
            mtime: mtimeDate,
            mode: mode,
            stage: UInt32(stage)
        )
    }

    /**
     * Serialize the index entries into binary format.
     *
     * This method converts the entries array back into the binary index file format
     * that can be written to disk.
     *
     * @return Binary data representing the index file
     * @throws File system errors if serialization fails
     */
    private func serializeIndex() throws -> Data {
        var data = Data()

        // Write header
        data.append(contentsOf: "DIRC".utf8) // Magic number
        data.append(withUnsafeBytes(of: UInt32(2).bigEndian) { Data($0) }) // Version
        data.append(withUnsafeBytes(of: UInt32(entries.count).bigEndian) { Data($0) }) // Entry count

        // Write entries
        for entry in entries {
            data.append(try serializeIndexEntry(entry))
        }

        // Calculate and write index checksum
        let indexSha1 = calculateSHA1(data)
        let indexSha1Data = Data(hexString: indexSha1) ?? Data()
        data.append(indexSha1Data)

        return data
    }

    /**
     * Serialize a single index entry into binary format.
     *
     * This method converts a GitIndexEntry back into the binary format used
     * in the index file.
     *
     * @param entry The entry to serialize
     * @return Binary data representing the entry
     */
    private func serializeIndexEntry(_ entry: GitIndexEntry) throws -> Data {
        var data = Data()

        // Write entry header (62 bytes)
        let mtime = UInt32(entry.mtime.timeIntervalSince1970)
        let ctime = mtime // Use same time for creation

        data.append(withUnsafeBytes(of: ctime.bigEndian) { Data($0) }) // ctime
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // ctime nanoseconds
        data.append(withUnsafeBytes(of: mtime.bigEndian) { Data($0) }) // mtime
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // mtime nanoseconds
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // dev
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // ino
        data.append(withUnsafeBytes(of: entry.mode.bigEndian) { Data($0) }) // mode
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // uid
        data.append(withUnsafeBytes(of: UInt32(0).bigEndian) { Data($0) }) // gid
        data.append(withUnsafeBytes(of: UInt32(entry.size).bigEndian) { Data($0) }) // file size

        // Write SHA1 hash
        let sha1Data = Data(hexString: entry.sha1) ?? Data()
        data.append(sha1Data)

        // Write flags
        let flags = UInt16(entry.stage << 12)
        data.append(withUnsafeBytes(of: flags.bigEndian) { Data($0) })

        // Write path length
        let pathData = entry.path.data(using: .utf8) ?? Data()
        data.append(withUnsafeBytes(of: UInt16(pathData.count).bigEndian) { Data($0) })

        // Write path
        data.append(pathData)

        // Add padding to align to 8-byte boundary
        let padding = (8 - (data.count % 8)) % 8
        data.append(contentsOf: Array(repeating: UInt8(0), count: padding))

        return data
    }
}

// MARK: - Data Extensions

/**
 * Extension to convert hex strings to Data objects.
 *
 * This is used to convert SHA1 hash strings (40 hex characters) into
 * binary data for storage in the index file.
 *
 * Example:
 * ```swift
 * let hexString = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
 * let data = Data(hexString: hexString)
 * // data contains 20 bytes representing the SHA1 hash
 * ```
 */
extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }

        var data = Data()
        var index = hexString.startIndex

        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = hexString[index ..< nextIndex]

            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)

            index = nextIndex
        }

        self = data
    }
}
