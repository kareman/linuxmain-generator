
import SwiftShell
import Foundation
import Moderator
import FileSmith

let indentation = "\t"

extension String {
	func subString(between: String, and: String) -> String? {
		guard let start = range(of: between)?.upperBound,
			let end = range(of: and, range: start..<endIndex)?.lowerBound
			else { return nil }
		return self[start..<end]
	}
}

typealias TestClass = (classname: String, funcs: [String])

func getTestClasses(_ input: File) -> [TestClass] {
	var result = [TestClass]()
	for line in input.lines() {
		if line.contains("XCTestCase"),
			let classname = line.subString(between: "class", and: ":")?.trimmingCharacters(in: .whitespaces) {

			result.append((classname,[]))

		} else if var currentclass = result.last,
			let newfunc = line.subString(between: "func ", and: "()")?.trimmingCharacters(in: .whitespaces),
			newfunc.hasPrefix("test") {

			currentclass.funcs.append(newfunc)
			result[result.endIndex-1] = currentclass
		}
	}
	return result
}

func makeAllTests(_ testclass: TestClass) -> String {
	var result = "\nextension " + testclass.classname + " {\n"
	result += indentation + "public static var allTests = [\n"
	result += testclass.funcs.map { testfunc in
		indentation + indentation + "(\"\(testfunc)\", \(testfunc)),\n"
		}.joined()
	result += indentation + indentation + "]\n"
	result += "}\n"
	return result
}

func addAllTests(tofile path: FilePath) throws -> [String] {
	let file = try path.edit()
	let testclasses = getTestClasses(file)
	guard !testclasses.isEmpty else { print("  Tests/\(path): Skipping, no test classes found."); return [] }

	testclasses.map(makeAllTests).forEach(file.write)
	let names = testclasses.map {$0.classname}
	print("+ Tests/\(path): Added 'allTests' to \(names.joined(separator: ", ")).")
	return names
}

func makeLinuxMainDotSwift(_ classnames: [String]) throws {
	let testdir = try Directory(open: "Tests")
	let linuxmain = try testdir.create(file:"LinuxMain.swift", ifExists: .replace)
	let testdirs = testdir.directories()

	var result = "\nimport XCTest\n\n"
	result += testdirs.map {dir in
		"@testable import \(dir.name) \n"}.joined()
	result += "\nlet tests: [XCTestCaseEntry] = [\n"
	result += classnames.map { indentation + "testCase(\($0).allTests),\n" }.joined()
	result += indentation + "]\n\n"
	result += "XCTMain(tests)\n"

	linuxmain.write(result)
	print("+ Tests/LinuxMain.swift")
}

let arguments = Moderator()
let overwrite = arguments.add(.option("o","overwrite", description: "Replace Tests/LinuxMain.swift if it already exists."))
//let dryrun = arguments.add(.option("d","dryrun", description: "Show what will happen without changing any files."))
let projectdir = arguments.add(Argument<String?>
	.singleArgument(name: "directory", description: "The project root directory")
	.default("./")
	.map { (rootpath:String) -> DirectoryPath in
		let rootdir = try Directory(open: rootpath)
		try rootdir.verifyContains("Package.swift")
		guard	!(!overwrite.value && rootdir.contains("Tests/LinuxMain.swift")) else {
			throw ArgumentError(errormessage: "\(rootdir.path)/Tests/LinuxMain.swift already exists. Use -o/--overwrite to replace it.")
		}
		return rootdir.path
	})

do {
	try arguments.parse()
	DirectoryPath.current = projectdir.value

	let testfiles = try Directory(open: "Tests").files("*/*.swift", recursive: true)
	guard !testfiles.isEmpty else { exit(errormessage: "Could not find any .swift files under \"Tests/*/\".") }
	let classnames = try testfiles.flatMap(addAllTests)
	try makeLinuxMainDotSwift(classnames)
} catch {
	exit(error)
}
