import Foundation

/// Builds `npx skills` invocations. The vercel-labs/skills CLI does the real
/// installing, linking and lockfile bookkeeping; OpenToolbelt only drives it.
public enum SkillsCommand {
    /// Installs from `source` (owner/repo, a git URL, or a local path) globally
    /// for `agents`. An empty `skills` list installs every skill in the source.
    public static func add(source: String, skills: [String], agents: [Agent]) -> [String] {
        var arguments = ["skills", "add", source, "--global", "--yes"]
        for agent in agents { arguments += ["--agent", agent.rawValue] }
        for skill in skills.isEmpty ? ["*"] : skills { arguments += ["--skill", skill] }
        return arguments
    }

    /// Removes global skills from every agent.
    public static func remove(skills: [String]) -> [String] {
        ["skills", "remove"] + skills + ["--global", "--agent", "*", "--yes"]
    }

    /// One shell command line, with every argument single-quoted so user
    /// input cannot break out of it.
    public static func shellLine(_ arguments: [String]) -> String {
        (["npx", "--yes"] + arguments).map(quote).joined(separator: " ")
    }

    static func quote(_ argument: String) -> String {
        "'" + argument.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
