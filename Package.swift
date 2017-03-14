import PackageDescription

let package = Package(
    name: "linuxmain-generator"
)

package.dependencies.append(.Package(url: "https://github.com/kareman/Moderator", "0.4.0"))
package.dependencies.append(.Package(url: "https://github.com/kareman/FileSmith", "0.1.3"))

