
import SwiftShell
import Foundation

extension String {
	func subString(between: String, and: String) -> String? {
		guard let start = range(of: between)?.upperBound,
			let end = range(of: and, range: start..<endIndex)?.lowerBound
			else { return nil }
		return self[start..<end]
	}
}

func makeAllTests(input: ReadableStream) -> String {
	var result = [String: [String]]()
	var currentclass: String?
	for line in input.lines() {
		if line.contains("XCTestCase"),
			let classname = line.subString(between: "class", and: ":")?.trimmingCharacters(in: .whitespaces) {

			currentclass = classname
			result[classname] = []

		} else if let classname = currentclass,
			line.contains("func "),
			let newfunc = line.subString(between: "func ", and: "(")?.trimmingCharacters(in: .whitespaces),
			newfunc.hasPrefix("test") {

			result[classname]?.append(newfunc)
		}
	}
	print(result)
	return ""
}

guard let swiftfile = try main.arguments.first.map ({try open($0)}) else {
	exit(errormessage: "Missing argument for swift file")
}

makeAllTests(input: swiftfile)
