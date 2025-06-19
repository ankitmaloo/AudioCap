import SwiftUI
import AudioToolbox
import OSLog
import Combine

struct AudioProcess: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case process
        case app
    }
    var id: pid_t
    var kind: Kind
    var name: String
    var audioActive: Bool
    var bundleID: String?
    var bundleURL: URL?
    var objectID: AudioObjectID
}

struct AudioProcessGroup: Identifiable, Hashable, Sendable {
    var id: String
    var title: String
    var processes: [AudioProcess]
}

extension AudioProcess.Kind {
    var defaultIcon: NSImage {
        switch self {
        case .process: NSWorkspace.shared.icon(for: .unixExecutable)
        case .app: NSWorkspace.shared.icon(for: .applicationBundle)
        }
    }
}

extension AudioProcess {
    var icon: NSImage {
        guard let bundleURL else { return kind.defaultIcon }
        let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
        image.size = NSSize(width: 32, height: 32)
        return image
    }
}

extension String: @retroactive LocalizedError {
    public var errorDescription: String? { self }
}

@MainActor
@Observable
final class AudioProcessController {

    private let logger = Logger(subsystem: "AudioCap", category: String(describing: AudioProcessController.self))

    private(set) var activeProcess: AudioProcess?
    
    // --- CHANGE 1: Add a property to track recording state ---
    /// The view will set this to true when a recording starts.
    var isRecording = false
    
    private var cancellables = Set<AnyCancellable>()

    func activate() {
        // ... (this function is unchanged)
        logger.debug(#function)

        let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect().map { _ in }
        let appPublisher = NSWorkspace.shared.publisher(for: \.runningApplications).map { _ in }

        Publishers.Merge(timer, appPublisher)
            .debounce(for: .seconds(0.2), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.reload()
            }
            .store(in: &cancellables)
    }
    
    private func reload() {
        // --- CHANGE 2: Add a guard to prevent reloading during recording ---
        // If a recording is in progress, we exit immediately to avoid
        // invalidating the current process and tap.
        guard !isRecording else {
            logger.debug("Reload skipped: Recording in progress.")
            return
        }

        logger.debug(#function)
        
        do {
            let runningApps = NSWorkspace.shared.runningApplications.filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            let objectIdentifiers = try AudioObjectID.readProcessList()

            let activeProcesses: [AudioProcess] = objectIdentifiers.compactMap { objectID in
                do {
                    let proc = try AudioProcess(objectID: objectID, runningApplications: runningApps)
                    return proc.audioActive ? proc : nil
                } catch {
                    return nil
                }
            }

            let sortedActiveProcesses = activeProcesses.sorted {
                if $0.kind == .app && $1.kind == .process {
                    return true
                }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            
            if self.activeProcess != sortedActiveProcesses.first {
                 self.activeProcess = sortedActiveProcesses.first
            }

        } catch {
            logger.error("Error reading process list: \(error, privacy: .public)")
            if self.activeProcess != nil {
                self.activeProcess = nil
            }
        }
    }
}


// ... (all extensions and private helpers below this line are unchanged) ...
private extension AudioProcess {
    init(app: NSRunningApplication, objectID: AudioObjectID) {
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? app.bundleIdentifier?.components(separatedBy: ".").last ?? "Unknown \(app.processIdentifier)"

        self.init(
            id: app.processIdentifier,
            kind: .app,
            name: name,
            audioActive: objectID.readProcessIsRunning(),
            bundleID: app.bundleIdentifier,
            bundleURL: app.bundleURL,
            objectID: objectID
        )
    }

    init(objectID: AudioObjectID, runningApplications apps: [NSRunningApplication]) throws {
        let pid: pid_t = try objectID.read(kAudioProcessPropertyPID, defaultValue: -1)

        if let app = apps.first(where: { $0.processIdentifier == pid }) {
            self.init(app: app, objectID: objectID)
        } else {
            try self.init(objectID: objectID, pid: pid)
        }
    }

    init(objectID: AudioObjectID, pid: pid_t) throws {
        let bundleID = objectID.readProcessBundleID()
        let bundleURL: URL?
        let name: String

        (name, bundleURL) = if let info = processInfo(for: pid) {
            (info.name, URL(fileURLWithPath: info.path).parentBundleURL())
        } else if let id = bundleID?.lastReverseDNSComponent {
            (id, nil)
        } else {
            ("Unknown (\(pid))", nil)
        }

        self.init(
            id: pid,
            kind: bundleURL?.isApp == true ? .app : .process,
            name: name,
            audioActive: objectID.readProcessIsRunning(),
            bundleID: bundleID.flatMap { $0.isEmpty ? nil : $0 },
            bundleURL: bundleURL,
            objectID: objectID
        )
    }
}

// MARK: - Grouping

extension AudioProcessGroup {
    static func groups(with processes: [AudioProcess]) -> [AudioProcessGroup] {
        var byKind = [AudioProcess.Kind: AudioProcessGroup]()

        for process in processes {
            byKind[process.kind, default: .init(for: process.kind)].processes.append(process)
        }

        return byKind.values.sorted(by: { $0.title.localizedStandardCompare($1.title) == .orderedAscending })
    }
}

extension AudioProcessGroup {
    init(for kind: AudioProcess.Kind) {
        self.init(id: kind.rawValue, title: kind.groupTitle, processes: [])
    }
}

extension AudioProcess.Kind {
    var groupTitle: String {
        switch self {
        case .process: "Processes"
        case .app: "Apps"
        }
    }
}

// MARK: - Helpers

private func processInfo(for pid: pid_t) -> (name: String, path: String)? {
    let nameBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))
    let pathBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(MAXPATHLEN))

    defer {
        nameBuffer.deallocate()
        pathBuffer.deallocate()
    }

    let nameLength = proc_name(pid, nameBuffer, UInt32(MAXPATHLEN))
    let pathLength = proc_pidpath(pid, pathBuffer, UInt32(MAXPATHLEN))

    guard nameLength > 0, pathLength > 0 else {
        return nil
    }

    let name = String(cString: nameBuffer)
    let path = String(cString: pathBuffer)

    return (name, path)
}

private extension String {
    var lastReverseDNSComponent: String? {
        components(separatedBy: ".").last.flatMap { $0.isEmpty ? nil : $0 }
    }
}

private extension URL {
    func parentBundleURL(maxDepth: Int = 8) -> URL? {
        var depth = 0
        var url = deletingLastPathComponent()
        while depth < maxDepth, !url.isBundle {
            url = url.deletingLastPathComponent()
            depth += 1
        }
        return url.isBundle ? url : nil
    }

    var isBundle: Bool {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .bundle) == true
    }

    var isApp: Bool {
        (try? resourceValues(forKeys: [.contentTypeKey]))?.contentType?.conforms(to: .application) == true
    }
}
