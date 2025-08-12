//
// Created by Banghua Zhao on 12/08/2025
// Copyright Apps Bay Limited. All rights reserved.
//

import CommonCrypto
import Foundation
import zlib

/**
 * Calculate SHA1 hash of data.
 *
 * SHA1 is used by Git to identify objects uniquely. Each Git object
 * (blob, tree, commit) is identified by its SHA1 hash.
 *
 * Example:
 * ```swift
 * let data = "Hello, World!".data(using: .utf8)!
 * let hash = calculateSHA1(data)
 * // hash = "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0"
 * ```
 *
 * @param data The data to hash
 * @return 40-character hex string representing the SHA1 hash
 */
func calculateSHA1(_ data: Data) -> String {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
    data.withUnsafeBytes { buffer in
        _ = CC_SHA1(buffer.baseAddress, CC_LONG(buffer.count), &digest)
    }
    return digest.map { String(format: "%02hhx", $0) }.joined()
}

/**
 * Compress data using zlib deflate algorithm.
 *
 * Git stores all objects in compressed format to save disk space.
 * The compression uses zlib with the deflate algorithm.
 *
 * Example:
 * ```swift
 * let originalData = "Hello, World!".data(using: .utf8)!
 * let compressed = try compressData(originalData)
 * // compressed is smaller than originalData
 * ```
 *
 * @param data The data to compress
 * @return Compressed data
 * @throws Compression errors if zlib operations fail
 */
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
