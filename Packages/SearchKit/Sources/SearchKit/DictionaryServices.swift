import CoreServices
import Foundation

@safe
struct DictionaryServices: Sendable {
    private typealias List = @convention(c) () -> Unmanaged<CFArray>?
    private typealias Default = @convention(c) () -> Unmanaged<DCSDictionary>?
    private typealias Name = @convention(c) (DCSDictionary) -> Unmanaged<CFString>?
    private typealias Search =
        @convention(c) (
            DCSDictionary, CFString, UnsafeRawPointer?, UnsafeRawPointer?
        ) -> Unmanaged<CFArray>?
    private typealias Fields = @convention(c) (CFTypeRef, CFArray?) -> Unmanaged<CFDictionary>?
    private typealias Markup = @convention(c) (CFTypeRef, CFIndex) -> Unmanaged<CFString>?
    private typealias Match = (record: CFTypeRef, fields: [String: Any])

    private enum Key {
        static let headword = "DCSTextElementKeyHeadword"
        static let pronunciation = "DCSTextElementKeyPronunciation"
        static let partOfSpeech = "DCSTextElementKeyPartOfSpeech"
        static let senses = "DCSTextElementKeySenses"
    }

    static let shared = Self()
    private static let wordCharacters = CharacterSet.urlPathAllowed.subtracting(
        CharacterSet(charactersIn: ":/"))
    private static let rawMarkup = 0

    private let active: List
    private let defaultThesaurus: Default
    private let name: Name
    private let identifier: Name
    private let search: Search
    private let fields: Fields
    private let markup: Markup

    private init?() {
        let handle = unsafe dlopen(nil, RTLD_NOW)
        func symbol<T>(_ name: String, _: T.Type) -> T? {
            unsafe dlsym(handle, name).map { unsafe unsafeBitCast($0, to: T.self) }
        }
        guard let list = unsafe symbol("DCSGetActiveDictionaries", List.self),
            let preferred = unsafe symbol("DCSGetDefaultThesaurus", Default.self),
            let getName = unsafe symbol("DCSDictionaryGetName", Name.self),
            let getID = unsafe symbol("DCSDictionaryGetIdentifier", Name.self),
            let find = unsafe symbol("DCSCopyRecordsForSearchString", Search.self),
            let copyFields = unsafe symbol("DCSRecordCopyTextElements", Fields.self),
            let copyMarkup = unsafe symbol("DCSRecordCopyData", Markup.self)
        else { return nil }
        unsafe self.active = list
        unsafe self.defaultThesaurus = preferred
        unsafe self.name = getName
        unsafe self.identifier = getID
        unsafe self.search = find
        unsafe self.fields = copyFields
        unsafe self.markup = copyMarkup
    }

    static func names(_ term: String, _ fields: [String: Any]) -> Bool {
        [Key.headword, Key.pronunciation].contains { key in
            let word = (fields[key] as? String)?.replacing("・", with: "")
            return word?.compare(term, options: [.caseInsensitive, .widthInsensitive])
                == .orderedSame
        }
    }

    func entry(for term: String) -> DictionaryLookup.Entry? {
        let dictionaries = unsafe active()?.takeUnretainedValue() as? [DCSDictionary] ?? []
        let preferred = unsafe defaultThesaurus()?.takeUnretainedValue()
        let thesaurus = dictionaries.first { dictionary in
            preferred.map { CFEqual(dictionary, $0) } ?? false
        }
        for dictionary in dictionaries
        where !(thesaurus.map { CFEqual(dictionary, $0) } ?? false) {
            guard let found = match(term, in: dictionary),
                let sense = (found.fields[Key.senses] as? [String])?.first
            else { continue }
            let headword = found.fields[Key.headword] as? String ?? term
            let synonyms = thesaurus.flatMap { match(headword, in: $0, exact: true) }
            let relations = DictionaryLookup.relations(
                in: xhtml(of: synonyms?.record ?? found.record))
            let japanese = dictionaries.first { other in
                !CFEqual(other, dictionary) && id(of: other) == DictionaryLookup.japaneseID
            }
            return DictionaryLookup.Entry(
                headword: headword,
                pronunciation: DictionaryLookup.pronunciation(
                    found.fields[Key.pronunciation] as? String ?? ""),
                partOfSpeech: found.fields[Key.partOfSpeech] as? String ?? "",
                definition: DictionaryLookup.sentence(sense), similar: relations.similar,
                opposite: relations.opposite,
                dictionary: unsafe name(dictionary)?.takeUnretainedValue() as String? ?? "",
                url: url(of: found, in: dictionary) ?? DictionaryLookup.lookupURL(for: term),
                japaneseURL: japanese.flatMap { japanese in
                    match(term, in: japanese).flatMap { url(of: $0, in: japanese) }
                })
        }
        return nil
    }

    private func match(_ term: String, in source: DCSDictionary, exact: Bool = false) -> Match? {
        let records = unsafe search(source, term as CFString, nil, nil)?
            .takeRetainedValue()
        let found = (records as? [CFTypeRef] ?? []).lazy.compactMap { record -> Match? in
            let values = unsafe fields(record, nil)?.takeRetainedValue() as? [String: Any]
            return values.map { (record, $0) }
        }
        let named = found.first { Self.names(term, $0.fields) }
        return exact ? named : named ?? found.first
    }

    private func xhtml(of record: CFTypeRef) -> String {
        unsafe markup(record, Self.rawMarkup)?.takeRetainedValue() as String? ?? ""
    }

    private func id(of dictionary: DCSDictionary) -> String? {
        unsafe identifier(dictionary)?.takeUnretainedValue() as String?
    }

    private func url(of match: Match, in dictionary: DCSDictionary) -> URL? {
        guard
            let word = (match.fields[Key.headword] as? String)?
                .addingPercentEncoding(withAllowedCharacters: Self.wordCharacters),
            let id = id(of: dictionary)
        else { return nil }
        return URL(string: "x-dictionary:d:\(word):\(id)")
    }
}
