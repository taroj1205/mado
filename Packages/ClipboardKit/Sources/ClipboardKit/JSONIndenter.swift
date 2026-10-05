struct JSONIndenter {
    private static let indent = "  "

    private(set) var output = ""
    private var depth = 0
    private var inString = false
    private var escaped = false
    private var opened: Character?

    init(_ json: String) {
        for character in json {
            take(character)
        }
    }

    private mutating func take(_ character: Character) {
        if inString {
            output.append(character)
            readString(character)
            return
        }
        if character.isWhitespace { return }
        if let open = opened {
            opened = nil
            if [("{", "}"), ("[", "]")].contains(where: { $0 == (open, character) }) {
                output.append(character)
                return
            }
            depth += 1
            newLine()
        }
        place(character)
    }

    private mutating func readString(_ character: Character) {
        if escaped {
            escaped = false
        } else if character == "\\" {
            escaped = true
        } else if character == "\"" {
            inString = false
        }
    }

    private mutating func place(_ character: Character) {
        switch character {
        case "{", "[":
            output.append(character)
            opened = character

        case "}", "]":
            depth -= 1
            newLine()
            output.append(character)

        case ",":
            output.append(character)
            newLine()

        case ":":
            output += ": "

        default:
            inString = character == "\""
            output.append(character)
        }
    }

    private mutating func newLine() {
        output += "\n" + String(repeating: Self.indent, count: depth)
    }
}
