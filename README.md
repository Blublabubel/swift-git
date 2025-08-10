# 🚀 SwiftGit

> **A Git implementation in Swift for learning Git internals**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)]()

**SwiftGit** is a complete implementation of Git's core functionality written in Swift. This project demonstrates how Git works under the hood by implementing the fundamental concepts: object storage, staging area, commits, and more.

## 🌟 Why This Project?

- **🧠 Learn Git Internals**: Understand how Git actually works, not just how to use it
- **💡 Educational Value**: Perfect for developers who want to dive deep into version control systems
- **🔧 Hands-on Experience**: Build your own Git-like system from scratch
- **📚 Real-world Implementation**: See Git concepts implemented in modern Swift

## ✨ Features

### 🎯 Core Git Operations
- **`init`** - Initialize a new Git repository
- **`add`** - Stage files for commit
- **`commit`** - Create commits with proper object storage

### 🔧 Git Internals Implemented
- **Object Storage**: Blob, tree, and commit objects
- **Index Management**: Binary index file with proper Git format
- **SHA1 Hashing**: Content-addressable storage
- **Zlib Compression**: Efficient object storage
- **Reference Management**: HEAD and branch pointers

### 📁 Repository Structure
```
.swiftgit/
├── objects/          # Git objects (blobs, trees, commits)
│   ├── 8a/b686...   # Content-addressable storage
│   └── ...
├── refs/
│   └── heads/       # Branch references
├── HEAD             # Current branch pointer
├── config           # Repository configuration
└── index            # Staging area (binary format)
```

## 🚀 Quick Start

### Prerequisites
- Swift 5.9+
- macOS (for CommonCrypto and zlib)

### Run SwiftGit
   ```bash
   # Initialize a new repository
   swift run SwiftGit init
   
   # Add files to staging
   echo 'Hello, World!' > file.txt
   swift run SwiftGit add file.txt
   
   # Create a commit
   swift run SwiftGit commit -m "Initial commit"
   ```

### Command Reference

```bash
# Initialize repository
SwiftGit init [directory]

# Add files to staging
SwiftGit add <file1> <file2> ...

# Create commit
SwiftGit commit -m "Commit message"
```

## 🔍 How It Works

### Git Object Model
SwiftGit implements Git's core object model:

1. **Blob Objects**: Store file contents
2. **Tree Objects**: Store directory structure
3. **Commit Objects**: Store commit metadata and references

### Staging Area
The index file maintains the staging area using Git's binary format:
- Tracks staged files and their metadata
- Stores SHA1 hashes of file contents
- Maintains file permissions and timestamps

### Object Storage
Files are stored using Git's content-addressable storage:
- SHA1 hash determines object location
- Objects are compressed using zlib
- Directory structure: `objects/XX/YYYY...`

## 🎓 Learning Resources

This project is perfect for learning:

- **Git Internals**: How Git stores data and manages history
- **Version Control Systems**: Core concepts of VCS design
- **Swift Programming**: Advanced Swift features and system programming
- **Binary File Formats**: Understanding complex file structures
- **Cryptographic Hashing**: SHA1 and content-addressable storage

## 🔧 Technical Details

### Dependencies
- **Swift Argument Parser**: Command-line interface
- **CommonCrypto**: SHA1 hashing
- **zlib**: Object compression

### Architecture
- **Modular Design**: Separate components for different Git operations
- **Error Handling**: Comprehensive error types and messages
- **Binary Compatibility**: Implements actual Git file formats

## 🤝 Contributing

Contributions are welcome! This is a learning project, so feel free to:

- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Add new Git commands
- 🧪 Add tests

### Development Setup
```bash
git clone https://github.com/banghuazhao/swift-git.git
cd swift-git
swift build
```

## 📚 Related Projects

- [Git from the Bottom Up](https://jwiegley.github.io/git-from-the-bottom-up/)
- [Git Internals](https://git-scm.com/book/en/v2/Git-Internals-Plumbing-and-Porcelain)
- [Building Git](https://shop.jcoglan.com/building-git/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⭐ Star This Project

If you found this project helpful for learning Git internals, please consider giving it a star! ⭐

Your support helps:
- 📈 Increase visibility for other learners
- 🎯 Encourage more educational content
- 💪 Motivate further development

---

**Happy Learning! 🚀**

*Built with ❤️ and Swift*
