//
// Created by Banghua Zhao on 12/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import Foundation

/**
 * Git-specific errors that can occur during repository operations.
 *
 * These errors provide meaningful descriptions for common Git operations
 * that can fail.
 */
enum GitError: Error, LocalizedError {
    /// Thrown when attempting to initialize a Git repository in a directory
    case gitRepositoryAlreadyExists
    
    /// Thrown when attempting to commit with no staged changes
    case noChangesToCommit

    /// Thrown when operating on a directory that is not a Git repository
    case notAGitRepository

    /// Thrown when the index file format is invalid or corrupted
    case invalidIndexFormat

    var errorDescription: String? {
        switch self {
        case .gitRepositoryAlreadyExists:
            return "Git repository already exists in this directory"
        case .noChangesToCommit:
            return "No changes to commit"
        case .notAGitRepository:
            return "Not a git repository"
        case .invalidIndexFormat:
            return "Invalid index file format"
        }
    }
}
