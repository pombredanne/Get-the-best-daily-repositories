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

import Foundation
import System

// VRE.Config holds state for instances (above that for VMs)

extension VRE {
    struct HTTPServiceDef: Codable {
        let enabled: Bool
        var address: String? // automatically detected
        var port: UInt16? // automatically detected

        init(
            enabled: Bool,
            address: String? = nil,
            port: UInt16? = nil
        ) {
            self.enabled = enabled
            self.address = address
            self.port = port
        }
    }

    struct Config: Codable {
        // ReleaseAsset is a list of "assets" from the metadata payload of a
        //  SW Release Transparency Log entry -- can be a useful reference to look up by
        //  asset "type" (ASSET_TYPE_XX) for operations such as adding ssh support, which
        //  requires adding the ASSET_TYPE_DEBUG_SHELL cryptex.
        //
        //  Other cryptexes provided outside of a SW Release are not stored here
        struct ReleaseAsset: Codable {
            let type: String
            let file: String
            let variant: String

            init(
                type: String,
                file: String,
                variant: String
            ) {
                self.type = type
                self.file = file
                self.variant = variant
            }

            init(asset: SWReleaseMetadata.Asset) {
                self.type = SWReleaseMetadata.assetTypeName(asset.type)
                self.file = FileManager.fileURL(asset.url).lastPathComponent
                self.variant = asset.variant
            }
        }

        let name: String
        let releaseID: String
        let httpService: HTTPServiceDef?
        var releaseAssets: [ReleaseAsset] // these are expected to come from release metadata

        init(
            name: String,
            releaseID: String,
            httpService: VRE.HTTPServiceDef?,
            releaseAssets: [ReleaseAsset]? = nil
        ) {
            self.name = name
            self.releaseID = releaseID
            self.httpService = httpService
            self.releaseAssets = releaseAssets ?? []

            let selfjson = asJSONString(self)
            VRE.logger.debug("config instance: \(selfjson, privacy: .public)")
        }

        init(contentsOf url: URL) throws {
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw VREError("load instance \(url.absoluteString): \(error)")
            }

            let decoder = PropertyListDecoder()
            do {
                self = try decoder.decode(Config.self, from: data)
            } catch {
                throw VREError("parse instance: \(error)")
            }

            let selfjson = asJSONString(self)
            VRE.logger.debug("config instance from \(url.path, privacy: .public): \(selfjson, privacy: .public)")
        }

        // write saves instance configuration as a plist file
        func write(to: URL) throws {
            let encoder = PropertyListEncoder()
            encoder.outputFormat = .xml

            do {
                let data = try encoder.encode(self)
                try data.write(to: to, options: .atomic)
            } catch {
                throw VREError("save instance \(to.absoluteString): \(error)")
            }

            let configjson = asJSONString(self)
            VRE.logger.log("wrote config \(to.path, privacy: .public): \(configjson, privacy: .public)")
        }

        // addReleaseAsset adds an entry to releaseAssets table (stored in configuration file) -
        //  previous entries with matching type/variant name are first removed
        mutating func addReleaseAsset(
            type: String,
            file: String,
            variant: String
        ) {
            self.removeReleaseAsset(variant: variant, type: type)
            self.releaseAssets.append(ReleaseAsset(type: type,
                                                   file: FileManager.fileURL(file).lastPathComponent,
                                                   variant: variant))
        }

        // removeReleaseAsset deletes entries from releaseAssets table by type or variant name
        mutating func removeReleaseAsset(
            variant: String,
            type: String
        ) {
            self.releaseAssets = self.releaseAssets.filter { $0.type != type && $0.variant != variant }
        }

        // lookupAssetType returns first releaseAsset entry matching asset type
        func lookupAssetType(type: SWReleaseMetadata.AssetType) -> ReleaseAsset? {
            return self.releaseAssets.first(where: { $0.type == SWReleaseMetadata.assetTypeName(type) })
        }
    }
}
