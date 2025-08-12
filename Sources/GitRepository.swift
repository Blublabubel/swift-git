import Foundation

// MARK: - Git Repository Structure

/**
 * GitRepository represents a Git repository and provides methods for Git operations.
 * 
 * A Git repository is a directory that contains:
 * - Working directory: The actual files you work with
 * - .swiftgit/ directory: Contains all Git metadata and objects
 * 
 * Repository structure:
 * ```
 * my-project/
 * ├── .swiftgit/           # Git repository data
 * │   ├── objects/         # Object database (blobs, trees, commits)
 * │   ├── refs/           # References (branches, tags)
 * │   ├── HEAD            # Points to current branch
 * │   └── index           # Staging area
 * ├── src/                # Your source code
 * ├── README.md           # Documentation
 * └── main.swift          # Main file
 * ```
 * 
 * Example usage:
 * ```swift
 * let repo = GitRepository()
 * try repo.initialize()  // Create new repository
 * try repo.add(files: ["main.swift"])
 * try repo.commit(message: "Initial commit")
 * ```
 */
struct GitRepository {
    /// Path to the .swiftgit directory (always in current directory)
    let gitDir: String
    
    /**
     * Initialize a new GitRepository instance.
     * 
     * Creates a repository in the current directory.
     * The .swiftgit directory will be created at ./.swiftgit/
     * 
     * Example:
     * ```swift
     * let repo = GitRepository()
     * // Repository will be created in current directory
     * ```
     */
    init() {
        self.gitDir = ".swiftgit"
    }
    
    /**
     * Initialize a new Git repository by creating the necessary directory structure.
     * 
     * This method creates the following structure:
     * ```
     * .swiftgit/
     * ├── objects/          # Object database (blobs, trees, commits)
     * ├── refs/
     * │   ├── heads/        # Branch references
     * │   └── tags/         # Tag references
     * ├── HEAD              # Points to current branch
     * └── config            # Repository configuration
     * ```
     * 
     * Example:
     * ```swift
     * let repo = GitRepository(path: ".")
     * try repo.initialize()
     * // Creates .swiftgit/ directory with all necessary subdirectories
     * ```
     * 
     * @throws File system errors if directories cannot be created
     */
    func initialize() throws {
        // Check if .swiftgit directory already exists
        if FileManager.default.fileExists(atPath: gitDir) {
            throw GitError.gitRepositoryAlreadyExists
        }
        
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
        // HEAD is a symbolic reference that points to the current branch
        // Example HEAD content: "ref: refs/heads/main"
        let headContent = "ref: refs/heads/main\n"
        try headContent.write(toFile: "\(gitDir)/HEAD", atomically: true, encoding: .utf8)
        
        // Create config file with basic repository settings
        // This config file contains repository metadata and user information
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
    
    /**
     * Add files to the staging area (index).
     * 
     * The staging area is a snapshot of the working directory that will be included
     * in the next commit. Files are stored as blob objects in the object database.
     * 
     * Supported patterns:
     * - Individual files: "main.swift", "src/helper.swift"
     * - All files: "." (adds all files in working directory, excluding .swiftgit)
     * - Folders: "src/" or "src" (adds all files in folder recursively)
     * 
     * Git object types:
     * - **Blob**: File content (e.g., source code, text files)
     * - **Tree**: Directory structure (contains references to blobs and other trees)
     * - **Commit**: Snapshot of the repository at a point in time
     * 
     * Example:
     * ```swift
     * let repo = GitRepository(path: ".")
     * try repo.add(files: ["."])  // Add all files
     * try repo.add(files: ["src/"])  // Add all files in src folder
     * try repo.add(files: ["main.swift", "README.md"])  // Add specific files
     * ```
     * 
     * @param files Array of file paths or patterns to add to staging area
     * @throws File system errors if files cannot be read or written
     */
    func add(files: [String]) throws {
        let index = GitIndex(repository: self)
        var allFilesToAdd: [String] = []
        
        for pattern in files {
            if pattern == "." {
                // Add all files in working directory (excluding .swiftgit)
                let allFiles = try getAllFilesInWorkingDirectory()
                allFilesToAdd.append(contentsOf: allFiles)
            } else if isDirectory(pattern) {
                // Add all files in the specified directory recursively
                let folderFiles = try getFilesInDirectory(pattern, recursive: true)
                allFilesToAdd.append(contentsOf: folderFiles)
            } else {
                // Handle individual files
                allFilesToAdd.append(pattern)
            }
        }
        
        // Remove duplicates and sort for consistent output
        let uniqueFiles = Array(Set(allFilesToAdd)).sorted()
        
        for file in uniqueFiles {
            if FileManager.default.fileExists(atPath: file) {
                try index.addFile(file)
                print("Added '\(file)' to staging area")
            } else {
                print("warning: '\(file)' does not exist")
            }
        }
        
        try index.write()
    }
    
    /**
     * Create a new commit from the staged changes.
     * 
     * A commit represents a snapshot of the repository at a specific point in time.
     * Each commit contains:
     * - Tree object (directory structure)
     * - Parent commit(s) (for history)
     * - Author and committer information
     * - Commit message
     * 
     * Commit creation process:
     * 1. Create tree object from staged files
     * 2. Create commit object referencing the tree
     * 3. Update HEAD to point to the new commit
     * 
     * Example:
     * ```swift
     * let repo = GitRepository(path: ".")
     * try repo.add(files: ["main.swift"])
     * try repo.commit(message: "Add initial implementation")
     * // Creates commit with hash like "a1b2c3d..."
     * ```
     * 
     * @param message The commit message describing the changes
     * @throws GitError.noChangesToCommit if no files are staged
     * @throws File system errors if objects cannot be created
     */
    func commit(message: String) throws {
        let index = GitIndex(repository: self)
        try index.read()
        
        guard !index.entries.isEmpty else {
            throw GitError.noChangesToCommit
        }
        
        // Create tree object from staged files
        // Tree objects represent directory structure and contain references to blobs
        let treeHash = try createTreeObject(from: index.entries)
        
        // Create commit object
        // Commit objects contain metadata about the snapshot
        let commitHash = try createCommitObject(
            treeHash: treeHash,
            message: message,
            parentHash: getCurrentCommitHash()
        )
        
        // Update HEAD to point to new commit
        // This moves the current branch pointer to the new commit
        try updateHEAD(to: commitHash)
        
        print("Created commit \(commitHash.prefix(7))")
        print("  \(message)")
    }
    
    /**
     * Create a blob object from file data and store it in the object database.
     * 
     * Blob objects store the actual content of files. Each blob is:
     * - Compressed using zlib
     * - Stored in `.swiftgit/objects/` with a path based on its SHA1 hash
     * - Referenced by other objects (trees, commits) using the hash
     * 
     * Object storage layout:
     * ```
     * .swiftgit/objects/
     * ├── a1/           # First two characters of hash
     * │   └── b2c3d...  # Remaining hash characters
     * └── e5/
     *     └── f6g7h...
     * ```
     * 
     * Example:
     * ```swift
     * let fileData = "Hello, World!".data(using: .utf8)!
     * let hash = calculateSHA1(fileData)  // "a1b2c3d..."
     * try repo.createBlob(data: fileData, hash: hash)
     * // Creates file at .swiftgit/objects/a1/b2c3d...
     * ```
     * 
     * @param data The file content as Data
     * @param hash The SHA1 hash of the data
     * @throws File system errors if object cannot be written
     */
    func createBlob(data: Data, hash: String) throws {
        let objectPath = "\(gitDir)/objects/\(hash.prefix(2))/\(hash.dropFirst(2))"
        let objectDir = "\(gitDir)/objects/\(hash.prefix(2))"
        
        // Create directory if it doesn't exist
        try FileManager.default.createDirectory(atPath: objectDir, withIntermediateDirectories: true)
        
        // Prepare blob content
        // Git object format: "type size\0content"
        // Example: "blob 13\0Hello, World!"
        let blobContent = "blob \(data.count)\0"
        var fullContent = Data()
        fullContent.append(contentsOf: blobContent.utf8)
        fullContent.append(data)
        
        // Compress and store
        let compressed = try compressData(fullContent)
        try compressed.write(to: URL(fileURLWithPath: objectPath))
    }
    
    /**
     * Create a tree object from index entries.
     * 
     * Tree objects represent directory structure and contain:
     * - File mode (permissions)
     * - File name
     * - SHA1 hash of the blob or subtree
     * 
     * Tree format: "mode name\0hash"
     * Example tree content:
     * ```
     * 100644 main.swift\0a1b2c3d...
     * 100644 README.md\0e5f6g7h...
     * 040000 src\0i9j0k1l...
     * ```
     * 
     * @param entries Array of GitIndexEntry objects representing staged files
     * @return SHA1 hash of the created tree object
     * @throws File system errors if tree cannot be created
     */
    private func createTreeObject(from entries: [GitIndexEntry]) throws -> String {
        // Create tree recursively starting from root level
        return try createTreeRecursive(entries: entries, currentLevel: 0)
    }
    
    /**
     * Create a tree object recursively, handling any depth of nested directories.
     * 
     * This method recursively processes files at each directory level:
     * - Files at current level go directly into the tree
     * - Files in subdirectories are grouped and processed recursively
     * 
     * Example for path "src/utils/helpers/helper.swift":
     * - Level 0: Groups by "src"
     * - Level 1: Inside "src", groups by "utils" 
     * - Level 2: Inside "src/utils", groups by "helpers"
     * - Level 3: Inside "src/utils/helpers", adds "helper.swift" as file
     * 
     * @param entries All file entries to process
     * @param currentLevel Current directory depth (0 = root)
     * @return SHA1 hash of the created tree object
     */
    private func createTreeRecursive(entries: [GitIndexEntry], currentLevel: Int) throws -> String {
        var files: [GitIndexEntry] = []
        var subdirs: [String: [GitIndexEntry]] = [:]
        
        // Group entries by current level
        for entry in entries {
            let components = entry.path.split(separator: "/")
            
            if components.count == currentLevel + 1 {
                // File at current level
                files.append(entry)
            } else if components.count > currentLevel + 1 {
                // File in subdirectory at current level
                let subdirName = String(components[currentLevel])
                subdirs[subdirName, default: []].append(entry)
            }
        }
        
        // Create tree content
        var treeContent = Data()
        
        // Add files at current level
        for entry in files {
            let components = entry.path.split(separator: "/")
            let fileName = String(components.last!) // Get just the filename
            
            let mode = "100644" // Regular file mode
            let hash = entry.sha1
            
            // Format: mode name\0hash
            let line = "\(mode) \(fileName)\0"
            treeContent.append(contentsOf: line.utf8)
            treeContent.append(contentsOf: hash.utf8)
        }
        
        // Process subdirectories recursively
        for (subdirName, subdirEntries) in subdirs {
            // Create tree object for this subdirectory
            let subTreeHash = try createTreeRecursive(entries: subdirEntries, currentLevel: currentLevel + 1)
            
            // Add subdirectory to current tree
            let mode = "040000" // Directory mode
            let line = "\(mode) \(subdirName)\0"
            treeContent.append(contentsOf: line.utf8)
            treeContent.append(contentsOf: subTreeHash.utf8)
        }
        
        // Compress and store tree object
        let compressed = try compressData(treeContent)
        let hash = calculateSHA1(treeContent)
        let objectPath = "\(gitDir)/objects/\(hash.prefix(2))/\(hash.dropFirst(2))"
        
        try FileManager.default.createDirectory(atPath: "\(gitDir)/objects/\(hash.prefix(2))", withIntermediateDirectories: true)
        try compressed.write(to: URL(fileURLWithPath: objectPath))
        
        return hash
    }
    
    /**
     * Create a commit object from tree hash and metadata.
     * 
     * Commit objects contain:
     * - Tree hash (snapshot of working directory)
     * - Parent commit hash(es) (for history)
     * - Author and committer information
     * - Commit message
     * 
     * Commit format:
     * ```
     * tree <tree-hash>
     * parent <parent-hash>
     * author <name> <email> <timestamp> <timezone>
     * committer <name> <email> <timestamp> <timezone>
     * 
     * <commit-message>
     * ```
     * 
     * Example commit content:
     * ```
     * tree a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
     * author John Doe <john@example.com> 1640995200 +0000
     * committer John Doe <john@example.com> 1640995200 +0000
     * 
     * Initial commit
     * ```
     * 
     * @param treeHash SHA1 hash of the tree object
     * @param message Commit message
     * @param parentHash SHA1 hash of parent commit (nil for initial commit)
     * @return SHA1 hash of the created commit object
     * @throws File system errors if commit cannot be created
     */
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
    
    /**
     * Get the current commit hash by reading HEAD and resolving the reference.
     * 
     * HEAD can be either:
     * - A symbolic reference: "ref: refs/heads/main"
     * - A direct commit hash: "a1b2c3d..."
     * 
     * Example HEAD resolution:
     * 1. Read HEAD: "ref: refs/heads/main"
     * 2. Read refs/heads/main: "a1b2c3d..."
     * 3. Return "a1b2c3d..."
     * 
     * @return SHA1 hash of current commit, or nil if no commits exist
     */
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
    
    /**
     * Update HEAD to point to the new commit hash.
     * 
     * This method:
     * 1. Updates HEAD to point to the main branch
     * 2. Updates the main branch reference to point to the new commit
     * 
     * Example:
     * ```swift
     * try updateHEAD(to: "a1b2c3d...")
     * // HEAD now points to main branch
     * // refs/heads/main now contains "a1b2c3d..."
     * ```
     * 
     * @param commitHash SHA1 hash of the commit to point to
     * @throws File system errors if references cannot be updated
     */
    private func updateHEAD(to commitHash: String) throws {
        let headContent = "ref: refs/heads/main\n"
        try headContent.write(toFile: "\(gitDir)/HEAD", atomically: true, encoding: .utf8)
        try commitHash.write(toFile: "\(gitDir)/refs/heads/main", atomically: true, encoding: .utf8)
    }
    
    /**
     * Get all files in the working directory, excluding .swiftgit.
     * 
     * @return Array of file paths in working directory
     * @throws File system errors if directory cannot be read
     */
    private func getAllFilesInWorkingDirectory() throws -> [String] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: ".")
        
        var allFiles: [String] = []
        
        for item in contents {                        
            if isDirectory(item) {
                // Recursively get files in subdirectory
                let subFiles = try getFilesInDirectory(item, recursive: true)
                allFiles.append(contentsOf: subFiles)
            } else {
                // Add individual file
                allFiles.append(item)
            }
        }
        
        return allFiles
    }
    
    /**
     * Get all files in a directory, optionally recursively.
     * 
     * @param directoryPath Path to the directory
     * @param recursive Whether to include files in subdirectories
     * @return Array of file paths relative to repository root
     * @throws File system errors if directory cannot be read
     */
    private func getFilesInDirectory(_ directoryPath: String, recursive: Bool) throws -> [String] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(atPath: directoryPath)
        
        var files: [String] = []
        
        for item in contents {
            let itemPath = "\(directoryPath)/\(item)"
            
            // Calculate relative path from repository root
            let relativePath: String
            if directoryPath == "." {
                // If we're at the repository root, just use the item name
                relativePath = item
            } else {
                // For subdirectories, the path is already relative
                relativePath = itemPath
            }
            
            if isDirectory(itemPath) && recursive {
                // Recursively get files in subdirectory
                let subFiles = try getFilesInDirectory(itemPath, recursive: true)
                files.append(contentsOf: subFiles)
            } else if !isDirectory(itemPath) {
                // Add individual file
                files.append(relativePath)
            }
        }
        
        return files
    }
    
    /**
     * Check if a path is a directory.
     * 
     * @param path Path to check
     * @return True if path is a directory, false otherwise
     */
    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }
}
