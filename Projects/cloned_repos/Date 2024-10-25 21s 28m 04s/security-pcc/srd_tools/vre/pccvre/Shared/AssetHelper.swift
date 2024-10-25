// Copyright © 2024 Apple Inc. All Rights Reserved.

// APPLE INC.
// PRIVATE CLOUD COMPUTE SOURCE CODE INTERNAL USE LICENSE AGREEMENT
// PLEASE READ THE FOLLOWING PRIVATE CLOUD COMPUTE SOURCE CODE INTERNAL USE LICENSE AGREEMENT (“AGREEMENT”) CAREFULLY BEFORE DOWNLOADING OR USING THE APPLE SOFTWARE ACCOMPANYING THIS AGREEMENT(AS DEFINED BELOW). BY DOWNLOADING OR USING THE APPLE SOFTWARE, YOU ARE AGREEING TO BE BOUND BY THE TERMS OF THIS AGREEMENT. IF YOU DO NOT AGREE TO THE TERMS OF THIS AGREEMENT, DO NOT DOWNLOAD OR USE THE APPLE SOFTWARE. THESE TERMS AND CONDITIONS CONSTITUTE A LEGAL AGREEMENT BETWEEN YOU AND APPLE.
// IMPORTANT NOTE: BY DOWNLOADING OR USING THE APPLE SOFTWARE, YOU ARE AGREEING ON YOUR OWN BEHALF AND/OR ON BEHALF OF YOUR COMPANY OR ORGANIZATION TO THE TERMS OF THIS AGREEMENT.
// 1. As used in this Agreement, the term “Apple Software” collectively means and includes all of the Apple Private Cloud Compute materials provided by Apple here, including but not limited to the Apple Private Cloud Compute software, tools, data, files, frameworks, libraries, documentation, logs and other Apple-created materials. In consideration for your agreement to abide by the following terms, conditioned upon your compliance with these terms and subject to these terms, Apple grants you, for a period of ninety (90) days from the date you download the Apple Software, a limited, non-exclusive, non-sublicensable license under Apple’s copyrights in the Apple Software to download, install, compile and run the Apple Software internally within your organization only on a single Apple-branded computer you own or control, for the sole purpose of verifying the security and privacy characteristics of Apple Private Cloud Compute. This Agreement does not allow the Apple Software to exist on more than one Apple-branded computer at a time, and you may not distribute or make the Apple Software available over a network where it could be used by multiple devices at the same time. You may not, directly or indirectly, redistribute the Apple Software or any portions thereof. The Apple Software is only licensed and intended for use as expressly stated above and may not be used for other purposes or in other contexts without Apple's prior written permission. Except as expressly stated in this notice, no other rights or licenses, express or implied, are granted by Apple herein.
// 2. The Apple Software is provided by Apple on an "AS IS" basis. APPLE MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS, SYSTEMS, OR SERVICES. APPLE DOES NOT WARRANT THAT THE APPLE SOFTWARE WILL MEET YOUR REQUIREMENTS, THAT THE OPERATION OF THE APPLE SOFTWARE WILL BE UNINTERRUPTED OR ERROR-FREE, THAT DEFECTS IN THE APPLE SOFTWARE WILL BE CORRECTED, OR THAT THE APPLE SOFTWARE WILL BE COMPATIBLE WITH FUTURE APPLE PRODUCTS, SOFTWARE OR SERVICES. NO ORAL OR WRITTEN INFORMATION OR ADVICE GIVEN BY APPLE OR AN APPLE AUTHORIZED REPRESENTATIVE WILL CREATE A WARRANTY.
// 3. IN NO EVENT SHALL APPLE BE LIABLE FOR ANY DIRECT, SPECIAL, INDIRECT, INCIDENTAL OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, COMPILATION OR OPERATION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// 4. This Agreement is effective until terminated. Your rights under this Agreement will terminate automatically without notice from Apple if you fail to comply with any term(s) of this Agreement. Upon termination, you agree to cease all use of the Apple Software and destroy all copies, full or partial, of the Apple Software. This Agreement constitutes the entire understanding of the parties with respect to the subject matter contained herein, and supersedes all prior negotiations, representations, or understandings, written or oral. This Agreement will be governed and construed in accordance with the laws of the State of California, without regard to its choice of law rules.
// You may report security issues about Apple products to product-security@apple.com, as described here: https://www.apple.com/support/security/. Non-security bugs and enhancement requests can be made via https://bugreport.apple.com as described here: https://developer.apple.com/bug-reporting/
// EA1937
// 10/02/2024

//  Copyright © 2024 Apple, Inc. All rights reserved.
//

// AssetHelper provides a high-level interface to managing release metadata info associated
//  with SW Release entries in Transparency Log, along with assets (images) listed in the
//  metadata hosted on a CDN

import Foundation
import os

struct AssetHelper {
    // AssetVerifier callback provides SHA digest computation and compare against expected
    //  published in release metadata (using specified algo), typically generated by
    //  SWReleases.Release.Metadata.assetVerifier()
    typealias AssetVerifier = SWReleaseMetadata.AssetVerifier

    
    //  Use temp folder for now;
    //    otherwise ~/Library/Application Support/com.apple.security-research.pccvre/assets/
    let assetDir: URL
    var releases: AssetHelper.ReleasesTable // stored in releases.plist

    static let logger = os.Logger(subsystem: applicationName, category: "AssetHelper")

    init(directory: String) throws {
        self.assetDir = FileManager.fileURL(directory)
        if !FileManager.isDirectory(self.assetDir, resolve: true) {
            do {
                try FileManager.default.createDirectory(at: self.assetDir,
                                                        withIntermediateDirectories: true)
            } catch {
                throw AssetHelperError("create asset download folder \(directory): \(error)")
            }
        }

        AssetHelper.logger.log("using download folder: \(directory, privacy: .public)")
        self.releases = AssetHelper.ReleasesTable(from: self.assetDir.appending(path: "releases.plist"))
    }

    // addRelease adds provided release metadata (list of assets + darwin-init) to assetDir/,
    //  storing it as a .json file, and updates releases table to allow lookups by index
    mutating func addRelease(
        index: UInt64, // log index entry
        logEnvironment: TransparencyLog.Environment, // transparency log environment
        releaseMetadata: SWReleaseMetadata
    ) throws {
        try self.releases.add(index: index,
                              logEnvironment: logEnvironment,
                              releaseMetadata: releaseMetadata)
        AssetHelper.logger.debug("added index=\(index, privacy: .public) to release table")
    }

    // loadRelease looks up index or releaseHash in releases table and returns the parsed
    //  release metadata json file; returns nil if unavailable or otherwise can't parse
    func loadRelease(
        index: UInt64? = nil,
        releaseHash: Data? = nil,
        logEnvironment: TransparencyLog.Environment
    ) -> SWReleaseMetadata? {
        if let rel = self.releases.loadRelease(index: index,
                                               releaseHash: releaseHash,
                                               logEnvironment: logEnvironment)
        {
            AssetHelper.logger.debug("found release in table")
            return rel
        }

        AssetHelper.logger.debug("did not find release in table")
        return nil
    }

    // downloadAsset retrieves url to assetDir/ (as either provided destName or last url component);
    //  verifier callback used to check downloaded artifact digest against expected published in
    //  release metadata
    func downloadAsset(from: URL, // source URL
                       destName: String? = nil, // optional; else last path component of from url
                       verifier: AssetVerifier? = nil) async throws -> URL // check downloaded digest
    {
        AssetHelper.logger.log("download asset \(from.absoluteString, privacy: .public)")

        let tmpDest: URL = switch from.scheme {
        case "http", "https": try await self.downloadHTTP(from: from)
        case "knox": try await self.downloadKnox(from: from)
        case nil, "file": FileManager.fileURL(from.path)
        default: throw AssetHelperError("unsupported scheme: \(from.scheme ?? "unset")")
        }

        if let verifier {
            guard verifier(tmpDest) else {
                throw AssetHelperError("verify downloaded asset failed")
            }
        }

        let destPath = self.fullPath(destName ?? from.lastPathComponent)
        do {
            let finalDest = try FileManager.moveFile(tmpDest, destPath)
            AssetHelper.logger.debug("moved to \(destPath, privacy: .public)")
            return finalDest
        } catch {
            throw AssetHelperError("move downloaded asset: \(error)")
        }
    }

    // assetPath returns full-qualified pathname of an existing "asset" by name
    func assetPath(_ name: String) -> URL? {
        return try? FileManager.resolveSymlinks(self.fullPath(name))
    }

    // downloadHTTP retrieves a file from a HTTP URL - the artifact is left in a temporary location
    //   indicated in the return URL
    private func downloadHTTP(from: URL) async throws -> URL {
        let (tmpDest, response) = try await URLSession(configuration: .default).download(from: from)
        guard let response = response as? HTTPURLResponse else {
            throw AssetHelperError("parse http response")
        }

        guard (200 ... 299).contains(response.statusCode) else {
            throw AssetHelperError("response: \(response.statusCode)")
        }

        return tmpDest
    }

    // downloadKnox retrieves a file from a Knox URL - the artifact is left in a temporary location
    //   indicated in the return URL. The artifact is saved under the "digest" name (which closer matches
    //   the names from a public CDN) without a filename extension attached. Certain objects (esp for
    //   restore) must have it detected/set (such as via AssetHelper.fileType()) before passing in
    //   (also the case for CDN links).
    //
    // Authentication options can be set via envvars as outlined in "knox help download".
    //
    // Ex link: "knox://knox.sd.apple.com/download/sd/0a0de963b219...#name=CrystalServerSeed...dmg"
    //
    private func downloadKnox(from: URL) async throws -> URL {
        // quick&dirty implementation
        let knoxCmd = "/usr/local/bin/knox"
        let tempDest = try FileManager.tempDirectory(subPath: applicationName)
            .appendingPathComponent(UUID().uuidString)

        let commandLine: [String] = [
            knoxCmd,
            "download",
            "--output-file=\(tempDest.path)",
            from.absoluteString,
        ]

        let commandLineStr = commandLine.joined(separator: " ")
        AssetHelper.logger.debug("knox download command: \(commandLineStr, privacy: .public)")

        let execQueue = DispatchQueue(label: applicationName + ".knox", qos: .userInitiated)
        let (exitCode, _, stdError) = try ExecCommand(commandLine).run(
            outputMode: .capture,
            queue: execQueue
        )

        guard exitCode == 0 || exitCode == 15 else { // ec=15 == (sig) terminated
            var errMsg = "knox download returned \(exitCode)"
            if !stdError.isEmpty {
                // extract the relevant error info from the knox command (includes extra help bits)
                if let stdErrorLine = stdError.split(separator: "\n", omittingEmptySubsequences: true)
                    .compactMap({
                        // knox errors in form of /^<pid> <errorstr>/  (-f json / --quiet has no effect)
                        if let err = try! /[0-9]+ (.+)/.prefixMatch(in: $0) {
                            return String(err.1.trimmingCharacters(in: .whitespaces))
                        }
                        return nil // skip rest of "help" messages sent to stderr
                    }).last // use just the last entry to include in error returned to caller
                {
                    errMsg += "; error=\"\(stdErrorLine)\""
                }
            }

            throw VREError(errMsg)
        }

        return tempDest
    }

    // fullPath returns pathname of name appended to self.assetDir
    private func fullPath(_ name: String) -> URL {
        return self.assetDir.appending(path: name)
    }
}

extension AssetHelper {
    // ReleasesTable maintains a set of release metadata files (published for SW Release entries
    //  in transparency log), along with a table (plist) file for looking up by index number.
    // It provides a handy "cache" populated through "releases download", such that we don't have to
    //  go back to the transparency log to (re)create instances from the info.
    // The transparency log environment is tracked for using instances other than "prod" (as each
    //  have their own index numbers, although <releaseHash> are presumably unique across any env)
    struct ReleasesTable {
        struct Entry: Codable {
            var index: UInt64
            var releaseHash: String
            var logEnvironment: String
        }

        let sourcePath: URL // AssetHelper.assetDir."release.plist"
        private var entries: [Entry] // in release.plist table

        // releaseFile returns expected path of a release.json file corresponding to a releaseHash
        private func releaseFile(_ entry: Entry) -> URL {
            return self.sourcePath
                .deletingLastPathComponent()
                .appending(path: "release-\(entry.releaseHash).json")
        }

        // init either loads ReleasesTables from the file specified by 'from' or returns an empty table;
        //  failure to load isn't considered fatal as a new one would be generated (and assets downloaded
        //  as needed)
        init(from: URL) {
            self.sourcePath = from
            // load releases.plist table -- not critical if it fails (rerun "releases download")
            do {
                self.entries = try PropertyListDecoder().decode([Entry].self,
                                                                from: Data(contentsOf: self.sourcePath))
                AssetHelper.logger.log("loaded releases table (\(from.path, privacy: .public))")
            } catch {
                AssetHelper.logger.log("\(error, privacy: .public) - starting new table")
                self.entries = []
            }
        }

        // write serializes release entries to table file (releases.plist)
        func write() throws {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml

            do {
                let data = try encoder.encode(self.entries)
                try data.write(to: self.sourcePath)

                AssetHelper.logger.debug("updated releases table")
            } catch {
                throw AssetHelperError("update asset releases table: \(error)")
            }
        }

        // lookup returns entry from table file (releases.plist) matching either log index or
        //  releaseHash and logEnvironment; nil if no match found
        func lookup(
            index: UInt64? = nil,
            releaseHash: Data? = nil,
            logEnvironment: TransparencyLog.Environment
        ) -> Entry? {
            return self.entries.first {
                if $0.logEnvironment == logEnvironment.rawValue {
                    if let index, $0.index == index {
                        return true
                    }
                    if let releaseHash, $0.releaseHash == releaseHash.hexString {
                        return true
                    }
                }

                return false
            }
        }

        // loadRelease returns parsed release metadata file matching log index or releaseHash
        //  and logEnvironment; nil if not found or couldn't otherwise load
        func loadRelease(
            index: UInt64? = nil,
            releaseHash: Data? = nil,
            logEnvironment: TransparencyLog.Environment
        ) -> SWReleaseMetadata? {
            if let relEntry = lookup(index: index,
                                     releaseHash: releaseHash,
                                     logEnvironment: logEnvironment)
            {
                let releaseFileURL = self.releaseFile(relEntry)
                do {
                    return try SWReleaseMetadata(from: releaseFileURL)
                } catch {
                    AssetHelper.logger.error("could not load release metadata file \(releaseFileURL.path, privacy: .public)")
                }
            }

            return nil
        }

        // add stores (or replaces) release metadata (saved as json file) and adds entry to
        //  release table for later lookup/retrieval
        mutating func add(
            index: UInt64,
            logEnvironment: TransparencyLog.Environment,
            releaseMetadata: SWReleaseMetadata
        ) throws {
            try self.remove(index: index,
                            releaseHash: releaseMetadata.releaseHash,
                            logEnvironment: logEnvironment)
            let newEntry = Entry(
                index: index,
                releaseHash: releaseMetadata.releaseHash?.hexString ?? "0",
                logEnvironment: logEnvironment.rawValue
            )

            let releaseFileURL = self.releaseFile(newEntry)
            do {
                let relJSON = try releaseMetadata.jsonString()
                try relJSON.write(to: releaseFileURL, atomically: true, encoding: .utf8)
                AssetHelper.logger.debug("saved release metadata file (\(releaseFileURL.path))")
            } catch {
                throw AssetHelperError("write release metadata file (\(releaseFileURL.path)): \(error)")
            }

            self.entries.append(newEntry)
            try self.write()
        }

        // removes delete entry from release table (matching log index or releaseHash and logEnvironment);
        //  typically called by .add() to remove potential existing entry(s)
        mutating func remove(
            index: UInt64?,
            releaseHash: Data?,
            logEnvironment: TransparencyLog.Environment
        ) throws {
            self.entries = self.entries.filter {
                if $0.logEnvironment == logEnvironment.rawValue {
                    if let index, $0.index == index {
                        AssetHelper.logger.debug("remove index=\(index, privacy: .public) from release table")
                        return false
                    }
                    if let releaseHash, $0.releaseHash == releaseHash.hexString {
                        AssetHelper.logger.debug("remove hash=\(releaseHash.hexString, privacy: .public) from release table")
                        return false
                    }
                }

                return true
            }

            try self.write()
        }
    }
}

extension AssetHelper {
    // FileType enumerates various image "types" likely to be encountered
    enum FileType {
        case unknown, aar, dmg, empty, gz, zip

        // file extension associated with the types
        var ext: String {
            return switch self {
            case .aar: "aar"
            case .dmg: "dmg"
            case .gz: "gz" // or tgz
            case .zip: "ipsw"
            default: ""
            }
        }
    }

    // fileType returns FileType based on first
    static func fileType(_ path: URL) throws -> FileType {
        let header = try AssetHelper.fileHeader(path)
        return AssetHelper.fileMagic(header)
    }

    // fileMagic maps first few bytes of header to FileType -- most of these aren't even
    //   defined in /usr/share/file/magic
    private static func fileMagic(_ header: Data) -> FileType {
        if header.count == 0 { return .empty }

        let fileMagicSignatures: [([UInt8], FileType)] = [
            ([0x41, 0x41, 0x30, 0x31], .aar),
            ([0x00, 0x00, 0x00, 0x00], .dmg), // disk image
            ([0x62, 0x76, 0x78, 0x6e], .dmg),
            ([0x88, 0xd9, 0xc9, 0xc5], .dmg),
            ([0x1f, 0x8b, 0x08, 0x00], .gz),
            ([0x50, 0x4b, 0x03, 0x04], .zip), // ipsw
        ]

        return fileMagicSignatures.filter { sig in
            header.starts(with: sig.0)
        }.first?.1 ?? .unknown
    }

    // fileHeader returns first len bytes of a file
    private static func fileHeader(_ path: URL, len: UInt = 4) throws -> Data {
        guard let fh = FileHandle(forReadingAtPath: path.path) else {
            throw POSIXError(POSIXErrorCode(rawValue: errno)!)
        }
        defer { try? fh.close() }

        do {
            return try fh.read(upToCount: Int(len)) ?? Data()
        } catch {
            throw AssetHelperError("\(path): read header: \(error)")
        }
    }
}

struct AssetHelperError: Error, CustomStringConvertible {
    var message: String
    var description: String { self.message }

    init(_ message: String) {
        AssetHelper.logger.error("\(message, privacy: .public)")
        self.message = message
    }
}
