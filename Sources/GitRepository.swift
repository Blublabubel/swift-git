import Foundation
import CommonCrypto
import zlib

// MARK: - Git Repository Structure

struct GitRepository {
    let path: String
    let gitDir: String
    
    init(path: String) {
        self.path = path
        self.gitDir = "\(path)/.swiftgit"
    }
    
    func initialize() throws {
        // Create .git directory structure
        let directories = [
            gitDir,
            "\(gitDir)/objects",
            "\(gitDir)/refs",
            "\(gitDir)/refs/heads",
            "\(gitDir)/refs/tags"
        ]
        
        for dir in directories {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        }
        
        // Create HEAD file pointing to main branch
        let headContent = "ref: refs/heads/main\n"
        try headContent.write(toFile: "\(gitDir)/HEAD", atomically: true, encoding: .utf8)
        
        // Create config file
        let configContent = """
        [core]
        \trepositoryformatversion = 0
        \tfilemode = true
        \tbare = false
        \tlogallrefupdates = true
        [user]
        \tname = SwiftGit User
        \temail = user@example.com
        """
        try configContent.write(toFile: "\(gitDir)/config", atomically: true, encoding: .utf8)
        
        print("Initialized empty Git repository in \(gitDir)")
    }
    
    func add(files: [String]) throws {
        let index = GitIndex(repository: self)
        
        for file in files {
            if FileManager.default.fileExists(atPath: file) {
                try index.addFile(file)
                print("Added '\(file)' to staging area")
            } else {
                print("warning: '\(file)' does not exist")
            }
        }
        
        try index.write()
    }
    
    func commit(message: String) throws {
        let index = GitIndex(repository: self)
        try index.read()
        
        guard !index.entries.isEmpty else {
            throw GitError.noChangesToCommit
        }
        
        // Create tree object from staged files
        let treeHash = try createTreeObject(from: index.entries)
        
        // Create commit object
        let commitHash = try createCommitObject(
            treeHash: treeHash,
            message: message,
            parentHash: getCurrentCommitHash()
        )
        
        // Update HEAD to point to new commit
        try updateHEAD(to: commitHash)
        
        print("Created commit \(commitHash.prefix(7))")
        print("  \(message)")
    }
    
    func createBlob(data: Data, hash: String) throws {
        let objectPath = "\(gitDir)/objects/\(hash.prefix(2))/\(hash.dropFirst(2))"
        let objectDir = "\(gitDir)/objects/\(hash.prefix(2))"
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(atPath: objectDir, withIntermediateDirectories: true)
        
        // Prepare blob content
        let blobContent = "blob \(data.count)\0"
        var fullContent = Data()
        fullContent.append(contentsOf: blobContent.utf8)
        fullContent.append(data)
        
        // Compress and store
        let compressed = try compressData(fullContent)
        try compressed.write(to: URL(fileURLWithPath: objectPath))
    }
    
    private func createTreeObject(from entries: [GitIndexEntry]) throws -> String {
        // Group entries by directory
        var treeEntries: [String: [GitIndexEntry]] = [:]
        
        for entry in entries {
            let components = entry.path.split(separator: "/")
            if components.count == 1 {
                // File in root directory
                treeEntries[""] = (treeEntries[""] ?? []) + [entry]
            } else {
                // File in subdirectory
                let dir = String(components[0])
                treeEntries[dir] = (treeEntries[dir] ?? []) + [entry]
            }
        }
        
        // Create tree content
        var treeContent = Data()
        
        for (dir, dirEntries) in treeEntries {
            for entry in dirEntries {
                let mode = "100644" // Regular file mode
                let name = dir.isEmpty ? entry.path : String(entry.path.split(separator: "/").last!)
                let hash = entry.sha1
                
                // Format: mode name\0hash
                let line = "\(mode) \(name)\0"
                treeContent.append(contentsOf: line.utf8)
                treeContent.append(contentsOf: hash.utf8)
            }
        }
        
        // Compress and store tree object
        let compressed = try compressData(treeContent)
        let hash = calculateSHA1(treeContent)
        let objectPath = "\(gitDir)/objects/\(hash.prefix(2))/\(hash.dropFirst(2))"
        
        try FileManager.default.createDirectory(atPath: "\(gitDir)/objects/\(hash.prefix(2))", withIntermediateDirectories: true)
        try compressed.write(to: URL(fileURLWithPath: objectPath))
        
        return hash
    }
    
    private func createCommitObject(treeHash: String, message: String, parentHash: String?) throws -> String {
        var commitContent = ""
        
        // Add tree
        commitContent += "tree \(treeHash)\n"
        
        // Add parent if exists
        if let parent = parentHash {
            commitContent += "parent \(parent)\n"
        }
        
        // Add author and committer
        let timestamp = Int(Date().timeIntervalSince1970)
        commitContent += "author SwiftGit User <user@example.com> \(timestamp) +0000\n"
        commitContent += "committer SwiftGit User <user@example.com> \(timestamp) +0000\n"
        commitContent += "\n"
        commitContent += message
        commitContent += "\n"
        
        // Compress and store commit object
        let compressed = try compressData(commitContent.data(using: .utf8)!)
        let hash = calculateSHA1(commitContent.data(using: .utf8)!)
        let objectPath = "\(gitDir)/objects/\(hash.prefix(2))/\(hash.dropFirst(2))"
        
        try FileManager.default.createDirectory(atPath: "\(gitDir)/objects/\(hash.prefix(2))", withIntermediateDirectories: true)
        try compressed.write(to: URL(fileURLWithPath: objectPath))
        
        return hash
    }
    
    private func getCurrentCommitHash() -> String? {
        do {
            let headContent = try String(contentsOfFile: "\(gitDir)/HEAD", encoding: .utf8)
            let refPath = headContent.trimmingCharacters(in: .whitespacesAndNewlines)
            if refPath.hasPrefix("ref: ") {
                let actualRef = String(refPath.dropFirst(5))
                let refFile = "\(gitDir)/\(actualRef)"
                if FileManager.default.fileExists(atPath: refFile) {
                    return try String(contentsOfFile: refFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            // No HEAD or ref file exists yet
        }
        return nil
    }
    
    private func updateHEAD(to commitHash: String) throws {
        let headContent = "ref: refs/heads/main\n"
        try headContent.write(toFile: "\(gitDir)/HEAD", atomically: true, encoding: .utf8)
        try commitHash.write(toFile: "\(gitDir)/refs/heads/main", atomically: true, encoding: .utf8)
    }
}


// MARK: - Git Index

struct GitIndexEntry {
    let path: String
    let sha1: String
    let size: Int
    let mtime: Date
    let mode: UInt32
    let stage: UInt32
}

class GitIndex {
    let repository: GitRepository
    var entries: [GitIndexEntry] = []
    
    init(repository: GitRepository) {
        self.repository = repository
    }
    
    func addFile(_ path: String) throws {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
        let sha1 = calculateSHA1(fileData)
        
        // Store the blob object
        try repository.createBlob(data: fileData, hash: sha1)
        
        let attributes = try FileManager.default.attributesOfItem(atPath: path)
        let mtime = attributes[.modificationDate] as? Date ?? Date()
        
        // Determine file mode (100644 for regular files, 100755 for executables)
        let mode: UInt32 = 100644 // Default to regular file
        
        let entry = GitIndexEntry(
            path: path,
            sha1: sha1,
            size: fileData.count,
            mtime: mtime,
            mode: mode,
            stage: 0 // Normal stage
        )
        
        // Remove existing entry if exists
        entries.removeAll { $0.path == path }
        entries.append(entry)
    }
    
    func removeFile(_ path: String) {
        entries.removeAll { $0.path == path }
    }
    
    func read() throws {
        let indexPath = "\(repository.gitDir)/index"
        guard FileManager.default.fileExists(atPath: indexPath) else {
            entries = []
            return
        }
        
        let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
        try parseIndex(data: data)
    }
    
    func write() throws {
        let indexPath = "\(repository.gitDir)/index"
        let data = try serializeIndex()
        try data.write(to: URL(fileURLWithPath: indexPath))
    }
    
    private func parseIndex(data: Data) throws {
        entries = []
        
        guard data.count >= 12 else {
            throw GitError.invalidIndexFormat
        }
        
        var offset = 0
        
        // Read header
        let magic = data[offset..<offset+4]
        guard String(data: magic, encoding: .ascii) == "DIRC" else {
            throw GitError.invalidIndexFormat
        }
        offset += 4
        
        let version = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        
        let entryCount = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self).bigEndian }
        offset += 4
        
        // Read entries
        for _ in 0..<entryCount {
            guard offset + 62 <= data.count else {
                throw GitError.invalidIndexFormat
            }
            
            let entry = try parseIndexEntry(data: data, offset: &offset)
            entries.append(entry)
        }
    }
    
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
        let sha1Data = data[offset..<offset+20]
        let sha1 = sha1Data.map { String(format: "%02hhx", $0) }.joined()
        offset += 20
        
        // Read flags
        let flags = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        offset += 2
        
        // Read path length
        let pathLength = data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt16.self).bigEndian }
        offset += 2
        
        // Read path
        let pathData = data[offset..<offset+Int(pathLength)]
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

extension Data {
    init?(hexString: String) {
        guard hexString.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hexString.startIndex
        
        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = hexString[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            
            index = nextIndex
        }
        
        self = data
    }
}

// MARK: - Errors

enum GitError: Error, LocalizedError {
    case noChangesToCommit
    case notAGitRepository
    case invalidIndexFormat
    
    var errorDescription: String? {
        switch self {
        case .noChangesToCommit:
            return "No changes to commit"
        case .notAGitRepository:
            return "Not a git repository"
        case .invalidIndexFormat:
            return "Invalid index file format"
        }
    }
}

// MARK: - Utilities

func calculateSHA1(_ data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { buffer in
        _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &digest)
    }
    return digest.map { String(format: "%02hhx", $0) }.joined()
}

func compressData(_ data: Data) throws -> Data {
    // Simple compression using zlib
    let compressed = data.withUnsafeBytes { buffer in
        let source = buffer.bindMemory(to: UInt8.self)
        let destination = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count * 2)
        defer { destination.deallocate() }
        
        var stream = z_stream()
        stream.zalloc = nil
        stream.zfree = nil
        stream.opaque = nil
        stream.avail_in = uInt(data.count)
        stream.next_in = UnsafeMutablePointer(mutating: source.baseAddress)
        stream.avail_out = uInt(data.count * 2)
        stream.next_out = destination
        
        let result = deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard result == Z_OK else {
            return Data()
        }
        
        deflate(&stream, Z_FINISH)
        deflateEnd(&stream)
        
        return Data(bytes: destination, count: data.count * 2 - Int(stream.avail_out))
    }
    
    return compressed
}
