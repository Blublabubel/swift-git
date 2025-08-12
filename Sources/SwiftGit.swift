// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser

// MARK: - Main Command

/**
 * SwiftGit is a Git implementation written in Swift.
 * 
 * This command-line tool provides basic Git functionality including:
 * - Repository initialization
 * - File staging (add)
 * - Commit creation
 * 
 * The tool uses Swift Argument Parser for command-line argument handling
 * and provides a familiar Git-like interface.
 * 
 * Example usage:
 * ```bash
 * swift-git init                    # Initialize new repository
 * swift-git add file1.txt file2.swift  # Stage files
 * swift-git commit -m "Initial commit"  # Create commit
 * ```
 * 
 * Repository Structure:
 * ```
 * project/
 * ├── .swiftgit/           # Git metadata (equivalent to .git/)
 * │   ├── objects/         # Object database
 * │   ├── refs/           # References (branches, tags)
 * │   ├── HEAD            # Current branch pointer
 * │   ├── index           # Staging area
 * │   └── config          # Repository configuration
 * ├── file1.txt           # Working directory files
 * └── file2.swift
 * ```
 */
@main
struct SwiftGit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-git",
        abstract: "A Git implementation in Swift",
        subcommands: [Init.self, Add.self, Commit.self]
    )
    
    /**
     * Main entry point for the SwiftGit command.
     * 
     * This method is called when no subcommand is specified.
     * It displays basic information about the tool and available commands.
     */
    mutating func run() throws {
        print("SwiftGit - A Git implementation in Swift")
        print("Use 'swift-git --help' for more information")
    }
}

// MARK: - Init Command

/**
 * Initialize a new Git repository.
 * 
 * The `init` command creates a new Git repository by:
 * 1. Creating the `.swiftgit/` directory structure
 * 2. Setting up the object database
 * 3. Creating initial configuration files
 * 4. Setting up HEAD to point to the main branch
 * 
 * This is equivalent to `git init` in standard Git.
 * 
 * Example usage:
 * ```bash
 * swift-git init
 * ```
 * 
 * Directory structure created:
 * ```
 * .swiftgit/
 * ├── objects/          # Object database (blobs, trees, commits)
 * ├── refs/
 * │   ├── heads/        # Branch references
 * │   └── tags/         # Tag references
 * ├── HEAD              # Points to current branch
 * └── config            # Repository configuration
 * ```
 */
struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new Git repository"
    )
    
    /**
     * Execute the init command.
     * 
     * Creates a new GitRepository instance and initializes it,
     * setting up all necessary directories and files.
     * 
     * @throws File system errors if directories cannot be created
     */
    mutating func run() throws {
        let repository = GitRepository()
        try repository.initialize()
    }
}

// MARK: - Add Command

/**
 * Add files to the staging area.
 * 
 * The `add` command stages files for the next commit by:
 * 1. Reading file content and calculating SHA1 hash
 * 2. Creating blob objects in the object database
 * 3. Adding entries to the index (staging area)
 * 
 * This is equivalent to `git add` in standard Git.
 * 
 * Example usage:
 * ```bash
 * swift-git add .                    # Stage all files in repository
 * swift-git add src                 # Stage all files in src folder recursively
 * swift-git add file.txt             # Stage single file
 * swift-git add file1.txt file2.swift  # Stage multiple files
 * ```
 * 
 * Staging process:
 * 1. File content is read and hashed
 * 2. Blob object is created and stored in `.swiftgit/objects/`
 * 3. Index entry is added with file metadata
 * 4. Index file is updated on disk
 * 
 * Note: Files must exist in the working directory to be staged.
 * Non-existent files will generate a warning but won't cause an error.
 * The `.` pattern excludes the `.swiftgit` directory automatically.
 * Folders are automatically detected and all their contents are added recursively.
 */
struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add files to the staging area"
    )
    
    /**
     * Files to add to the staging area.
     * 
     * These are the file paths (relative to repository root) that should
     * be staged for the next commit. Multiple files can be specified.
     * 
     * Example:
     * ```bash
     * swift-git add main.swift helper.swift README.md
     * # Stages three files for commit
     * ```
     */
    @Argument(help: "Files to add")
    var files: [String]
    
    /**
     * Execute the add command.
     * 
     * Creates a GitRepository instance and adds the specified files
     * to the staging area. Files are processed in the order specified.
     * 
     * @throws File system errors if files cannot be read or written
     */
    mutating func run() throws {
        let repository = GitRepository()
        try repository.add(files: files)
    }
}

// MARK: - Commit Command

/**
 * Create a new commit from staged changes.
 * 
 * The `commit` command creates a new commit by:
 * 1. Reading the current index (staging area)
 * 2. Creating a tree object from staged files
 * 3. Creating a commit object with metadata
 * 4. Updating HEAD to point to the new commit
 * 
 * This is equivalent to `git commit` in standard Git.
 * 
 * Example usage:
 * ```bash
 * swift-git commit -m "Add initial implementation"
 * swift-git commit --message "Fix bug in main function"
 * ```
 * 
 * Commit creation process:
 * 1. Index entries are grouped by directory
 * 2. Tree object is created representing the directory structure
 * 3. Commit object is created with:
 *    - Tree hash (snapshot of working directory)
 *    - Parent commit hash (if not initial commit)
 *    - Author and committer information
 *    - Commit message
 * 4. HEAD is updated to point to the new commit
 * 
 * Note: At least one file must be staged before creating a commit.
 * Attempting to commit with no staged changes will result in an error.
 */
struct Commit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "commit",
        abstract: "Create a new commit"
    )
    
    /**
     * Commit message describing the changes.
     * 
     * This message should briefly describe what changes are included
     * in this commit. It becomes part of the commit history.
     * 
     * Example:
     * ```bash
     * swift-git commit -m "Add user authentication feature"
     * # Creates commit with message "Add user authentication feature"
     * ```
     * 
     * Best practices for commit messages:
     * - Use present tense ("Add feature" not "Added feature")
     * - Keep first line under 50 characters
     * - Be descriptive but concise
     * - Explain what and why, not how
     */
    @Option(name: .shortAndLong, help: "Commit message")
    var message: String
    
    /**
     * Execute the commit command.
     * 
     * Creates a GitRepository instance and commits the staged changes
     * with the specified message. The commit hash is displayed upon success.
     * 
     * @throws GitError.noChangesToCommit if no files are staged
     * @throws File system errors if objects cannot be created
     */
    mutating func run() throws {
        let repository = GitRepository()
        try repository.commit(message: message)
    }
}
