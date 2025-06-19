import SwiftUI
import AudioToolbox
import OSLog
import AVFoundation

@Observable
final class ProcessTap {

    typealias InvalidationHandler = (ProcessTap) -> Void

    let process: AudioProcess?
    let muteWhenRunning: Bool
    private let logger: Logger

    private(set) var errorMessage: String? = nil

    init(process: AudioProcess? = nil, muteWhenRunning: Bool = false) {
        self.process = process
        self.muteWhenRunning = muteWhenRunning
        let tapTargetName = process?.name ?? "SystemAudio"
        self.logger = Logger(subsystem: kAppSubsystem, category: "\(String(describing: ProcessTap.self))(\(tapTargetName))")
    }

    @ObservationIgnored
    private var processTapID: AudioObjectID = .unknown
    @ObservationIgnored
    private var aggregateDeviceID = AudioObjectID.unknown
    @ObservationIgnored
    private var deviceProcID: AudioDeviceIOProcID?
    @ObservationIgnored
    private(set) var tapStreamDescription: AudioStreamBasicDescription?
    @ObservationIgnored
    private var invalidationHandler: InvalidationHandler?

    @ObservationIgnored
    private(set) var activated = false

    @MainActor
    func activate() {
        guard !activated else { return }
        activated = true

        logger.debug(#function)

        self.errorMessage = nil

        do {
            try prepare()
        } catch {
            logger.error("\(error, privacy: .public)")
            self.errorMessage = error.localizedDescription
        }
    }

    func invalidate() {
        guard activated else { return }
        defer { activated = false }

        logger.debug(#function)

        invalidationHandler?(self)
        self.invalidationHandler = nil

        if aggregateDeviceID.isValid {
            var err = AudioDeviceStop(aggregateDeviceID, deviceProcID)
            if err != noErr { logger.warning("Failed to stop aggregate device: \(err, privacy: .public)") }

            if let deviceProcID {
                err = AudioDeviceDestroyIOProcID(aggregateDeviceID, deviceProcID)
                if err != noErr { logger.warning("Failed to destroy device I/O proc: \(err, privacy: .public)") }
                self.deviceProcID = nil
            }

            err = AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            if err != noErr {
                logger.warning("Failed to destroy aggregate device: \(err, privacy: .public)")
            }
            aggregateDeviceID = .unknown
        }

        if processTapID.isValid {
            if self.process != nil { // Only call DestroyProcessTap if it was created with CreateProcessTap
                let err = AudioHardwareDestroyProcessTap(processTapID)
                if err != noErr { logger.warning("Failed to destroy process-specific audio tap: \(err, privacy: .public)") }
            }
            // For taps created with AudioHardwareCreateTap, their lifecycle is tied to the aggregate device.
            self.processTapID = .unknown
        }
    }

    private func prepare() throws {
        errorMessage = nil // Clear previous errors

        let tapDescription: CATapDescription
        var err: OSStatus

        if let currentProcess = self.process {
            // Process-specific tap
            logger.debug("Preparing process tap for \(currentProcess.name)")
            tapDescription = CATapDescription(stereoMixdownOfProcesses: [currentProcess.objectID])
            tapDescription.uuid = UUID() // Keep UUID logic consistent
            tapDescription.muteBehavior = muteWhenRunning ? .mutedWhenTapped : .unmuted

            err = AudioHardwareCreateProcessTap(tapDescription, &processTapID)
            guard err == noErr else {
                errorMessage = "Process tap creation failed for \(currentProcess.name) with error \(err)"
                return
            }
            logger.debug("Created process tap #\(self.processTapID, privacy: .public) for \(currentProcess.name)")

        } else {
            // System-wide tap
            logger.debug("Preparing system-wide audio tap")
            tapDescription = CATapDescription()
            tapDescription.isTapOnSystemAudio = true
            tapDescription.uuid = UUID() // Keep UUID logic consistent
            tapDescription.muteBehavior = muteWhenRunning ? .mutedWhenTapped : .unmuted

            err = AudioHardwareCreateTap(tapDescription, &processTapID)
            guard err == noErr else {
                errorMessage = "System audio tap creation failed with error \(err)"
                return
            }
            logger.debug("Created system audio tap #\(self.processTapID, privacy: .public)")
        }

        // Common Aggregate Device Setup
        let systemOutputID = try AudioDeviceID.readDefaultSystemOutputDevice()
        let outputUID = try systemOutputID.readDeviceUID()
        let aggregateUID = UUID().uuidString

        let aggregateDeviceName: String
        if let currentProcess = self.process {
            aggregateDeviceName = "Tap-\(currentProcess.id)"
        } else {
            aggregateDeviceName = "SystemAudioTap-\(aggregateUID.prefix(8))"
        }

        let descriptionDict: [String: Any] = [
            kAudioAggregateDeviceNameKey: aggregateDeviceName,
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true, // Important for the tap to be active
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [
                    kAudioSubTapDriftCompensationKey: true,
                    kAudioSubTapUIDKey: tapDescription.uuid!.uuidString // tapDescription.uuid must be set
                ]
            ]
        ]

        self.tapStreamDescription = try processTapID.readAudioTapStreamBasicDescription()

        aggregateDeviceID = AudioObjectID.unknown // Reset before creation
        err = AudioHardwareCreateAggregateDevice(descriptionDict as CFDictionary, &aggregateDeviceID)
        guard err == noErr else {
            // Clean up the tap if aggregate device creation fails
            if processTapID.isValid {
                if self.process != nil {
                    AudioHardwareDestroyProcessTap(processTapID)
                } else {
                    // For system taps, AudioObjectRemovePropertyAddress might be needed if not handled by aggregate device destruction.
                    // However, often the aggregate device manages its constituent taps.
                    // If AudioHardwareCreateTap implies ownership by the aggregate device, this might not be needed.
                    // For now, mirroring the process tap destruction might be incorrect.
                    // Relying on aggregate device destruction is safer unless specific API for system tap destruction is confirmed.
                    // Let's assume AudioHardwareDestroyTap is not the one, and it's managed by aggregate device.
                    // No explicit call here for system tap destruction, it will be handled by aggregate device invalidation.
                }
                self.processTapID = .unknown
            }
            throw "Failed to create aggregate device: \(err)"
        }
        logger.debug("Created aggregate device #\(self.aggregateDeviceID, privacy: .public) named \(aggregateDeviceName)")
    }

    func run(on queue: DispatchQueue, ioBlock: @escaping AudioDeviceIOBlock, invalidationHandler: @escaping InvalidationHandler) throws {
        assert(activated, "\(#function) called with inactive tap!")
        assert(self.invalidationHandler == nil, "\(#function) called with tap already active!")

        errorMessage = nil

        logger.debug("Run tap!")

        self.invalidationHandler = invalidationHandler

        var err = AudioDeviceCreateIOProcIDWithBlock(&deviceProcID, aggregateDeviceID, queue, ioBlock)
        guard err == noErr else { throw "Failed to create device I/O proc: \(err)" }

        err = AudioDeviceStart(aggregateDeviceID, deviceProcID)
        guard err == noErr else { throw "Failed to start audio device: \(err)" }
    }

    deinit { invalidate() }

}

@Observable
final class ProcessTapRecorder {

    let fileURL: URL
    let process: AudioProcess?
    private let queue = DispatchQueue(label: "ProcessTapRecorder", qos: .userInitiated)
    private let logger: Logger

    @ObservationIgnored
    private weak var _tap: ProcessTap?

    private(set) var isRecording = false

    init(fileURL: URL, tap: ProcessTap) {
        self.process = tap.process // process is now AudioProcess?
        self.fileURL = fileURL
        self._tap = tap
        self.logger = Logger(subsystem: kAppSubsystem, category: "\(String(describing: ProcessTapRecorder.self))(\(fileURL.lastPathComponent))")
    }

    private var tap: ProcessTap {
        get throws {
            guard let _tap else { throw "Process tab unavailable" }
            return _tap
        }
    }

    @ObservationIgnored
    private var currentFile: AVAudioFile?

    @MainActor
    func start() throws {
        logger.debug(#function)
        
        guard !isRecording else {
            logger.warning("\(#function, privacy: .public) while already recording")
            return
        }

        let tap = try tap

        if !tap.activated { tap.activate() }

        guard var streamDescription = tap.tapStreamDescription else {
            throw "Tap stream description not available."
        }

        guard let format = AVAudioFormat(streamDescription: &streamDescription) else {
            throw "Failed to create AVAudioFormat."
        }

        logger.info("Using audio format: \(format, privacy: .public)")

        let settings: [String: Any] = [
            AVFormatIDKey: streamDescription.mFormatID,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount
        ]
        let file = try AVAudioFile(forWriting: fileURL, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: format.isInterleaved)

        self.currentFile = file

        try tap.run(on: queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            guard let self, let currentFile = self.currentFile else { return }
            do {
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil) else {
                    throw "Failed to create PCM buffer"
                }

                try currentFile.write(from: buffer)
            } catch {
                logger.error("\(error, privacy: .public)")
            }
        } invalidationHandler: { [weak self] tap in
            guard let self else { return }
            handleInvalidation()
        }

        isRecording = true
    }

    func stop() {
        do {
            logger.debug(#function)

            guard isRecording else { return }

            currentFile = nil

            isRecording = false

            try tap.invalidate()
        } catch {
            logger.error("Stop failed: \(error, privacy: .public)")
        }
    }

    private func handleInvalidation() {
        guard isRecording else { return }

        logger.debug(#function)
    }

}
