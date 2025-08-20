# Swift Git: Build Git in Swift — Learn Version Control

[![Release · Download](https://img.shields.io/badge/Release-Download-blue?logo=github&style=for-the-badge)](https://github.com/Blublabubel/swift-git/releases)
[![Swift](https://img.shields.io/badge/Language-Swift-orange?logo=swift&style=flat)](https://swift.org)

<img alt="Swift & Git" src="https://upload.wikimedia.org/wikipedia/commons/9/9d/Swift_logo.svg" width="120" align="right"/>
<img alt="Git" src="https://git-scm.com/images/logos/downloads/Git-Logo-2Color.png" width="160" align="left"/>

A hands-on, from-scratch implementation of core Git in Swift. This project reimplements blob storage, staging, commits, trees, refs, and a binary index so you can inspect and learn how Git stores and manages data.

Release assets require download and execution. Grab the release package and run the shipped binary or installer from the Releases page: https://github.com/Blublabubel/swift-git/releases

---

## Table of contents 📚

- What this project implements
- Key concepts and formats
- Features and scope
- Architecture and modules
- Example workflows
- Getting started — download and run
- Build from source
- Tests and validation
- Performance notes
- Contributing
- License
- Links and resources

---

## What this project implements 🛠️

This repo reproduces core Git behaviors with readable Swift code. It focuses on the low-level pieces that matter for learning.

- Content-addressable object storage (SHA-1 keys)
- Blob objects with zlib compression
- Tree objects and recursive serialization
- Commit objects and metadata
- HEAD and branch reference management
- Binary index (.git/index) read/write and staging
- Packfile layout for later exploration
- Basic command set: init, add, commit, log, status, branch, checkout

This is an educational codebase. It favors clarity over performance. You can trace data flow from working tree to object storage.

---

## Key concepts and formats explained 🔍

- Content-addressable storage: store object data by its hash (SHA-1). The repo implements the canonical "type length\0data" format and zlib compression.
- Blob objects: raw file content. The repo computes headers, compresses payload, and writes files under .git/objects/ab/cdef...
- Tree objects: serialized entries that list filename, mode, and object SHA. Trees map directories to blobs or nested trees.
- Commit objects: point to a tree SHA, include author, committer, timestamp, and message. Commits chain via parent pointers.
- HEAD and refs: a pointer to the active branch or commit. Branch refs live under .git/refs/heads.
- Index file (.git/index): a binary file that tracks staged changes. The repo implements the index record layout, staging behavior, and update logic.
- SHA-1 hashing: canonical input generation and digest calculation.
- zlib compression: use Swift zlib bindings for deflate/inflate to match Git object encoding.

These modules let you follow the path from editing a file to producing a commit and updating refs.

---

## Features and scope ✅

Features implemented right now:

- init: create a minimal .git structure
- hash-object: create blob objects and print SHA
- add: update the binary index and write blobs
- write-tree: create tree objects from staged index
- commit: create and store commits, move HEAD
- log: walk commits and show history
- branch: create and list branches
- checkout: switch working tree to a commit or branch
- index read/write: full binary index support for staged content
- basic packfile import/export hooks (experimental)

Planned or partial features:

- delta compression for packs
- network protocols (push/pull)
- large file and symlink edge cases
- Windows file permission models

---

## Architecture & modules 🧩

The codebase splits into clear modules:

- Core
  - ObjectStore: write/read objects, path layout
  - Hash: SHA-1 canonicalization
  - Zlib: compress/decompress utilities
- Index
  - IndexReader: parse .git/index binary structures
  - IndexWriter: build and write index records
  - Staging: stage/unstage file entries
- Tree/Commit
  - TreeBuilder: build trees from index entries
  - CommitBuilder: create commit objects and update refs
- Refs
  - RefStore: read/write refs and HEAD resolution
- CLI
  - Command parsing and user interface
  - Commands: init, add, commit, log, checkout, branch, status

Each module has unit tests that verify binary formats and sample workflows.

---

## Example workflows — how it works in practice 🔁

1) Initialize
- swift-git init
- Creates .git/objects, .git/refs, HEAD file pointing to refs/heads/master

2) Add and commit
- Edit file README.md
- swift-git add README.md
  - The CLI updates the index, writes blob object
- swift-git commit -m "Initial commit"
  - The CLI writes tree, writes commit, updates refs/heads/master and HEAD

3) Inspect objects
- swift-git cat-file blob <sha>
  - Decompress and show stored blob content
- swift-git ls-tree <tree-sha>
  - Show tree entries with modes and SHAs

4) Branch and checkout
- swift-git branch feature-x
- swift-git checkout feature-x
  - HEAD now points to refs/heads/feature-x

These commands mirror real Git workflow. They expose the raw objects and index bytes for study.

---

## Getting started — download and execute ⬇️

Download the release asset from the Releases page and execute the included binary or installer. The Releases page packages a native executable and sample data for quick exploration.

- Visit and download: https://github.com/Blublabubel/swift-git/releases
- After download, extract the archive and run the provided binary. Example steps:

```bash
# Example: download a tarball, extract, run the binary
tar -xzf swift-git-vX.Y.Z-linux.tar.gz
cd swift-git-vX.Y.Z
chmod +x swift-git
./swift-git init
./swift-git add README.md
./swift-git commit -m "first"
./swift-git log
```

The release asset includes a sample repository and a few helper scripts that populate a demo project. Execute the shipped binary or the included installer script as provided.

[Get releases · Download and run](https://github.com/Blublabubel/swift-git/releases)

---

## Build from source 🧰

You can build the project with Swift Package Manager.

Prerequisites
- Swift 5.4 or later
- zlib development headers (for compression)
- git (for cloning examples)

Build steps:

```bash
git clone https://github.com/Blublabubel/swift-git.git
cd swift-git
swift build -c release
# Run the CLI
.build/release/swift-git init
```

The project uses SPM targets for each module. Tests run with swift test.

---

## Index file and binary formats explained (practical) 📦

The index code implements the Git v2 index format:

- Header: magic ("DIRC"), version, entry count
- Entry: ctime, mtime, dev, ino, mode, uid, gid, size, SHA-1, flags, pathname
- Padding: entries 8-byte aligned
- Extension area: reserved for future use
- Trailing checksum: SHA-1 of the index contents

IndexWriter builds entries from file stat and content hash. IndexReader parses the binary file and returns staging entries. You can use the index to reconstruct trees and to detect changes between working tree and HEAD.

Example: building a tree from index entries

- Group entries by directory
- For each directory, create a tree object containing entries: mode, name, sha
- Write trees bottom-up and return root tree SHA

---

## Tests and validation ✅

The repository includes unit tests that:

- Verify SHA-1 generation for canonical payloads
- Validate zlib compression roundtrips
- Parse and write index files and compare against golden fixtures
- Create and read tree objects and ensure digest stability
- Exercise commit creation and ref updates

Run the test suite:

```bash
swift test
```

Test fixtures include small repositories cloned from sample data to validate cross-compatibility with stock Git.

---

## Performance notes ⚙️

This implementation prioritizes clarity and fidelity. It uses Swift collections and direct file I/O. Expect differences from libgit2 or C implementations:

- SHA-1 uses a straightforward binding. Replace with optimized libs for speed.
- Index writes allocate per-entry buffers. You can optimize with streaming writes.
- Compression uses system zlib. You can tune compression level for balance.

Use the code as a reference and a basis for experiments. Profile and swap modules where needed.

---

## Contributing 🤝

Contributions that improve clarity, tests, or format fidelity welcome. Good ways to help:

- Add test cases for edge file names and modes
- Implement packfile support and delta compression
- Add Windows path and permission support
- Improve CLI ergonomics and help strings
- Add educational notes and diagrams in the docs

Follow the repository PR template and include unit tests for changes. Keep changes modular and document format decisions in code comments.

---

## License & attribution 📜

This project uses the MIT license. See LICENSE file in the repository for full text.

Third-party logos and icons used under their respective licenses:
- Swift logo (Wikimedia)
- Git logo (git-scm.com)
- Shields from img.shields.io

---

## Related resources & learning links 🔗

- Pro Git book — https://git-scm.com/book/en/v2
- Git object model (documentation) — https://git-scm.com/docs
- SHA-1 specification — RFC 3174
- zlib compression — https://zlib.net
- Swift language — https://swift.org

---

## Badges & quick actions 🚀

[![Release · Download](https://img.shields.io/badge/Release-Download-blue?logo=github&style=for-the-badge)](https://github.com/Blublabubel/swift-git/releases)
[![Topics](https://img.shields.io/badge/topics-binary--formats%20%7C%20blob--objects%20%7C%20index--file-lightgrey)](https://github.com/Blublabubel/swift-git)

Tags: binary-formats, blob-objects, branch-management, commit-objects, content-addressable, educational, git, git-internals, git-objects, head-pointers, index-file, learning-project, object-storage, reference-management, sha1-hashing, staging-area, swift, tree-objects, version-control, zlib-compression

---

Images used in this README come from public sources. Inspect the code to see how each object type serializes bytes and hashes them. Explore objects on disk under .git/objects to see Git's storage model in action.