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

//
//  TC2DaemonHost.swift
//  PrivateCloudCompute
//
//  Copyright © 2024 Apple Inc. All rights reserved.
//

import AppSupport
import Darwin
import Foundation
import Foundation_Private.NSXPCConnection
import PrivateCloudCompute
import os.lock

protocol TC2DaemonHostDelegate: Sendable {
    var requestMetadata: TC2TrustedRequestFactoriesMetadata { get }
    func prefetchRequest(workloadType: String, workloadParameters: [String: String]) async -> Data?
    func prewarmRequest(workloadType: String, workloadParameters: [String: String], bundleIdentifier: String, featureIdentifier: String)
    func structuredRequestFactory(forSetup: TC2ResolvedSetup) -> ThimbledTrustedRequestFactory
    func prefetchCache() async -> [String]
    func prefetchParametersCache() -> [String]
    func prefetchParametersCacheSavedState() -> [String]
    func prefetchCacheReset() async -> Bool
    func listRateLimits(bundleIdentifier: String?, featureIdentifier: String?, fetch: Bool) async -> Data?
    func addRateLimit(bundleIdentifier: String?, featureIdentifier: String?, workloadType: String?, count: UInt, duration: Double, ttl: Double, jitter: Double) async
    func resetRateLimits() async
    func fetchServerDrivenConfiguration() async -> Data
    func listServerDrivenConfiguration() async -> Data
    func setServerDrivenConfiguration(json: Data) async -> Data
}

/// This object implements the protocol which we have defined. It provides the actual behavior for the service. It is 'exported' by the service to make it available to the process hosting the service over an NSXPCConnection.
final class TC2DaemonHost: NSObject, TC2DaemonProtocol, @unchecked Sendable {
    let logger = tc2Logger(forCategory: .Daemon)
    let delegate: TC2DaemonHostDelegate
    let connection: NSXPCConnection
    let config: TC2Configuration
    let rateLimitValve: OverflowValve<ContinuousClock>

    init(config: TC2Configuration, delegate: TC2DaemonHostDelegate, connection: NSXPCConnection) {
        self.delegate = delegate
        self.connection = connection
        self.config = config
        self.rateLimitValve = OverflowValve(
            frequency: Duration.seconds(config[.rateLimitRequestMinimumSpacing]),
            clock: ContinuousClock()
        )
    }

    @objc func currentEnvironment(completion: (String) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.serverEnvironment) else {
            return completion("")
        }

        completion(self.config.environment.name)
    }

    /// This implements the example protocol. Replace the body of this class with the implementation of this service's protocol.
    @objc func echo(text: String, completion: (String) -> Void) {
        let response = "thimbled Echo: \(text)"
        logger.log("echo: \(text)")
        completion(response)
    }

    @objc func trustedRequest(
        withParameters parameters: Data,
        requestID clientRequestID: UUID,
        bundleIdentifier: String?,
        originatingBundleIdentifier: String?,
        featureIdentifier: String?,
        sessionIdentifier: UUID?,
        completion: @escaping @Sendable (TC2XPCTrustedRequestProtocol?, Data?) -> Void
    ) {
        // The requestID that is passed in here is the clientRequestID, i.e., the ID
        // that the caller provides. We track it for logging but we do not pass it to the server.
        do {
            let xpcRequest = try self._trustedRequest(
                withParameters: parameters, clientRequestID: clientRequestID, bundleIdentifier: bundleIdentifier, originatingBundleIdentifier: originatingBundleIdentifier, featureIdentifier: featureIdentifier, sessionIdentifier: sessionIdentifier)
            completion(xpcRequest, nil)
        } catch {
            completion(nil, error.json)
        }
    }

    private func _trustedRequest(
        withParameters parameters: Data,
        clientRequestID: UUID,
        bundleIdentifier: String?,
        originatingBundleIdentifier: String?,
        featureIdentifier: String?,
        sessionIdentifier: UUID?
    ) throws(TrustedCloudComputeError) -> any TC2XPCTrustedRequestProtocol {
        guard hasEntitlement(.requests) || hasEntitlement(.requests_old) else {
            throw TrustedCloudComputeError(message: "missing entitlements")
        }

        let clientBundleIdentifier = bundleIdentifierForAuditToken(auditToken: connection.auditToken)
        let allowBundleIdentifierOverride = hasEntitlement(.bundleIdentifierOverride) || hasEntitlement(.bundleIdentifierOverride_old)
        let effectiveUserIdentifier = effectiveUserIdentifier(auditToken: connection.auditToken)

        guard let clientBundleIdentifier else {
            throw TrustedCloudComputeError(message: "missing client bundle identifier")
        }

        let resolvedSetup = TC2ResolvedSetup(clientBundleIdentifier: clientBundleIdentifier, allowBundleIdentifierOverride: allowBundleIdentifierOverride)

        let factory = delegate.structuredRequestFactory(forSetup: resolvedSetup)

        guard let tc2RequestParameters = TC2RequestParameters(json: parameters) else {
            throw TrustedCloudComputeError(message: "failure decoding TC2RequestParameters")
        }

        guard
            let xpcRequest = factory.startTrustedRequest(
                clientRequestID: clientRequestID,
                parameters: tc2RequestParameters,
                bundleID: bundleIdentifier,
                originatingBundleIdentifier: originatingBundleIdentifier,
                featureID: featureIdentifier,
                sessionID: sessionIdentifier,
                effectiveUserIdentifier: effectiveUserIdentifier
            )
        else {
            throw TrustedCloudComputeError(message: "failure retrieving request from factory")
        }

        return xpcRequest
    }

    func requestMetadata(completion: @escaping @Sendable (Data?) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion(nil)
        }

        return completion(delegate.requestMetadata.json)
    }

    func prefetchRequest(workloadType: String, workloadParameters: [String: String], completion: @escaping @Sendable (Data?) -> Void) {
        guard hasEntitlement(.prefetchRequest) || hasEntitlement(.prefetchRequest_old) else {
            completion(nil)
            return
        }

        Task {
            let data = await delegate.prefetchRequest(workloadType: workloadType, workloadParameters: workloadParameters)
            completion(data)
        }
    }

    func prewarmRequest(
        workloadType: String,
        workloadParameters: [String: String],
        bundleIdentifier: String?,
        featureIdentifier: String,
        completion: @escaping @Sendable () -> Void
    ) {
        // Entitlement is still the same, since the underlying call is going to be a prefetch
        guard hasEntitlement(.prefetchRequest) || hasEntitlement(.prefetchRequest_old) else {
            return completion()
        }

        let clientBundleIdentifier = bundleIdentifierForAuditToken(auditToken: connection.auditToken)
        let allowBundleIdentifierOverride = hasEntitlement(.bundleIdentifierOverride) || hasEntitlement(.bundleIdentifierOverride_old)

        guard let clientBundleIdentifier else {
            return completion()
        }

        let bundleIdentifierForPrewarm =
            if allowBundleIdentifierOverride, let bundleIdentifier {
                bundleIdentifier
            } else {
                clientBundleIdentifier
            }

        self.delegate.prewarmRequest(
            workloadType: workloadType,
            workloadParameters: workloadParameters,
            bundleIdentifier: bundleIdentifierForPrewarm,
            featureIdentifier: featureIdentifier
        )
        completion()
    }

    func prefetchCache(completion: @escaping @Sendable ([String]) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion([])
        }

        Task {
            let result = await delegate.prefetchCache()
            completion(result)
        }
    }

    func prefetchParametersCache(completion: @escaping @Sendable ([String]) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion([])
        }

        completion(delegate.prefetchParametersCache())
    }

    func prefetchParametersCacheSavedState(completion: @escaping @Sendable ([String]) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion([])
        }

        return completion(delegate.prefetchParametersCacheSavedState())
    }

    func prefetchCacheReset(completion: @escaping @Sendable (Bool) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion(false)
        }

        Task {
            let result = await delegate.prefetchCacheReset()
            completion(result)
        }
    }

    // The difference between knownRateLimits and listRateLimits is that knownRateLimits is ultimately
    // exposed in API, and it (a) will make a determination for itself whether to issue a fetch to the
    // server, and (b) will default to the caller's bundleID but allow them to override with the
    // correct entitlment, and therefore (c) uses its own entitlement separate from the admin one.
    func knownRateLimits(bundleIdentifier: String?, featureIdentifier: String?, skipFetch: Bool, completion: @escaping @Sendable (Data?) -> Void) {
        guard hasEntitlement(.knownRateLimits) || hasEntitlement(.knownRateLimits_old) else {
            return completion(nil)
        }

        guard hasEntitlement(.bundleIdentifierOverride) || hasEntitlement(.bundleIdentifierOverride_old) || bundleIdentifier == nil else {
            logger.log("attempt to set bundleIdentifierOverride without entitlement rejected")
            return completion(nil)
        }
        let bundleIdentifier = bundleIdentifier ?? bundleIdentifierForAuditToken(auditToken: connection.auditToken)

        // Decide whether to fetch. If skipFetch is true, we never fetch. If it's false
        // we make a decision based on the timeinterval since the last fetch.
        Task {
            let result =
                if skipFetch {
                    await delegate.listRateLimits(bundleIdentifier: bundleIdentifier, featureIdentifier: featureIdentifier, fetch: false)
                } else {
                    await delegate.listRateLimits(bundleIdentifier: bundleIdentifier, featureIdentifier: featureIdentifier, fetch: self.rateLimitValve.allow())
                }
            completion(result)
        }

    }

    func listRateLimits(bundleIdentifier: String?, featureIdentifier: String?, fetch: Bool, completion: @escaping @Sendable (Data?) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion(nil)
        }

        Task {
            let result = await delegate.listRateLimits(bundleIdentifier: bundleIdentifier, featureIdentifier: featureIdentifier, fetch: fetch)
            completion(result)
        }
    }

    func addRateLimit(
        bundleIdentifier: String?,
        featureIdentifier: String?,
        workloadType: String?,
        count: UInt,
        duration: Double,
        ttl: Double,
        jitter: Double,
        completion: @escaping @Sendable () -> Void
    ) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion()
        }

        Task {
            await delegate.addRateLimit(bundleIdentifier: bundleIdentifier, featureIdentifier: featureIdentifier, workloadType: workloadType, count: count, duration: duration, ttl: ttl, jitter: jitter)
            completion()
        }
    }

    func resetRateLimits(completion: @escaping @Sendable () -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion()
        }

        Task {
            await delegate.resetRateLimits()
            completion()
        }
    }

    func fetchServerDrivenConfiguration(completion: @escaping @Sendable (Data) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion(Data())
        }

        Task {
            let result = await delegate.fetchServerDrivenConfiguration()
            completion(result)
        }
    }

    func listServerDrivenConfiguration(completion: @escaping @Sendable (Data) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion(Data())
        }

        Task {
            let result = await delegate.listServerDrivenConfiguration()
            completion(result)
        }
    }

    func setServerDrivenConfiguration(json: Data, completion: @escaping @Sendable (Data) -> Void) {
        guard hasEntitlement(.admin) || hasEntitlement(.admin_old) else {
            return completion(Data())
        }

        Task {
            let result = await delegate.setServerDrivenConfiguration(json: json)
            completion(result)
        }
    }

    private func hasEntitlement(_ entitlement: TC2Entitlement) -> Bool {
        guard let value = self.connection.value(forEntitlement: entitlement.rawValue) else {
            logger.log("entitlement not present: \(entitlement.rawValue)")
            return false
        }
        switch value {
        case let b as Bool:
            logger.log("entitlement observed: \(entitlement.rawValue) = \(b)")
            return b
        case let x:
            logger.log("entitlement is wrong type: \(entitlement.rawValue) = \(type(of: x))")
            return false
        }
    }

    private func bundleIdentifierForAuditToken(auditToken: audit_token_t) -> String? {
        var bundleID: Unmanaged<CFString>?
        guard CPCopyBundleIdentifierAndTeamFromAuditToken(auditToken, &bundleID, nil) else {
            logger.error("could not get client bundle identifier")
            return nil
        }

        guard let bundleID = bundleID?.takeRetainedValue() else {
            logger.error("could not retain client bundle identifier")
            return nil
        }
        return bundleID as String
    }

    private func effectiveUserIdentifier(auditToken: audit_token_t) -> uid_t? {
        #if os(macOS)
        let euid = audit_token_to_euid(auditToken)
        logger.debug("audit_token_to_euid=\(Int(euid))")
        return euid
        #else
        return nil
        #endif
    }
}
