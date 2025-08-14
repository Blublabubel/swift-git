# Swift Git

A Git implementation written in Swift, demonstrating the core concepts and internals of Git version control.

## Overview

Swift Git is an educational implementation of Git that provides basic version control functionality including repository initialization, file staging, and commit creation. It's designed to help developers understand how Git works under the hood by implementing the core concepts in a clear, readable way.

## Features

- **Repository Initialization**: Create new Git repositories with proper directory structure
- **File Staging**: Add files to the staging area (index) with pattern support
- **Commit Creation**: Create commits with full metadata and history
- **Object Database**: Store blobs, trees, and commits using SHA1 hashing
- **Binary Index Format**: Implement Git's index file format (v2) for staging area
- **Recursive Tree Creation**: Handle nested directories of any depth
- **Comprehensive Testing**: 34 unit tests with full coverage
- **Performance Optimized**: 8-byte alignment, efficient algorithms

## Installation

### Prerequisites

- Swift 5.5 or later
- macOS (for CommonCrypto and zlib support)

### Building

```bash
# Clone the repository
git clone <repository-url>
cd swift-git

# Build the project
swift build

# Run the executable (Method 1: Using swift run)
swift run SwiftGit --help

# Or run the built executable directly (Method 2)
.build/debug/SwiftGit --help

# Run tests
swift test
```

## Usage

Swift Git provides a command-line interface similar to standard Git. You can run it in two ways:

### Method 1: Using `swift run` (Recommended for development)

```bash
# Show help
swift run SwiftGit --help

# Initialize a repository
swift run SwiftGit init

# Add files
swift run SwiftGit add main.swift
swift run SwiftGit add .

# Create commit
swift run SwiftGit commit -m "Initial commit"
```

### Method 2: Build and use executable

```bash
# Build the project
swift build

# Find the executable
ls .build/debug/SwiftGit

# Run the executable
.build/debug/SwiftGit --help
.build/debug/SwiftGit init
.build/debug/SwiftGit add main.swift
.build/debug/SwiftGit commit -m "Initial commit"
```

### Initialize a Repository

```bash
# Initialize in current directory
swift run SwiftGit init
```

This creates the following directory structure:
```
./
├── .swiftgit/           # Git metadata (equivalent to .git/)
│   ├── objects/         # Object database
│   ├── refs/
│   │   ├── heads/       # Branch references
│   │   └── tags/        # Tag references
│   ├── HEAD             # Current branch pointer
│   └── config           # Repository configuration
├── file1.txt            # Working directory files
└── file2.swift
```

### Stage Files

```bash
# Stage single file
swift run SwiftGit add main.swift

# Stage multiple files
swift run SwiftGit add main.swift helper.swift README.md

# Stage all files in repository (excluding .swiftgit)
swift run SwiftGit add .
```

### Create Commits

```bash
# Create commit with message
swift run SwiftGit commit -m "Add initial implementation"

# Create commit with descriptive message
swift run SwiftGit commit --message "Fix bug in authentication logic"
```

## Git Concepts Explained

### 1. Repository Structure

A Git repository consists of:

- **Working Directory**: Your project files
- **Staging Area (Index)**: Snapshot of files ready for commit
- **Object Database**: Compressed storage of all repository data
- **References**: Pointers to commits (branches, tags)

### 2. Git Objects

Git uses three main object types:

#### Blob Objects
Store file content:
```
Content: "Hello, World!"
SHA1: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
Storage: .swiftgit/objects/a1/b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

#### Tree Objects
Represent directory structure:
```
100644 main.swift\0a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
100644 README.md\0e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
040000 src\0i9j0k1l2m3n4o5p6q7r8s9t0
```

#### Commit Objects
Snapshot of repository state:
```
tree a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
parent e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
author John Doe <john@example.com> 1640995200 +0000
committer John Doe <john@example.com> 1640995200 +0000

Add user authentication feature
```

### 3. Staging Area (Index)

The index is a binary file that tracks staged files:

```
Header (12 bytes):
- Magic: "DIRC"
- Version: 2
- Entry count: N

Entries (variable):
- File metadata (size, time, permissions)
- SHA1 hash
- File path with NUL termination
- 8-byte alignment padding

Footer:
- SHA1 checksum
```

### 4. Object Storage

Objects are stored using content-addressable storage:

1. **Hash Calculation**: SHA1 hash of object content
2. **Path Generation**: First 2 characters as directory, rest as filename
3. **Compression**: zlib deflate compression
4. **Storage**: `.swiftgit/objects/<hash-prefix>/<hash-suffix>`

Example:
```
Content: "Hello, World!"
SHA1: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
Path: .swiftgit/objects/a1/b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

## Implementation Details

### Core Components

#### GitRepository
Main repository class that coordinates all operations:
```swift
let repo = GitRepository()
try repo.initialize()  // Create new repository
try repo.add(files: ["file1.txt"])  // Stage files
try repo.commit(message: "Initial commit")  // Create commit
```

#### GitIndex
Manages the staging area (index file):
```swift
let index = GitIndex(repository: repo)
try index.addFile("main.swift")  // Stage file
try index.read()  // Load from disk
try index.write()  // Save to disk
```

#### GitIndexEntry
Represents a single staged file:
```swift
let entry = GitIndexEntry(
    path: "src/main.swift",
    sha1: "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
    size: 1024,
    mtime: Date(),
    mode: 100644,  // Regular file
    stage: 0       // Normal stage
)
```

### Command-Line Interface

Built using Swift Argument Parser:
```swift
@main
struct SwiftGit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-git",
        abstract: "A Git implementation in Swift",
        subcommands: [Init.self, Add.self, Commit.self]
    )
}
```

## Example Workflow

Here's a complete example of using Swift Git:

```bash
# 1. Create a new project
mkdir my-project
cd my-project

# 2. Initialize repository
swift run SwiftGit init

# 3. Create some files
echo "Hello, World!" > main.swift
echo "# My Project" > README.md
mkdir src
echo "func helper() {}" > src/helper.swift

# 4. Stage files
swift run SwiftGit add main.swift README.md
swift run SwiftGit add src  # Add entire directory

# 5. Create initial commit
swift run SwiftGit commit -m "Initial commit"

# 6. Make changes
echo "print(\"Hello, Swift!\")" >> main.swift

# 7. Stage and commit changes
swift run SwiftGit add .
swift run SwiftGit commit -m "Add Swift code"
```

## Technical Highlights

### Performance Optimizations

- **8-byte Memory Alignment**: CPU-friendly access patterns
- **Efficient SHA1 Calculation**: Native CommonCrypto implementation
- **Compressed Object Storage**: Zlib deflate algorithm
- **Smart File Filtering**: Excludes build artifacts and system files

### Git Index v2 Format

- **Binary Format**: Efficient storage and parsing
- **NUL-terminated Paths**: Proper string handling
- **Flags Encoding**: Path length in 12-bit field (0x0FFF max)
- **Memory Alignment**: 8-byte boundaries for performance
- **Robust Parsing**: Bounds checking and error handling

### Recursive Tree Creation

- **Nested Directory Support**: Handles any depth of subdirectories
- **Efficient Grouping**: Groups files by directory level
- **Proper Tree Structure**: Creates intermediate tree objects
- **Path Component Handling**: Splits paths correctly

## Differences from Standard Git

This implementation focuses on educational value and includes several simplifications:

- **Limited Commands**: Only `init`, `add`, and `commit`
- **Single Branch**: Always uses `main` branch
- **Basic Configuration**: Minimal config file
- **No Merging**: No branch or merge support
- **No Remote**: No remote repository support
- **Simple Compression**: Basic zlib implementation

## Project Structure

```
swift-git/
├── Sources/
│   ├── SwiftGit.swift      # Command-line interface
│   ├── GitRepository.swift # Main repository logic
│   ├── GitIndex.swift      # Staging area management
│   ├── Utilities.swift     # Helper functions
│   └── GitError.swift      # Custom error types
├── Tests/
│   └── SwiftGitTests/
│       ├── GitIndexTests.swift    # Index functionality tests
│       └── DataExtensionTests.swift # Utility function tests
├── Package.swift           # Swift Package Manager config
└── README.md              # This file
```

## Learning Resources

To understand Git internals better, check out:

- [Git Internals - Plumbing and Porcelain](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)
- [Git Objects](https://git-scm.com/book/en/v2/Git-Internals-Git-Objects)
- [Git References](https://git-scm.com/book/en/v2/Git-Internals-Git-References)
- [The Git Index](https://git-scm.com/book/en/v2/Git-Internals-The-Git-Index)

## Contributing

This is an educational project. Feel free to:

- Add new Git commands (checkout, branch, merge)
- Improve error handling and edge cases
- Add tests and documentation
- Optimize performance
- Implement additional Git features

## License

This project is for educational purposes. Feel free to use and modify as needed.

## Acknowledgments

- Inspired by the [Build Your Own X](https://github.com/codecrafters-io/build-your-own-x) project
- Based on Git's internal design and file formats
- Uses Swift Argument Parser for CLI handling
