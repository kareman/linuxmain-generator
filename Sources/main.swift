
import SwiftShell
import Foundation

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

func getTestClasses(_ input: ReadableStream) -> [TestClass] {
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

func addAllTests(tofile path: String) throws -> [String] {
	let testclasses = getTestClasses(try open(path))
	guard !testclasses.isEmpty else { print("  \(path): Skipping, no test classes found."); return [] }
	let file = try open(forWriting: path)
	testclasses.map(makeAllTests).forEach(file.write)
	let names = testclasses.map {$0.classname}
	print("+ \(path): Added 'allTests' to \(names.joined(separator: ", ")).")
	return names
}

extension ReadableStream {
	func list() -> [String] {
		let result = Array(lines())
		return (result.last?.isEmpty ?? false) ? Array(result.dropLast()) : result
	}
}

func makeLinuxMainDotSwift(_ classnames: [String]) throws {
	var result = "\nimport XCTest\n\n"
	result += runAsync(bash: "cd Tests && ls -d */").stdout.list().map {dir in "import " + String(dir.characters.dropLast()) + "\n"}.joined()
	result += "\nlet tests: [XCTestCaseEntry] = [\n"
	result += classnames.map { indentation + "testCase(\($0).allTests),\n" }.joined()
	result += indentation + "]\n\n"
	result += "XCTMain(tests)\n"
	let file = try open(forWriting: "Tests/LinuxMain.swift")
	file.write(result)
	print("+ Tests/LinuxMain.swift")
}

//
guard Files.fileExists(atPath: "Package.swift") else { exit(errormessage: "Not in a Swift Package directory: Package.swift not found.") }
guard	!Files.fileExists(atPath: "Tests/LinuxMain.swift") else { exit(errormessage: "Tests/LinuxMain.swift already exists.")}

do {
	let testfiles = runAsync("find", "Tests", "-name", "*.swift").stdout.list()
	guard !testfiles.isEmpty else { exit(errormessage: "Could not find any .swift files in \"Tests/\".") }
	let classnames = try testfiles.flatMap(addAllTests)
	try makeLinuxMainDotSwift(classnames)
} catch {
	exit(error)
}

/*
guard let swiftfile = try main.arguments.first.map ({try open($0)}) else {
	exit(errormessage: "Missing argument for swift file")
}
*/
