import PackageDescription

let package = Package(
    name: "linuxmain-generator"
)

package.dependencies.append(.Package(url: "/Users/karemorstol/Programming/SwiftShell/SwiftShell3", "3.0.0-beta"))
package.dependencies.append(.Package(url: "/Users/karemorstol/Programming/Libraries/Moderator/Moderator.swift", "0.4.0-beta"))
package.dependencies.append(.Package(url: "/Users/karemorstol/Programming/Libraries/FileSmith/FileSmith", "0.1.0-alpha"))

