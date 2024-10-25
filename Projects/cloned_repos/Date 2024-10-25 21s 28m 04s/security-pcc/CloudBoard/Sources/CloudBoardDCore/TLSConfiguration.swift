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

//  Copyright © 2023 Apple Inc. All rights reserved.

import CloudBoardIdentity
import CloudBoardLogging
import CloudBoardMetrics
import Dispatch
import InternalGRPC
import Network
import os
import Security

extension GRPCTLSConfiguration {
    private static let verifyQueue =
        DispatchQueue(label: "com.apple.cloudos.cloudboardd.GRPCTLSConfiguration.verifyQueue")

    fileprivate static let validatorLogger: Logger = .init(
        subsystem: "com.apple.cloudos.cloudboard",
        category: "TLSValidator"
    )

    typealias IdentityCallback = () -> IdentityManager.ResolvedIdentity?

    static func cloudboardProviderConfiguration(
        identityCallback: @escaping IdentityCallback,
        expectedPeerAPRN: APRN?,
        metricsSystem: MetricsSystem
    ) throws -> GRPCTLSConfiguration {
        let options = NWProtocolTLS.Options()

        options.setChallengeBlock(identityCallback)

        // Require TLSv1.3
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv13)

        for `protocol` in ["grpc-exp", "h2", "http/1.1"] {
            sec_protocol_options_add_tls_application_protocol(
                options.securityProtocolOptions,
                `protocol`
            )
        }

        // Set the challenge block.
        if let expectedPeerAPRN {
            switch expectedPeerAPRN.domain {
            case "sdr":
                sec_protocol_options_set_peer_authentication_required(options.securityProtocolOptions, true)
                sec_protocol_options_set_verify_block(
                    options.securityProtocolOptions,
                    Self.sdrValidationBlock(expectedAPRN: expectedPeerAPRN, metricsSystem: metricsSystem),
                    Self.verifyQueue
                )
            default:
                Self.validatorLogger.error(
                    "Unable to set validation logic for APRN \(expectedPeerAPRN, privacy: .public)"
                )
                throw TLSConfigurationError.unknownAPRNDomain(expectedPeerAPRN)
            }
        }

        return GRPCTLSConfiguration.makeServerConfigurationBackedByNetworkFramework(options: options)
    }

    private static func sdrValidationBlock(expectedAPRN: APRN, metricsSystem: MetricsSystem) -> sec_protocol_verify_t {
        precondition(expectedAPRN.domain == "sdr")

        return { _, trustRef, complete in
            // For SDR connections we don't trust any root other than the SDR one we provided.
            let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()
            var rc = SecTrustSetAnchorCertificates(trust, IdentityTranslator.sdrRootCAs as CFArray)
            if rc != errSecSuccess {
                Self.validatorLogger.error("Unable to trust SDR root, error \(rc, privacy: .public)")
                complete(false)
                Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .untrustedRootCA)
                return
            }

            rc = SecTrustEvaluateAsyncWithError(trust, Self.verifyQueue) { trust, result, error in
                guard result else {
                    guard let error else {
                        Self.validatorLogger.error("Unable to validate cert with no error")
                        complete(false)
                        Self.emitTLSVerificationFailure(
                            metricsSystem: metricsSystem,
                            failure: .unexpectedCertEvaluationFailure
                        )
                        return
                    }
                    Self.validatorLogger.error(
                        "Unable to validate cert, error: \(String(unredacted: error), privacy: .public)"
                    )
                    complete(false)
                    Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .invalidCertChain)
                    return
                }

                // Chain is valid, let's grab it.
                guard let untypedChain = SecTrustCopyCertificateChain(trust) else {
                    Self.validatorLogger.error("Missing cert chain, validation failed.")
                    complete(false)
                    Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .unexpectedNoCertChain)
                    return
                }

                guard let chain = untypedChain as? [SecCertificate] else {
                    Self.validatorLogger.error(
                        "Unable to unwrap the chain to [SecCertificate], have \(untypedChain, privacy: .public), validation failed."
                    )
                    complete(false)
                    Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .notAnX509Cert)
                    return
                }

                let computedAPRN: APRN
                do {
                    computedAPRN = try IdentityTranslator.computeAPRN(validatedCertChain: chain)
                } catch {
                    Self.validatorLogger.error(
                        "Error computing APRN for chain \(chain, privacy: .public), \(String(unredacted: error), privacy: .public), validation failed"
                    )
                    complete(false)
                    Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .aprnComputationFailure)
                    return
                }

                let ourResult = computedAPRN == expectedAPRN
                if ourResult {
                    Self.validatorLogger.debug(
                        "Successfully matched APRNs, \(expectedAPRN, privacy: .public) matched \(computedAPRN, privacy: .public)"
                    )
                } else {
                    Self.validatorLogger.error(
                        "Failed to match APRN, expected \(expectedAPRN, privacy: .public) but got \(computedAPRN, privacy: .public)"
                    )
                    Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .untrustedAPRN)
                }

                complete(ourResult)
            }

            if rc != errSecSuccess {
                Self.validatorLogger.error(
                    "Unable to call SecTrustEvaluateAsyncWithError, error \(rc, privacy: .public)"
                )
                complete(false)
                Self.emitTLSVerificationFailure(metricsSystem: metricsSystem, failure: .evaluationCallbackNotInvoked)
                return
            }
        }
    }

    private static func emitTLSVerificationFailure(metricsSystem: MetricsSystem, failure: TLSVerificationFailure) {
        metricsSystem.emit(
            Metrics.TLSConfiguration.TLSVerificationErrorCounter(action: .increment, failureReason: failure.rawValue)
        )
    }
}

enum TLSConfigurationError: Error, ReportableError {
    case unknownAPRNDomain(APRN)
    var publicDescription: String {
        switch self {
        case .unknownAPRNDomain(let aprn):
            return "TLSConfigurationError.unknownAPRNDomain"
        }
    }
}

enum TLSVerificationFailure: String {
    case aprnComputationFailure = "APRN Computation Failure"
    case evaluationCallbackNotInvoked = "Evaluation Callback Not Invoked"
    case invalidCertChain = "Invalid Cert Chain"
    case notAnX509Cert = "Not an X509 Cert"
    case unexpectedCertEvaluationFailure = "Unexpected Cert Evaluation Failure"
    case unexpectedNoCertChain = "Unexpected No Cert Chain"
    case untrustedRootCA = "Untrusted Root CA"
    case untrustedAPRN = "Untrusted APRN"
}
