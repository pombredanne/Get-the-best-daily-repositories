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
import Virtualization
import Virtualization_Private

private let defaultBootArgs = "debug=0x014e serial=0xb" // nvram "boot-args" if none specified during create

extension VM {
    // VM.Config is our in-core representation of a Virtual Machine (ideally would use the
    //  VZVirtualMachineConfiguration serializer, but it's not a stable interface)
    struct Config {
        var bundle: VMBundle // pointers to files in the VM folder
        let platformType: PlatformType // vresearch101
        let platformFusing: VM.PlatformFusing?
        var cpuCount: UInt
        var memorySize: UInt64
        var networkConfig: NetworkConfig
        var nvramArgs: [String: String] // nvram parameters (user-provided or loaded from auxStorage)
        var romImages: ROMImages? // iBoot and vSEP -- usu empty to use those in the VZ framework
        var machineIDBlob: Data? // opaque represenation of ECID

        var ecid: UInt64 {
            if let vmConfig = try? vzConfig(),
               let pconf = vmConfig.platform as? VZMacPlatformConfiguration
            {
                return pconf.machineIdentifier._ECID
            }

            return 0
        }

        // init instanciates a (new) VM from parameters
        init(
            bundle: VMBundle,
            platformType: PlatformType = .vresearch101,
            platformFusing: VM.PlatformFusing?,
            machineIDBlob: Data? = nil,
            cpuCount: UInt,
            memorySize: UInt64,
            networkConfig: NetworkConfig = NetworkConfig(mode: .none),
            nvramArgs: [String: String]? = nil,
            romImages: ROMImages? = nil
        ) {
            self.bundle = bundle
            self.platformType = platformType
            self.platformFusing = platformFusing
            if let machineIDBlob {
                self.machineIDBlob = machineIDBlob
            }

            self.cpuCount = cpuCount
            self.memorySize = memorySize
            self.networkConfig = networkConfig
            self.nvramArgs = nvramArgs ?? [:]
            self.romImages = romImages
        }

        // init instanciates a (new) VM from saved bundle (containing config)
        init(fromBundle bundle: VMBundle) throws {
            guard let bundleConfig = bundle.config else {
                throw VMError("bundle configuration not loaded")
            }

            var nvramArgs: [String: String]?
            do {
                // load nvram values from auxStorage
                let nvram = try VM.NVRAM(auxStorageURL: bundle.auxiliaryStoragePath)
                nvramArgs = try? nvram.allValues()
            } catch {
                // may not be available (esp during restore operation) -- log & fall through
                VM.logger.error("unable to load nvram settings: \(error, privacy: .public)")
            }

            self.init(
                bundle: bundle,
                platformFusing: bundleConfig.platformFusing,
                machineIDBlob: bundleConfig.machineIdentifier,
                cpuCount: bundleConfig.cpuCount,
                memorySize: bundleConfig.memorySize,
                networkConfig: NetworkConfig(bundleConfig.networkConfig),
                nvramArgs: nvramArgs,
                romImages: bundleConfig.romImages
            )
        }

        // writeBundleConfig encapsulates the VM configuration within a VMBundle and saves it
        func writeBundleConfig() throws {
            do {
                try VMBundle.Config(
                    vmConfig: vzConfig(),
                    platformType: platformType,
                    platformFusing: platformFusing,
                    romImages: romImages
                ).write(to: bundle.configPath)

                // write nvram args back to auxStorage
                try applyNVRAMArgs()
            } catch {
                throw VMError("VM bundle: \(error)")
            }
        }

        // applyNVRAMArgs applies nvramArgs dictionary to auxiliary storage
        func applyNVRAMArgs() throws {
            if nvramArgs.isEmpty {
                return
            }

            let nvram = try VM.NVRAM(auxStorageURL: bundle.auxiliaryStoragePath)
            for (k, v) in nvramArgs {
                try nvram.set(k, value: v)
            }
        }

        // vzConfig derives a VZVirtualMachineConfiguration from our configuration bundle
        func vzConfig(
            consoleInput: FileHandle? = FileHandle.standardInput,
            consoleOutput: FileHandle? = FileHandle.standardOutput
        ) throws -> VZVirtualMachineConfiguration {
            let auxStorage: VZMacAuxiliaryStorage
            do {
                if FileManager.isRegularFile(bundle.auxiliaryStoragePath) {
                    auxStorage = VZMacAuxiliaryStorage(url: bundle.auxiliaryStoragePath)
                } else {
                    auxStorage = try vzCreateAuxStorage(bundle: bundle, platformType: platformType)
                    try auxStorage._setValue(defaultBootArgs, forNVRAMVariableNamed: "boot-args")
                }
            } catch {
                throw VMError("\(bundle.auxiliaryStoragePath.path): \(error)")
            }

            // initial VM configuration for platformType
            let avpsepbooter: URL? = if let img = romImages?.avpsepbooter { bundle.qualifyPath(img) } else { nil }
            let config: VZVirtualMachineConfiguration
            do {
                config = try vzMachineConfig(
                    bundle: bundle,
                    platformType: platformType,
                    platformFusing: validatedPlatformFusing(),
                    machineIDBlob: machineIDBlob,
                    avpsepbooter: avpsepbooter
                )
            } catch {
                throw VMError("create VM configuration: \(error)")
            }

            let bootloader_config = VZMacOSBootLoader()
            if let avpbooter = romImages?.avpbooter {
                // default AVPBooter.vresearch1.bin from VZ framework
                bootloader_config._romURL = bundle.qualifyPath(avpbooter)
            }
            config.bootLoader = bootloader_config

            do {
                let storage_attachment = try VZDiskImageStorageDeviceAttachment(
                    url: bundle.diskStoragePath,
                    readOnly: false
                )
                let storage_dev = VZVirtioBlockDeviceConfiguration(attachment: storage_attachment)
                config.storageDevices = [storage_dev]
            } catch {
                throw VMError("VM storage attachment: \(error)")
            }

            var cpuCount = max(cpuCount, UInt(VZVirtualMachineConfiguration.minimumAllowedCPUCount))
            cpuCount = min(cpuCount, UInt(VZVirtualMachineConfiguration.maximumAllowedCPUCount))
            cpuCount = min(cpuCount, UInt(ProcessInfo.processInfo.processorCount))
            config.cpuCount = Int(cpuCount)

            config.memorySize = max(memorySize, VZVirtualMachineConfiguration.minimumAllowedMemorySize)
            config.memorySize = min(config.memorySize, VZVirtualMachineConfiguration.maximumAllowedMemorySize)

            config.networkDevices = [vzNetworkConfig(config: networkConfig)]
            config.serialPorts = [vzSerialPort(input: consoleInput, output: consoleOutput)]

            // DEBUG: VM.vzDumpConfig(config)

            config._debugStub = _VZGDBDebugStubConfiguration()

            do {
                try config.validate()
            } catch {
                throw VMError("validate VZ configuration: \(error)")
            }

            return config
        }

        // vzCreateAuxStorage creates an empty file to contain nvram state (for the VM platform type)
        func vzCreateAuxStorage(bundle: VMBundle, platformType: PlatformType) throws -> VZMacAuxiliaryStorage {
            return try bundle.createAuxStorage(hwModel: vzHardwareModel(platformType: platformType))
        }

        // validatedPlatformFusing masks VM "fusing" to host OS type
        func validatedPlatformFusing() -> VM.PlatformFusing {
            if os_variant_allows_internal_security_policies(applicationName) {
                return platformFusing ?? .dev
            } else {
                return .prod
            }
        }

        // vzMachineConfig derives the VZVirtualMachineConfiguration platform config specific to
        //  the "platform type" of the VM (currently only vresearch101 supported)
        private func vzMachineConfig(
            bundle: VMBundle,
            platformType: PlatformType,
            platformFusing: VM.PlatformFusing,
            machineIDBlob: Data? = nil,
            avpsepbooter: URL? = nil
        ) throws -> VZVirtualMachineConfiguration {
            let config: VZVirtualMachineConfiguration = .init()

            let pconf = VZMacPlatformConfiguration()
            pconf.hardwareModel = try vzHardwareModel(platformType: platformType)
            if let machineIDBlob {
                guard let machineID = VZMacMachineIdentifier(dataRepresentation: machineIDBlob) else {
                    throw VMError("invalid VM platform info (machine id)")
                }

                pconf.machineIdentifier = machineID
            }

            switch platformType {
            case .vresearch101:
                let sep_config = _VZSEPCoprocessorConfiguration(storageURL: bundle.sepStoragePath)
                if let avpsepbooter { // default AVPSEPBooter.vresearch1.bin from VZ framework
                    sep_config.romBinaryURL = avpsepbooter
                }
                sep_config.debugStub = _VZGDBDebugStubConfiguration()
                config._coprocessors = [sep_config]

                pconf._isProductionModeEnabled = (platformFusing == .prod)

                let graphics_config = VZMacGraphicsDeviceConfiguration()
                let displays_config = VZMacGraphicsDisplayConfiguration(
                    widthInPixels: 1290,
                    heightInPixels: 2796,
                    pixelsPerInch: 460
                )
                graphics_config.displays.append(displays_config)
                config.graphicsDevices = [graphics_config]

            default:
                throw VMError("unsupported VM platform type (\(platformType.rawValue)")
            }

            pconf.auxiliaryStorage = VZMacAuxiliaryStorage(url: bundle.auxiliaryStoragePath)
            config.platform = pconf

            return config
        }

        // vzHardwareModel derives the VZMacHardwareModel config specific to the "platform type"
        //  of the VM (currently only vresearch101 supported)
        private func vzHardwareModel(platformType: PlatformType) throws -> VZMacHardwareModel {
            var hw_model: VZMacHardwareModel
            switch platformType {
            case .vresearch101:
                let hw_descriptor = _VZMacHardwareModelDescriptor()
                hw_descriptor.setPlatformVersion(3)
                hw_descriptor.setISA(.appleInternal4)
                hw_model = VZMacHardwareModel._hardwareModel(with: hw_descriptor)

            default:
                throw VMError("unsupported VM platform type (\(platformType.rawValue)")
            }

            guard hw_model.isSupported else {
                throw VMError("VM hardware config not supported (model.isSupported = false)")
            }

            return hw_model
        }

        // vzNetworkConfig derives the VZVirtioNetworkDeviceConfiguration settings for the selected
        //   NetworkConfig (NAT or bridged mode)
        func vzNetworkConfig(config: NetworkConfig) -> VZVirtioNetworkDeviceConfiguration {
            let network_config = VZVirtioNetworkDeviceConfiguration()
            switch config.mode {
            case .nat:
                network_config.attachment = VZNATNetworkDeviceAttachment()

            case .bridged:
                if let bridgedIf = config.bridgeIf {
                    network_config.attachment = VZBridgedNetworkDeviceAttachment(interface: bridgedIf)
                } else if let bridgedIf = VZBridgedNetworkInterface.networkInterfaces.first {
                    network_config.attachment = VZBridgedNetworkDeviceAttachment(interface: bridgedIf)
                } else {
                    VM.logger.error("no matching bridge network interface found")
                }

            default:
                break
            }

            if let macAddr = config.macAddr {
                network_config.macAddress = macAddr
            } else {
                network_config.macAddress = VZMACAddress.randomLocallyAdministered()
            }

            return network_config
        }

        // vzSerialPort adds VZSerialPortConfiguration attachment to input/output FileHandles (def stdio)
        func vzSerialPort(
            input: FileHandle? = FileHandle.standardInput,
            output: FileHandle? = FileHandle.standardOutput
        ) -> VZSerialPortConfiguration {
            let console_config: VZSerialPortConfiguration = _VZPL011SerialPortConfiguration()
            let console_attachment = VZFileHandleSerialPortAttachment(
                fileHandleForReading: input,
                fileHandleForWriting: output
            )
            console_config.attachment = console_attachment
            return console_config
        }
    }

    // vzDumpConfig outputs the VZVirtualMachineConfiguration (for debugging purposes)
    static func vzDumpConfig(_ config: VZVirtualMachineConfiguration) {
        do {
            let encoded = try _VZVirtualMachineConfigurationEncoder(baseURL: FileManager.fileURL("/"))
                .data(with: config, format: PropertyListSerialization.PropertyListFormat.xml)

            VM.logger.debug("VM Configuration:\n\(String(decoding: encoded, as: UTF8.self), privacy: .public)\n")
        } catch {
            VM.logger.error("dump config: \(error, privacy: .public)")
        }
    }
}
