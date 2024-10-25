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
//  RateLimitConfiguration.swift
//  PrivateCloudCompute
//
//  Copyright © 2024 Apple Inc. All rights reserved.
//

import CollectionsInternal
import Foundation
import PrivateCloudCompute

// MARK: - RateLimitFilter

// This type is the part of the RateLimitConfig that is the "filter",
// in the sense that it determines which requests a rate limit applies
// to, but does not know what the rate or timing concerns are. You
// can ask of it whether it would apply to a given request.
struct RateLimitFilter: Sendable, Equatable, Hashable, Codable {
    var bundleID: String?
    var featureID: String?
    var workloadType: String?
    var workloadTags: [WorkloadTag]

    // FYI, tuples do not conform to Equatable, Hashable yet
    struct WorkloadTag: Sendable, Equatable, Hashable, Codable {
        var key: String
        var value: String

        init(key: String, value: String) {
            self.key = key
            self.value = value
        }
    }

    init(bundleID: String?, featureID: String?, workloadType: String?, workloadTags: [WorkloadTag]) {
        self.bundleID = bundleID
        self.featureID = featureID
        self.workloadType = workloadType
        self.workloadTags = workloadTags
    }

    init(bundleID: String?, featureID: String?, workloadType: String?, workloadParams: [String: String]) {
        self.init(
            bundleID: bundleID,
            featureID: featureID,
            workloadType: workloadType,
            workloadTags: workloadParams.map { WorkloadTag(key: $0.key, value: $0.value) }
        )
    }
}

extension RateLimitFilter {
    func matches(_ requestMetadata: RateLimiterRequestMetadata) -> Bool {
        return matchesBundleID(requestMetadata.bundleID)
            && matchesFeatureID(requestMetadata.featureID)
            && matchesWorkloadType(requestMetadata.workloadType)
            && matchesWorkloadTags(requestMetadata.workloadTags)
    }

    func mightApplyWhen(bundleIdentifier: String?, featureIdentifier: String?) -> Bool {
        switch (bundleIdentifier, featureIdentifier) {
        case (nil, nil):
            // In this case, we want to know whether the filter might apply with
            // no information about to which feature or bundle id. So yes, the filter
            // might apply.
            return true
        case (let b?, nil):
            // Here, we know that we are asking about bundleIdentifier b, which means
            // that the filter either must ask for b or not ask for anything.
            return matchesBundleID(b)
        case (nil, let f?):
            // Same, for feature id.
            return matchesFeatureID(f)
        case (let b?, let f?):
            // And here they both must simultaneously match or be unspecified.
            return matchesBundleID(b) && matchesFeatureID(f)
        }
    }

    // For a filter match, either the filter does not specify a bundle id, or it specifies the same bundle id.
    private func matchesBundleID(_ value: String) -> Bool {
        return self.bundleID == nil || self.bundleID == value
    }

    // For a filter match, either the filter does not specify a feature id, or it specifies a filter id that
    // is the same OR which is a "dotted" prefix of the request's feature id (i.e. prefix ending in the first dot).
    private func matchesFeatureID(_ value: String) -> Bool {
        if self.featureID == nil || self.featureID == value {
            return true
        }
        if let featureID, let i = value.firstIndex(of: ".") {
            return featureID == value.prefix(upTo: i)
        }
        return false
    }

    // For a filter match, either the filter does not specify a workload type, or it specifies the same workload type.
    private func matchesWorkloadType(_ value: String) -> Bool {
        return self.workloadType == nil || self.workloadType == value
    }

    // For a filter match, either the filter does not specify any workload tags, or every tag that it does specify
    // is also identically present in the request.
    private func matchesWorkloadTags(_ value: [String: String]) -> Bool {
        for tag in self.workloadTags {
            if value[tag.key] != tag.value {
                return false
            }
        }
        return true
    }
}

extension RateLimitFilter {
    // This filter matches every request
    static let universalFilter = RateLimitFilter(bundleID: nil, featureID: nil, workloadType: nil, workloadTags: [])
}

// MARK: - RateLimitTimingDetails

// This type is the part of the RateLimitConfig that knows about how
// to actually put limits on requests that match the filter; it's all
// the time information.
struct RateLimitTimingDetails: Sendable, Equatable, Hashable, Codable {
    // This is the rate, count requests per duration
    var count: UInt
    var duration: TimeInterval
    // This is how long the configuration should be in effect,
    // and it could be quite a while, unrelated to duration
    var ttlExpiration: Date
    // When we compute retry, we add some random value within jitter
    var jitter: TimeInterval

    init(now: Date, count: UInt, duration: TimeInterval, ttl: TimeInterval, jitterRatio: Double, config: TC2Configuration) {
        self.count = count
        let duration = min(max(0.0, duration), config[.rateLimiterMaximumRateLimitDuration])
        self.duration = duration
        let ttl = min(max(0.0, ttl), config[.rateLimiterMaximumRateLimitTtl])
        self.ttlExpiration = now + ttl
        let jitterRatio = min(max(0.0, jitterRatio == 0 ? config[.rateLimiterDefaultJitterFactor] : jitterRatio), 1.0)
        self.jitter = jitterRatio * self.duration
    }

    init(now: Date, retryAfter: TimeInterval, config: TC2Configuration) {
        self.init(
            now: now,
            count: 0,
            duration: retryAfter,
            ttl: retryAfter,
            jitterRatio: config[.rateLimiterDefaultJitterFactor],
            config: config)
    }
}

// MARK: - RateLimitConfiguration

// A configuration arises from a combination of the filter and the timing
// details, and we often have to carry them together, so this is basically
// a tuple and that's it.
struct RateLimitConfiguration: Sendable, Equatable, Hashable, Codable {
    var filter: RateLimitFilter
    var timing: RateLimitTimingDetails

    init(filter: RateLimitFilter, timing: RateLimitTimingDetails) {
        self.filter = filter
        self.timing = timing
    }
}

extension RateLimitConfiguration {
    init?(now: Date, proto: Proto_Ropes_RateLimit_RateLimitConfiguration, config: TC2Configuration) {
        // rdar://125117845 (Use new RequestType in rate limit config from server)
        guard proto.requestType == .invoke else {
            return nil
        }

        // The server changed their rate limiting configurations to match how the parameters
        // are being passed to CloudBoard. The old way was a list (key, value), and the new way
        // is a list (key, list (value)), basically grouping by key. We, however, track this
        // routing information the old way, so when the rate limit config comes back we have to
        // ungroup. That's what the flatmap is doing. It's not sensible to change to thie view
        // of list (key, list (value)) model unless everything does in the Thimble framework.
        self.init(
            filter: RateLimitFilter(
                bundleID: proto.bundleID.isEmpty ? nil : proto.bundleID,
                featureID: proto.featureID.isEmpty ? nil : proto.featureID,
                workloadType: proto.workloadType.isEmpty ? nil : proto.workloadType,
                workloadTags: proto.params.flatMap { (key, params) in params.value.map { RateLimitFilter.WorkloadTag(key: key, value: $0) } }),
            timing: RateLimitTimingDetails(
                now: now,
                count: UInt(proto.rate.count),
                duration: proto.rate.duration.timeInterval,
                ttl: proto.ttl.timeInterval,
                jitterRatio: proto.jitter,
                config: config))
    }
}

// MARK: - RateLimitConfigurationSet

// This is how we store rate limit configurations in the rate limiter,
// it's just an association between filters and timing details, but it
// has all the useful operations--finding matches, updating configs,
// expiring old ones, etc.
struct RateLimitConfigurationSet: Sendable, Codable {
    private var configurations: [RateLimitFilter: RateLimitTimingDetails] = [:]
}

extension RateLimitConfigurationSet {
    // This finds configurations that match a request. It's mutating so that
    // it can trim expired configs when they are detected.
    mutating func matching(now: Date, _ requestMetadata: RateLimiterRequestMetadata) -> [RateLimitConfiguration] {
        var sawExpired = false
        defer {
            if sawExpired {
                trimExpired(now: now)
            }
        }

        return self.configurations.compactMap {
            if $0.value.ttlExpiration < now {
                sawExpired = true
                return nil
            } else if $0.key.matches(requestMetadata) {
                return RateLimitConfiguration(filter: $0.key, timing: $0.value)
            } else {
                return nil
            }
        }
    }

    func hasMatching(now: Date, _ requestMetadata: RateLimiterRequestMetadata) -> Bool {
        for configuration in self.configurations where configuration.value.ttlExpiration >= now {
            if configuration.key.matches(requestMetadata) {
                return true
            }
        }
        return false
    }

    mutating func applicableWhen(now: Date, bundleIdentifier: String?, featureIdentifier: String?) -> [RateLimitConfiguration] {
        var sawExpired = false
        defer {
            if sawExpired {
                trimExpired(now: now)
            }
        }

        return self.configurations.compactMap { (key, value) in
            if value.ttlExpiration < now {
                sawExpired = true
                return nil
            } else if key.mightApplyWhen(bundleIdentifier: bundleIdentifier, featureIdentifier: featureIdentifier) {
                return RateLimitConfiguration(filter: key, timing: value)
            } else {
                return nil
            }
        }
    }

    // This adds a RateLimitConfig to the set. Or, updates it if it exists.
    mutating func add(_ rateLimitConfiguration: RateLimitConfiguration) {
        self.configurations[rateLimitConfiguration.filter] = rateLimitConfiguration.timing
    }

    mutating func trimExpired(now: Date) {
        self.configurations = self.configurations.compactMapValues {
            ($0.ttlExpiration < now) ? nil : $0
        }
    }
}
