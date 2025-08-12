# Swift Git

A Git implementation written in Swift, demonstrating the core concepts and internals of Git version control.

## Overview

Swift Git is an educational implementation of Git that provides basic version control functionality including repository initialization, file staging, and commit creation. It's designed to help developers understand how Git works under the hood by implementing the core concepts in a clear, readable way.

## Features

- **Repository Initialization**: Create new Git repositories with proper directory structure
- **File Staging**: Add files to the staging area (index)
- **Commit Creation**: Create commits with full metadata and history
- **Object Database**: Store blobs, trees, and commits using SHA1 hashing
- **Binary Index Format**: Implement Git's index file format for staging area

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

# Run the executable
swift run swift-git --help
```

## Usage

Swift Git provides a command-line interface similar to standard Git:

### Initialize a Repository

```bash
# Initialize in current directory
swift-git init

# Initialize in specific directory
swift-git init my-project
```

This creates the following directory structure:
```
my-project/
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
swift-git add main.swift

# Stage multiple files
swift-git add main.swift helper.swift README.md

# Stage all Swift files (shell expansion)
swift-git add *.swift
```

### Create Commits

```bash
# Create commit with message
swift-git commit -m "Add initial implementation"

# Create commit with descriptive message
swift-git commit --message "Fix bug in authentication logic"
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
- File path

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
let repo = GitRepository(path: "/path/to/project")
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
swift-git init

# 3. Create some files
echo "Hello, World!" > main.swift
echo "# My Project" > README.md

# 4. Stage files
swift-git add main.swift README.md

# 5. Create initial commit
swift-git commit -m "Initial commit"

# 6. Make changes
echo "print(\"Hello, Swift!\")" >> main.swift

# 7. Stage and commit changes
swift-git add main.swift
swift-git commit -m "Add Swift code"
```

## Differences from Standard Git

This implementation focuses on educational value and includes several simplifications:

- **Limited Commands**: Only `init`, `add`, and `commit`
- **Single Branch**: Always uses `main` branch
- **Basic Configuration**: Minimal config file
- **No Merging**: No branch or merge support
- **No Remote**: No remote repository support
- **Simple Compression**: Basic zlib implementation

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
