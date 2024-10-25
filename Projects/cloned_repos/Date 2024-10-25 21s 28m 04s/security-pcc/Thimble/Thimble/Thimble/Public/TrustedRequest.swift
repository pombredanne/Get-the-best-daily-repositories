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
//  TrustedRequest.swift
//  PrivateCloudCompute
//
//  Copyright © 2024 Apple Inc. All rights reserved.
//

private import AtomicsInternal
import Foundation

/// A struct representing a single trusted cloud compute request.
public struct TrustedRequest: Sendable {
    /// A struct used for writing data for a trusted request.
    public struct Writer: Sendable {
        // The underlying trusted request.
        private let xpcRequestProxy: XPCRequestProxy
        private let jsonDecoder = JSONDecoder()

        init(xpcRequest: XPCRequestProxy) {
            self.xpcRequestProxy = xpcRequest
        }

        /// Writes the contents of the sequence to the request.
        ///
        /// This method will suspend if no more data can be written due to back pressure. Once, more
        /// flow control has opened up the method will resume and allow more data to be written.
        ///
        /// - Parameter contentsOf: The sequence of data to write to the request.
        public func write(contentsOf sequence: some Sequence<UInt8>) async throws {
            try await self.write(data: Data(sequence))
        }

        /// Writes the contents of the data to the request.
        ///
        /// This method will suspend if no more data can be written due to back pressure. Once, more
        /// flow control has opened up the method will resume and allow more data to be written.
        ///
        /// - Parameter data: The data to write to the request.
        public func write(data: Data) async throws {
            try await withTaskCancellationHandler {
                return try await self.xpcRequestProxy.send(data: data, isComplete: true)
            } onCancel: {
                self.xpcRequestProxy.cancel()
            }
        }

        /// Writes the contents of the asynchronous sequence to the request.
        ///
        /// This method will run until the passed asynchronous sequence has finished.
        ///
        /// - Parameter contentsOf: The asynchronous sequence of data to write to the request.
        public func write<AS: AsyncSequence>(contentsOf sequence: AS) async throws where AS.Element == Data {
            try await withTaskCancellationHandler {
                do {
                    for try await element in sequence {
                        try await self.xpcRequestProxy.send(data: element, isComplete: false)
                    }
                    try await self.xpcRequestProxy.send(data: Data(), isComplete: true)
                } catch {
                    // if the provided AsyncSequence threw, we must cancel the request, then
                    // rethrow the error
                    self.xpcRequestProxy.cancel()
                    throw error
                }
            } onCancel: {
                self.xpcRequestProxy.cancel()
            }
        }
    }

    /// A struct representing the returned data for a ``TrustedRequest``.
    public struct Response: AsyncSequence {
        public typealias Element = Data

        // The underlying trusted request.
        private let xpcRequest: XPCRequestProxy
        private let madeAsyncIteratorAtomic = ManagedAtomic(false)

        init(xpcRequest: XPCRequestProxy) {
            self.xpcRequest = xpcRequest
        }

        public func makeAsyncIterator() -> AsyncIterator {
            guard !self.madeAsyncIteratorAtomic.compareExchange(expected: false, desired: true, ordering: .acquiringAndReleasing).original else {
                fatalError(
                    """
                    Bug in PrivateCloudCompute adopter code!

                    TrustedRequest.Reponse can only create a single AsyncIterator. Creating multiple
                    AsyncIterators would lead to undefined behavior when iterating the iterators in
                    parallel and is therefore forbidden.
                    """
                )
            }
            return AsyncIterator(xpcRequest: self.xpcRequest)
        }

        public struct AsyncIterator: AsyncIteratorProtocol {
            private var xpcRequest: XPCRequestProxy
            private let jsonDecoder = JSONDecoder()
            private let concurrentNextCallsAtomic = ManagedAtomic(false)

            fileprivate init(xpcRequest: XPCRequestProxy) {
                self.xpcRequest = xpcRequest
            }

            public mutating func next() async throws -> Data? {
                guard !self.concurrentNextCallsAtomic.compareExchange(expected: false, desired: true, ordering: .acquiringAndReleasing).original else {
                    fatalError(
                        """
                        Bug in PrivateCloudCompute adopter code!

                        TrustedRequest.Reponse.AsyncIterator is not Sendable and therefore must not
                        be invoked concurrently.
                        """
                    )
                }
                defer {
                    let changed = self.concurrentNextCallsAtomic.compareExchange(expected: true, desired: false, ordering: .acquiringAndReleasing)
                    precondition(changed.original)
                }
                return try await withTaskCancellationHandler {
                    try await self.xpcRequest.next()
                } onCancel: { [xpcRequest] in
                    xpcRequest.cancel()
                }
            }
        }
    }

    /// The request's ID. Note this should not be sent to the server. It is the local
    /// identity for the request (i.e., the caller's notion, currently GMS).
    public var id: UUID
    /// The request's workload type.
    public var workloadType: String
    /// The requests workload parameters.
    public var workloadParameters: [String: String]?

    /// Optional bundle identifier to override the one automatically determined. Can only be passed if you have an entitlement.
    public var bundleIdentifier: String?

    /// Optional bundle identifier that specifies which app contained the interaction that led to the inference request, which is potentially different from the bundleIdentifier that is driving the inference request.
    public var originatingBundleIdentifier: String?

    /// Optional feature identifier used for rate limiting and analytics.
    public var featureIdentifier: String?

    /// Optional session identifier used for rate limiting and analytics.
    public var sessionIdentifier: UUID?

    /// Creates a new ``TrustedRequest``.
    /// - Parameters:
    ///   - id: The request's ID. Defaults to a newly generated one.
    ///   - workloadType: The request's workload type.
    ///   - workloadParameters: The request's workload parameters.
    ///   - featureIdentifier: The request's feature ID.
    ///   - sessionIdentifier: The request's session ID.
    ///   - bundleIdentifierOverride: An override for the originating bundle ID.
    ///   - originatingBundleIdentifier: The bundleID that hosted the root interaction.
    public init(
        id: UUID = .init(),
        workloadType: String,
        workloadParameters: [String: String],
        featureIdentifier: String,
        sessionIdentifier: UUID,
        bundleIdentifierOverride: String? = nil,
        originatingBundleIdentifier: String? = nil
    ) {
        self.id = id
        self.workloadType = workloadType
        self.workloadParameters = workloadParameters
        self.bundleIdentifier = bundleIdentifierOverride
        self.featureIdentifier = featureIdentifier
        self.sessionIdentifier = sessionIdentifier
        self.originatingBundleIdentifier = originatingBundleIdentifier
    }

    // This is internal, becase we don't want the public interface to expose the
    // optional nature of some of these fields. Everyone should provide a feature id,
    // session id, etc. At the same time we store them as optional and there is
    // a pretty long thread to unravel here (including the public properties, that
    // are optional).
    package init(
        id: UUID = .init(),
        workloadType: String,
        workloadParameters: [String: String]?,
        bundleIdentifier: String?,
        featureIdentifier: String?,
        sessionIdentifier: UUID?
    ) {
        self.id = id
        self.workloadType = workloadType
        self.workloadParameters = workloadParameters
        self.bundleIdentifier = bundleIdentifier
        self.featureIdentifier = featureIdentifier
        self.sessionIdentifier = sessionIdentifier
    }
}
