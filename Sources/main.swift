
import Foundation
import Moderator
import FileSmith

let indentation = "\t"

extension String {
	func subString(between before: String, and after: String) -> String? {
		guard let start = range(of: before)?.upperBound,
			let end = range(of: after, range: start..<endIndex)?.lowerBound
			else { return nil }
		return self[start..<end]
	}
}

typealias TestClass = (classname: String, funcs: [String])

func getTestClasses(_ input: ReadableFile) -> [TestClass] {
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
	let path = path.relativeTo(.current) // to get correct output when printing the path.
	let testclasses = getTestClasses(try path.open())
	guard !testclasses.isEmpty else { print("  \(path): Skipping, no test classes found."); return [] }

	let file = try path.edit()
	testclasses.map(makeAllTests).forEach(file.write)
	let names = testclasses.map {$0.classname}
	print("+ \(path): Added 'allTests' to \(names.joined(separator: ", ")).")
	return names
}

func makeLinuxMainDotSwift(testdir: Directory, classnames: [String]) throws {
	let linuxmain = try testdir.create(file:"LinuxMain.swift", ifExists: .replace)

	linuxmain.print()
	linuxmain.print("import XCTest")
	linuxmain.print()
	testdir.directories().forEach { linuxmain.print("@testable import \($0.name)") }
	linuxmain.print()
	linuxmain.print("let tests: [XCTestCaseEntry] = [")
	classnames.forEach { linuxmain.print(indentation + "testCase(\($0).allTests),") }
	linuxmain.print(indentation + "]\n")
	linuxmain.print("XCTMain(tests)")

	print("+ \(testdir.path)/LinuxMain.swift")
}

let arguments = Moderator(description: "Automatically add code to Swift Package Manager projects to run unit tests on Linux.")
let overwrite = arguments.add(.option("o","overwrite", description: "Replace <test directory>/LinuxMain.swift if it already exists."))
let testdirarg = arguments.add(Argument<String?>
	.optionWithValue("testdir", name: "test directory", description: "The path to the directory with the unit tests.")
	.default("Tests"))
_ = arguments.add(Argument<String?>
	.singleArgument(name: "directory", description: "The project root directory.")
	.default("./")
	.map { (projectpath: String) in
		let projectdir = try Directory(open: projectpath)
		try projectdir.verifyContains("Package.swift")
		Directory.current = projectdir
	})

do {
	try arguments.parse(strict: true)
	print(arguments.usagetext)

	let testdir = try Directory(open: testdirarg.value)
	if !overwrite.value && testdir.contains("LinuxMain.swift") {
		throw ArgumentError(errormessage: "\(testdir.path)/LinuxMain.swift already exists. Use -o/--overwrite to replace it.")
	}

	let testfiles = testdir.files("*/*.swift", recursive: true)
	guard !testfiles.isEmpty else {
		WritableFile.stderror.print("Could not find any .swift files under \"\(testdir.path)/*/\".")
		exit(EXIT_FAILURE)
	}
	let classnames = try testfiles.flatMap(addAllTests)
	try makeLinuxMainDotSwift(testdir: testdir, classnames: classnames)
} catch {
	WritableFile.stderror.print(error)
	exit(Int32(error._code))
}
