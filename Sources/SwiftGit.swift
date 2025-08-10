// The Swift Programming Language
// https://docs.swift.org/swift-book
// 
// Swift Argument Parser
// https://swiftpackageindex.com/apple/swift-argument-parser/documentation

import ArgumentParser

@main
struct SwiftGit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-git",
        abstract: "A Git implementation in Swift",
        subcommands: [Init.self, Add.self, Commit.self]
    )
    
    mutating func run() throws {
        print("SwiftGit - A Git implementation in Swift")
        print("Use 'swift-git --help' for more information")
    }
}

struct Init: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Initialize a new Git repository"
    )
    
    @Option(name: .shortAndLong, help: "Directory to initialize")
    var directory: String = "."
    
    mutating func run() throws {
        let repository = GitRepository(path: directory)
        try repository.initialize()
    }
}

struct Add: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add files to the staging area"
    )
    
    @Argument(help: "Files to add")
    var files: [String]
    
    mutating func run() throws {
        let repository = GitRepository(path: ".")
        try repository.add(files: files)
    }
}

struct Commit: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "commit",
        abstract: "Create a new commit"
    )
    
    @Option(name: .shortAndLong, help: "Commit message")
    var message: String
    
    mutating func run() throws {
        let repository = GitRepository(path: ".")
        try repository.commit(message: message)
    }
}
