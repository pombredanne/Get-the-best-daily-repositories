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

// Copyright © 2024 Apple. All rights reserved.

import CloudBoardLogging
import CloudBoardMetrics

private let prefix = CloudBoardJobHelper.metricsClientName

extension HistogramBuckets {
    fileprivate static let chunkSize: HistogramBuckets = [
        1,
        2,
        4,
        8,
        16,
        32,
        64,
        128,
        256,
        512,
        1024, // KiB
        1536,
        2048,
        2560,
        3072,
        3584,
        4096,
        8192,
        16384,
        32768,
        65536,
        131_072,
        262_144,
        524_288,
        1_048_576, // MiB
        536_870_912,
        1_073_741_824, // GiB
    ]

    // should be the same as that of CloudboardDCore requestTime metric
    fileprivate static let requestTime: Self = [
        0.005524,
        0.007812,
        0.011049,
        0.015625,
        0.022097,
        0.03125,
        0.044194,
        0.0625,
        0.088388,
        0.125,
        0.176777,
        0.25,
        0.353553,
        0.5,
        0.707107,
        1.0,
        1.414214,
        1.681793,
        2.0,
        2.181015,
        2.378414,
        2.593679,
        2.828427,
        2.953652,
        3.084422,
        3.220981,
        3.363586,
        3.512504,
        3.668016,
        3.830413,
        4.0,
        4.177095,
        4.362031,
        4.555155,
        4.756828,
        4.967431,
        5.187358,
        5.417022,
        5.656854,
        5.907305,
        6.168843,
        6.441961,
        6.727171,
        7.025009,
        7.336032,
        7.660826,
        8.0,
        8.35419,
        8.724062,
        9.110309,
        9.513657,
        9.934862,
        10.374716,
        11.313708,
        12.337687,
        13.454343,
        14.672065,
        16.0,
        22.627417,
        32.0,
        45.254834,
        64.0,
        90.509668,
        128.0,
        181.019336,
        256.0,
        362.038672,
    ]
}

enum Metrics {
    enum Daemon {
        struct LaunchCounter: Counter {
            static let label: MetricLabel = "\(prefix)_daemon_launch_total"
            var action: CounterAction
        }

        struct UptimeGauge: Gauge {
            static let label: MetricLabel = "\(prefix)_daemon_uptime"
            var value: Int
        }

        struct ErrorExitCounter: Counter {
            static let label: MetricLabel = "\(prefix)_daemon_exit_error"
            var action: CounterAction
        }

        struct TotalExitCounter: Counter {
            static let label: MetricLabel = "\(prefix)_daemon_exit_total"
            var action: CounterAction
        }
    }

    enum Messenger {
        struct TotalRequestsReceivedCounter: Counter {
            static let label: MetricLabel = "\(prefix)_messenger_requests_received_total"
            var action: CounterAction
        }

        struct RequestChunkReceivedSizeHistogram: Histogram {
            static let label: MetricLabel = "\(prefix)_messenger_request_chunk_received_size_bytes"
            static var buckets: HistogramBuckets = .chunkSize
            var value: Int
        }

        struct TotalResponseChunksReceivedCounter: Counter {
            static let label: MetricLabel = "\(prefix)_messenger_response_chunks_received_total"
            var action: CounterAction
        }

        struct TotalResponseChunksSentCounter: Counter {
            static let label: MetricLabel = "\(prefix)_messenger_response_chunks_sent_total"
            var action: CounterAction
        }

        struct TotalResponseChunksInBuffer: Gauge {
            static let label: MetricLabel = "\(prefix)_messenger_response_chunks_in_buffer_total"
            var value: Int
        }

        struct TotalResponseChunkReceivedSizeHistogram: Histogram {
            static let label: MetricLabel = "\(prefix)_messenger_response_chunk_received_size_bytes"
            static var buckets: HistogramBuckets = .chunkSize
            var value: Int
        }

        struct TotalResponseChunksBufferedSizeHistogram: Histogram {
            static let label: MetricLabel = "\(prefix)_messenger_response_chunk_buffered_size_bytes"
            static var buckets: HistogramBuckets = .chunkSize
            var value: Int
        }

        struct OverallErrorCounter: ErrorCounter {
            static let label: MetricLabel = "\(prefix)_messenger_error"
            var dimensions: MetricDimensions<DefaultErrorDimensionKeys>
            var action: CounterAction
        }
    }

    enum WorkloadManager {
        struct TotalRequestsReceivedCounter: Counter {
            static let label: MetricLabel = "\(prefix)_workload_manager_requests_received_total"
            var action: CounterAction
        }

        struct TotalResponsesSentCounter: Counter {
            static let label: MetricLabel = "\(prefix)_workload_manager_responses_sent_total"
            var action: CounterAction
        }

        struct SuccessResponsesSentCounter: Counter {
            static let label: MetricLabel = "\(prefix)_workload_manager_responses_sent_success"
            var action: CounterAction
        }

        struct FailureResponsesSentCounter: ErrorCounter {
            static let label: MetricLabel = "\(prefix)_workload_manager_responses_sent_failure"
            var dimensions: MetricDimensions<DefaultErrorDimensionKeys>
            var action: CounterAction
        }

        struct TGTValidationCounter: Counter {
            static let label: MetricLabel = "\(prefix)_tgt_validation_total"
            var action: CounterAction
        }

        struct TGTValidationErrorCounter: ErrorCounter {
            static let label: MetricLabel = "\(prefix)_tgt_validation_error_total"
            var dimensions: MetricDimensions<DefaultErrorDimensionKeys>
            var action: CounterAction
        }

        struct OverallErrorCounter: ErrorCounter {
            static let label: MetricLabel = "\(prefix)_workload_manager_error"
            var dimensions: MetricDimensions<DefaultErrorDimensionKeys>
            var action: CounterAction
        }

        /// How many times workloadmanager finished without processing any request messages
        struct UnusedTerminationCounter: Counter {
            static let label: MetricLabel = "\(prefix)_workload_manager_unused_termination_total"
            var action: CounterAction
        }

        struct WorkloadDurationFromFirstRequestMessage: Histogram {
            static let label: MetricLabel = "\(prefix)_workload_manager_duration_from_first_request_seconds"
            static let buckets: HistogramBuckets = .requestTime
            var dimensions: MetricDimensions<DimensionKey>
            var value: Double

            enum DimensionKey: String, RawRepresentable {
                case result
                case errorDescription
            }

            init(duration: Duration, error: Error?) {
                self.value = Double(duration.microsecondsClamped) / 1_000_000
                if let error {
                    self.dimensions = [
                        .result: "error",
                        .errorDescription: String(reportable: error),
                    ]
                } else {
                    self.dimensions = [
                        .result: "success",
                    ]
                }
            }
        }
    }

    enum Workload {
        struct OverallErrorCounter: ErrorCounter {
            static let label: MetricLabel = "\(prefix)_workload_error"
            var dimensions: MetricDimensions<DefaultErrorDimensionKeys>
            var action: CounterAction
        }

        struct CloudAppExitCounter: ExitCounter {
            static let label: MetricLabel = "\(prefix)_cloudapp_process_exit"
            var dimensions: MetricDimensions<DefaultExitDimensionKeys>
            var action: CounterAction
        }
    }

    enum CloudAppRequestStream {
        struct OverallErrorCounter: ErrorCounter {
            static let label: MetricLabel = "\(prefix)_cloud_app_request_stream_error"
            var dimensions: MetricDimensions<DefaultErrorDimensionKeys>
            var action: CounterAction
        }
    }
}
