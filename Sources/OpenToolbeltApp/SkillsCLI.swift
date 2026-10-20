import Foundation
import Observation
import OpenToolbeltCore

/// Runs `npx skills` and streams its output. Runs through a login,
/// interactive zsh so the user's Node setup (nvm, fnm, Homebrew) is on PATH,
/// which a GUI app does not inherit.
@MainActor @Observable
final class SkillsCLI {
    enum Status: Equatable { case idle, running, succeeded, failed(Int32) }

    private(set) var status: Status = .idle
    private(set) var output = ""
    private var process: Process?

    func run(_ arguments: [String], onSuccess: @escaping @MainActor () -> Void) {
        guard status != .running else { return }
        output = "$ " + (["npx"] + arguments).joined(separator: " ") + "\n"
        status = .running

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-l", "-i", "-c", SkillsCommand.shellLine(arguments)]
        var environment = ProcessInfo.processInfo.environment
        environment["NO_COLOR"] = "1"
        environment["FORCE_COLOR"] = "0"
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in self.output += Self.clean(text) }
        }
        process.terminationHandler = { process in
            let code = process.terminationStatus
            Task { @MainActor in
                pipe.fileHandleForReading.readabilityHandler = nil
                self.status = code == 0 ? .succeeded : .failed(code)
                if code == 0 { onSuccess() }
            }
        }
        do {
            try process.run()
            self.process = process
        } catch {
            output += "Could not start zsh: \(error.localizedDescription)\n"
            status = .failed(-1)
        }
    }

    func cancel() {
        process?.terminate()
    }

    func reset() {
        guard status != .running else { return }
        status = .idle
        output = ""
    }

    /// Drops ANSI escape codes and spinner carriage returns.
    private static func clean(_ text: String) -> String {
        text.replacingOccurrences(of: #"\u{1B}\[[0-9;?]*[A-Za-z]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
