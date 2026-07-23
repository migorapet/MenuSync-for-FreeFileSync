import Foundation

struct ProcessCapture {
    let stdout: Data
    let stderr: String
    let terminationStatus: Int32
}

private final class ProcessDataCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()

    func setStdout(_ data: Data) {
        lock.lock()
        stdout = data
        lock.unlock()
    }

    func setStderr(_ data: Data) {
        lock.lock()
        stderr = data
        lock.unlock()
    }

    func snapshot() -> (stdout: Data, stderr: Data) {
        lock.lock()
        defer { lock.unlock() }
        return (stdout, stderr)
    }
}

enum RunnerError: LocalizedError {
    case executableMissing
    case batchJobMissing
    case invalidBatchJob
    case launchFailed(String)
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .executableMissing:
            return "The selected FreeFileSync.app does not contain the expected executable."
        case .batchJobMissing:
            return "The selected .ffs_batch file could not be found."
        case .invalidBatchJob:
            return "Select a file with the .ffs_batch extension."
        case let .launchFailed(message):
            return "FreeFileSync could not be launched: \(message)"
        case let .invalidJSON(details):
            return details.isEmpty
                ? "FreeFileSync did not return valid JSON."
                : "FreeFileSync did not return valid JSON. \(details)"
        }
    }
}

struct SyncRunResponse {
    let output: FreeFileSyncOutput
    let terminationStatus: Int32
}

enum FreeFileSyncRunner {
    static func run(
        batchJobPath: String,
        freeFileSyncAppPath: String
    ) async throws -> SyncRunResponse {
        try await Task.detached(priority: .utility) {
            let capture = try captureProcess(
                arguments: [batchJobPath],
                freeFileSyncAppPath: freeFileSyncAppPath
            )
            do {
                let output = try JSONDecoder().decode(FreeFileSyncOutput.self, from: capture.stdout)
                return SyncRunResponse(
                    output: output,
                    terminationStatus: capture.terminationStatus
                )
            } catch {
                throw RunnerError.invalidJSON(capture.stderr)
            }
        }.value
    }

    static func openForEditing(
        batchJobPath: String,
        freeFileSyncAppPath: String
    ) throws {
        let executableURL = executableURL(for: freeFileSyncAppPath)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw RunnerError.executableMissing
        }
        guard FileManager.default.fileExists(atPath: batchJobPath) else {
            throw RunnerError.batchJobMissing
        }
        guard URL(fileURLWithPath: batchJobPath).pathExtension.lowercased() == "ffs_batch" else {
            throw RunnerError.invalidBatchJob
        }

        let process = Process()
        process.executableURL = executableURL
        process.arguments = ["-edit", batchJobPath]
        do {
            try process.run()
        } catch {
            throw RunnerError.launchFailed(error.localizedDescription)
        }
    }

    private static func captureProcess(
        arguments: [String],
        freeFileSyncAppPath: String
    ) throws -> ProcessCapture {
        let executableURL = executableURL(for: freeFileSyncAppPath)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw RunnerError.executableMissing
        }
        guard let batchPath = arguments.first,
              FileManager.default.fileExists(atPath: batchPath) else {
            throw RunnerError.batchJobMissing
        }
        guard URL(fileURLWithPath: batchPath).pathExtension.lowercased() == "ffs_batch" else {
            throw RunnerError.invalidBatchJob
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw RunnerError.launchFailed(error.localizedDescription)
        }

        let group = DispatchGroup()
        let capturedData = ProcessDataCapture()

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            capturedData.setStdout(data)
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            capturedData.setStderr(data)
            group.leave()
        }

        process.waitUntilExit()
        group.wait()
        let captured = capturedData.snapshot()

        return ProcessCapture(
            stdout: captured.stdout,
            stderr: String(data: captured.stderr, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            terminationStatus: process.terminationStatus
        )
    }

    private static func executableURL(for appPath: String) -> URL {
        URL(fileURLWithPath: appPath, isDirectory: true)
            .appendingPathComponent("Contents/MacOS/FreeFileSync")
    }
}
