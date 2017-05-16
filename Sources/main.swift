
import Foundation
import Moderator
import FileSmith

let indentation = "\t"

extension Dictionary {

    mutating func merge(with dictionary: Dictionary) {
        dictionary.forEach { self[$0] = $1 }
    }

    func merged(with dictionary: Dictionary) -> Dictionary {
        var dict = self
        dict.merge(with: dictionary)

        return dict
    }
}

extension String {
	func subString(between before: String, and after: String) -> String? {
		guard let start = range(of: before)?.upperBound,
			let end = range(of: after, range: start..<endIndex)?.lowerBound
			else { return nil }
		return self[start..<end]
	}
}

typealias TestClasses = [String: Set<String>]

func getTestClasses(_ input: ReadableFile) -> TestClasses {
	var result = TestClasses()

    var classname: String?

	for line in input.lines() {

		if line.contains("XCTestCase"), let name = line.subString(between: "class", and: ":")?.trimmingCharacters(in: .whitespaces) {

            classname = name
			result[name] = Set()

		} else if let currentclass = classname,
            var currentClassFuncs = result[currentclass],
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("/*"),
			let newfunc = line.subString(between: "func ", and: "()")?.trimmingCharacters(in: .whitespaces),
			newfunc.hasPrefix("test") {

			currentClassFuncs.insert(newfunc)
			result[currentclass] = currentClassFuncs
		}
	}
	return result
}

func getTestClassesFromAllTests(_ input: ReadableFile) -> TestClasses {
    var result = TestClasses()

    var classname: String?

    var isAllTests = false

    for line in input.lines() {

        if line.contains("XCTestCase"), let name = line.subString(between: "class", and: ":")?.trimmingCharacters(in: .whitespaces) {

            classname = name
            result[name] = Set()
            isAllTests = false

        } else if !isAllTests && line.contains("static let allTests = [") {
            isAllTests = true

        } else if let currentclass = classname,
            var currentClassFuncs = result[currentclass],
            !line.trimmingCharacters(in: .whitespaces).hasPrefix("//") && !line.trimmingCharacters(in: .whitespaces).hasPrefix("/*"),
            let newfunc = line.subString(between: "\",", and: ")")?.trimmingCharacters(in: .whitespaces),
            newfunc.hasPrefix("test") {

            currentClassFuncs.insert(newfunc)
            result[currentclass] = currentClassFuncs
        }
    }
    return result
}

func makeAllTests(classname: String, funcs: Set<String>) -> String {
	var result = "\nextension " + classname + " {\n"
	result += indentation + "public static var allTests = [\n"
	result += funcs.map { testfunc in
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
	let names = testclasses.map {$0.key}
	print("+ \(path): Added 'allTests' to \(names.joined(separator: ", ")).")
	return names
}

func getTestClassnamesLinuxMainDotSwift(testdir: Directory) throws -> Set<String> {
    var result = Set<String>()

    let input = try testdir.open(file: "LinuxMain.swift")

    for line in input.lines() {

        if line.contains("testCase("), let name = line.subString(between: "testCase(", and: ".allTests)")?.trimmingCharacters(in: .whitespaces) {

            // We don't have a way (yet) to know to which package a test class belongs,
            // so we are going to strip eventual namespacing for the time being.
            result.insert(name.components(separatedBy: ".").last ?? name)
        }
    }
    return result
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

func testClassesDifference(_ parsed: TestClasses, declared: TestClasses) -> TestClasses {
    var result = TestClasses()

    for testClass in parsed {
        let funcs = declared[testClass.key] ?? Set()
        let missingTests = testClass.value.subtracting(funcs)

        if !missingTests.isEmpty {
            result[testClass.key] = missingTests
        }
    }

    return result
}

func checkOnly(testDir: Directory, testFiles: [FilePath]) throws -> Bool {

    // Check for missing tests declaration
    var missingTests = TestClasses()

    var allTestClassNames = Set<String>()

    for testFile in testFiles {
        let testClasses = getTestClasses(try testFile.open())
        let allTestsTestClasses = getTestClassesFromAllTests(try testFile.open())

        missingTests.merge(with: testClassesDifference(testClasses, declared: allTestsTestClasses))

        allTestClassNames.formUnion(Set(testClasses.keys))
    }

    // Check for missing test classes in LinuxMain.swift
    let missingLinuxDotMainClassNames = allTestClassNames.subtracting(try getTestClassnamesLinuxMainDotSwift(testdir: testDir))

    guard missingTests.isEmpty, missingLinuxDotMainClassNames.isEmpty else {

        if !missingLinuxDotMainClassNames.isEmpty {
            WritableFile.stderror.print("LinuxMain.swift testCase declarations missing:\n")
            for testCase in missingLinuxDotMainClassNames {
                WritableFile.stderror.print(testCase)
            }
            WritableFile.stderror.print("")
        }

        if !missingTests.isEmpty {
            WritableFile.stderror.print("Tests declaration missing:\n")
            for testClass in missingTests {
                WritableFile.stderror.print(testClass.key)
                for test in testClass.value {
                    WritableFile.stderror.print("\t\(test)")
                }
            }
        }

        return false
    }

    return true
}

let arguments = Moderator(description: "Automatically add code to Swift Package Manager projects to run unit tests on Linux.")
let overwrite = arguments.add(.option("o","overwrite", description: "Replace <test directory>/LinuxMain.swift if it already exists."))
let checkOnly = arguments.add(.option("c","checkOnly", description: "Do not modify any file. Exits with 0 if test cases are in sync, otherwise exits with 1."))
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

	let testdir = try Directory(open: testdirarg.value)

	if !checkOnly.value && !overwrite.value && testdir.contains("LinuxMain.swift") {
		throw ArgumentError(errormessage: "\(testdir.path)/LinuxMain.swift already exists. Use -o/--overwrite to replace it.")
	}

	let testfiles = testdir.files("*/*.swift", recursive: true)
	guard !testfiles.isEmpty else {
		WritableFile.stderror.print("Could not find any .swift files under \"\(testdir.path)/*/\".")
		exit(EXIT_FAILURE)
	}

    guard !checkOnly.value else {
        // Perform only a check then exit
        exit(try checkOnly(testDir: testdir, testFiles: testfiles) ? 0 : EXIT_FAILURE)
    }

	let classnames = try testfiles.flatMap(addAllTests)
	try makeLinuxMainDotSwift(testdir: testdir, classnames: classnames)
} catch {
	WritableFile.stderror.print(error)
	exit(Int32(error._code))
}
