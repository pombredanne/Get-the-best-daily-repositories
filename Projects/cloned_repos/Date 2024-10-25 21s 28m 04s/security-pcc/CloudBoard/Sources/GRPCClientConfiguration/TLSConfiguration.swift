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

//  Copyright © 2024 Apple Inc. All rights reserved.

import CloudBoardIdentity
import CloudBoardLogging
import Dispatch
import InternalGRPC
import Network
import os
import Security

public struct TLSConfiguration: Codable, Hashable, Sendable {
    enum CodingKeys: String, CodingKey {
        case _enable = "Enable"
        case sniOverride = "SNIOverride"
        case _enablemTLS = "EnableMTLS"
    }

    public var _enable: Bool?
    /// If true, TLS is enabled. Otherwise an insecure connection is used.
    public var enable: Bool {
        self._enable ?? true
    }

    /// Override for Server Name Indication to validate in server certificate
    public var sniOverride: String?
    public var _enablemTLS: Bool?
    /// Enable mTLS, using the node's Narrative identity client certificate
    public var enablemTLS: Bool {
        self._enablemTLS ?? true
    }
}

extension TLSConfiguration {
    public init(enable: Bool, sniOverride: String? = nil, enablemTLS: Bool? = nil) {
        self._enable = enable
        self.sniOverride = sniOverride
        self._enablemTLS = enablemTLS ?? true
    }
}

extension GRPCTLSConfiguration {
    fileprivate static let validatorLogger: Logger = .init(
        subsystem: "com.apple.cloudos.cloudboard",
        category: "TLSValidator"
    )

    public typealias IdentityCallback = () -> IdentityManager.ResolvedIdentity?

    public static func grpcTLSConfiguration(
        hostnameOverride: String?,
        identityCallback: IdentityCallback?,
        customRoot: SecCertificate?
    ) -> GRPCTLSConfiguration {
        let options = NWProtocolTLS.Options()

        if let identityCallback {
            Self.validatorLogger.log("Setting client cert for service discovery")
            options.setChallengeBlock(identityCallback)
        }

        // Require TLSv1.3
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)

        if let hostnameOverride {
            sec_protocol_options_set_tls_server_name(
                options.securityProtocolOptions,
                hostnameOverride
            )
        }

        if let customRoot {
            Self.validatorLogger.warning("Setting custom root for service discovery")

            let validationQueue = DispatchQueue(label: "com.apple.cloudos.cloudboard.tlsValidationQueue")
            sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
            sec_protocol_options_set_verify_block(
                options.securityProtocolOptions,
                { _, trustRef, complete in
                    // For custom root we don't trust any root other than the custom one we provided.
                    let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()
                    var rc = SecTrustSetAnchorCertificates(trust, [customRoot] as CFArray)
                    if rc != errSecSuccess {
                        Self.validatorLogger.error("Unable to trust custom root, error \(rc, privacy: .public)")
                        complete(false)
                        return
                    }
                    rc = SecTrustEvaluateAsyncWithError(trust, validationQueue) { _, result, error in
                        Self.validatorLogger.debug(
                            "Custom root validation result \(result, privacy: .public), error \(String(describing: error), privacy: .public)"
                        )
                        complete(result)
                    }

                    if rc != errSecSuccess {
                        Self.validatorLogger.error(
                            "Unable to call SecTrustEvaluateAsyncWithError, error \(rc, privacy: .public)"
                        )
                        complete(false)
                        return
                    }
                },
                validationQueue
            )
        }

        for `protocol` in ["grpc-exp", "h2", "http/1.1"] {
            sec_protocol_options_add_tls_application_protocol(
                options.securityProtocolOptions,
                `protocol`
            )
        }

        return GRPCTLSConfiguration.makeClientConfigurationBackedByNetworkFramework(options: options)
    }
}

extension NWProtocolTLS.Options {
    public func setChallengeBlock(_ callback: @escaping GRPCTLSConfiguration.IdentityCallback) {
        sec_protocol_options_set_challenge_block(
            self.securityProtocolOptions,
            { _, challengeComplete in
                GRPCTLSConfiguration.validatorLogger.debug("Loading identity for TLS challenge.")

                guard let identity = callback() else {
                    GRPCTLSConfiguration.validatorLogger.error("Unable to load TLS identity, failing handshake.")
                    challengeComplete(nil)
                    return
                }

                guard let targetIdentity = sec_identity_create_with_certificates(
                    identity.base,
                    identity.chain as CFArray
                ) else {
                    GRPCTLSConfiguration.validatorLogger
                        .error("Failed to create identity from parts, failing handshake.")
                    challengeComplete(nil)
                    return
                }

                GRPCTLSConfiguration.validatorLogger
                    .debug("Successfully loaded identity for TLS challenge. \(identity.credential)")
                challengeComplete(targetIdentity)
            },
            .global(qos: .userInitiated)
        )
    }
}

public enum ClientTLSConfiguration: CustomStringConvertible {
    case plaintext
    case simpleTLS(SimpleTLS)

    public struct SimpleTLS: CustomStringConvertible {
        public var sniOverride: String?
        public var localIdentityCallback: GRPCTLSConfiguration.IdentityCallback?

        // Override for setting a custom root cert, used only in testing.
        public var customRoot: SecCertificate?

        public var description: String {
            "SimpleTLSConfig(sniOverride: \(String(describing: self.sniOverride)))"
        }

        public init(
            sniOverride: String? = nil,
            localIdentityCallback: GRPCTLSConfiguration.IdentityCallback? = nil,
            customRoot: SecCertificate? = nil
        ) {
            self.sniOverride = sniOverride
            self.localIdentityCallback = localIdentityCallback
            self.customRoot = customRoot
        }
    }

    public init(
        _ tlsConfig: TLSConfiguration?,
        identityCallback: GRPCTLSConfiguration.IdentityCallback?
    ) {
        if let tlsConfig, tlsConfig.enable {
            let usedIdentity = tlsConfig.enablemTLS ? identityCallback : nil
            self = .simpleTLS(.init(sniOverride: tlsConfig.sniOverride, localIdentityCallback: usedIdentity))
        } else {
            self = .plaintext
        }
    }

    public var description: String {
        switch self {
        case .plaintext:
            return "TLSConfiguration.plaintext"
        case .simpleTLS:
            return "TLSConfiguration.simpleTLS"
        }
    }
}
