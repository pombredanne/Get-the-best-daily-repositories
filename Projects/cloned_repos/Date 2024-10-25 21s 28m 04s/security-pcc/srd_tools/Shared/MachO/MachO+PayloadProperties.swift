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

extension MachO64 {
    fileprivate struct Region {
        let identifier: String
        var segments = [Segment]()

        init (identifier: String) {
            self.identifier = identifier
        }

        mutating func addSegment(_ segment: MachO64.Segment) throws {
            if self.segments.count > 1 {
                let lastSegment = self.segments.last!
                guard lastSegment.fileOffset + lastSegment.size == segment.fileOffset else {
                    throw ParseError.segmentContiguous(segment.name)
                }
            }
            self.segments.append(segment)
        }

        var offset: UInt64 {
            return self.segments.first!.fileOffset
        }

        var size: UInt64 {
            return self.segments.map{$0.size}.reduce(0, +)
        }

        var lowestAddr: UInt64 {
            return self.segments.map{$0.virtAddr}.reduce(self.segments.first!.virtAddr) {
                if $0 < $1 {
                    return $0
                }
                return $1
            }
        }
    }

    fileprivate var regions: [Region] {
        get throws {
            var allRegions: [String: Region] = [
                "read-only": Region(identifier: "r"),
                "read-write": Region(identifier: "w"),
                "sptm-data": Region(identifier: "s"),
                "executable": Region(identifier: "x"),
                "executable-boot": Region(identifier: "b"),
                "link-edit": Region(identifier: "l")
            ]

            for segment in try self.segments {
                switch segment.name {
                case "__TEXT", "__PRELINK_TEXT", "__DATA_CONST", "__LATE_CONST":
                    try allRegions["read-only"]!.addSegment(segment)
                case "__PRELINK_INFO", "__DATA", "__BOOTDATA":
                    try allRegions["read-write"]!.addSegment(segment)
                case "__DATA_SPTM":
                    try allRegions["sptm-data"]!.addSegment(segment)
                case "__TEXT_EXEC", "__LAST":
                    try allRegions["executable"]!.addSegment(segment)
                case "__TEXT_BOOT_EXEC":
                    try allRegions["executable-boot"]!.addSegment(segment)
                case "__LINKEDIT":
                    try allRegions["link-edit"]!.addSegment(segment)
                default:
                    throw ParseError.segmentUnknown(self.fileName, segment.name)
                }
            }

            return allRegions.compactMap{
                if $0.value.segments.count == 0 {
                    return nil
                }
                return $0.value
            }
        }
    }

    var payloadProperties: [String: UInt64] {
        get throws {
            var properties: [String: UInt64] = [:]

            /* Add all the regions */
            for region in try self.regions {
                properties["kc" + region.identifier + "f"] = region.offset
                properties["kc" + region.identifier + "z"] = region.size
            }

            /* Add the entry point */
            properties["kcep"] = try self.unixThread.entryPoint

            /* Add the base address */
            properties["kclo"] = try self.regions.map {
                $0.lowestAddr
            }.reduce(try self.regions.first!.lowestAddr) {
                if $0 < $1 {
                    return $0
                }
                return $1
            }

            return properties
        }
    }
}
