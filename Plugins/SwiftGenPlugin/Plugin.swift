//
// SwiftGenPlugin
// Copyright © 2022 SwiftGen
// MIT Licence
//

import Foundation
import PackagePlugin

@main
struct SwiftGenPlugin: BuildToolPlugin {
  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let fileManager = FileManager.default

    // Possible paths where there may be a config file (root of package, target dir.)
    let configurations: [Path] = [context.package.directory, target.directory]
      .map { $0.appending("swiftgen.yml") }
      .filter { fileManager.fileExists(atPath: $0.string) }

    // Validate paths list
    guard validate(configurations: configurations, target: target) else {
      return []
    }
      
    try? fileManager.createDirectory(atPath: target.directory.appending(["Generated"]).string, withIntermediateDirectories: true)

    return try configurations.map { configuration in
      try .swiftgen(using: configuration, context: context, target: target)
    }
  }
}

// MARK: - Helpers

private extension SwiftGenPlugin {
  /// Validate the given list of configurations
  func validate(configurations: [Path], target: Target) -> Bool {
    guard !configurations.isEmpty else {
      Diagnostics.error("""
      No SwiftGen configurations found for target \(target.name). If you would like to generate sources for this \
      target include a `swiftgen.yml` in the target's source directory, or include a shared `swiftgen.yml` at the \
      package's root.
      """)
      return false
    }

    return true
  }
}

private extension Command {
    static func swiftgen(using configuration: Path, context: PluginContext, target: Target) throws -> Command {
        .buildCommand(
            displayName: "SwiftGen BuildTool Plugin",
            executable: try context.tool(named: "swiftgen").path,
            arguments: [
                "config",
                "run",
                "--verbose",
                "--config", "\(configuration)"
            ],
            environment: [
                "PROJECT_DIR": context.package.directory,
                "TARGET_NAME": target.name,
                "PRODUCT_MODULE_NAME": target.moduleName,
                "DERIVED_SOURCES_DIR": context.pluginWorkDirectory
            ],
            inputFiles: [],
            outputFiles: [
                target.directory.appending(["Generated"])
            ]
        )
    }
}

private extension FileManager {
  /// Re-create the given directory
  func forceClean(directory: Path) {
    try? removeItem(atPath: directory.string)
    try? createDirectory(atPath: directory.string, withIntermediateDirectories: false)
  }
}

extension Target {
  /// Try to access the underlying `moduleName` property
  /// Falls back to target's name
  var moduleName: String {
    switch self {
    case let target as SourceModuleTarget:
      return target.moduleName
    default:
      return ""
    }
  }
}
