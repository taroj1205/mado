import AppCore
import AppKit

struct WeatherSettings: StoredValue, Equatable {
    static let key = "weather"
    private static let footerSize: CGFloat = 12
    private static let openMeteo = "Open-Meteo.com"
    private static let licence = "CC BY 4.0"
    private static let links = [
        (openMeteo, "https://open-meteo.com/"),
        (licence, "https://creativecommons.org/licenses/by/4.0/"),
    ]

    private static var footer: NSAttributedString {
        let text = NSMutableAttributedString(
            string: "Weather data by \(openMeteo), under \(licence).",
            attributes: [
                .font: NSFont.systemFont(ofSize: footerSize),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        for (name, link) in links {
            if let range = text.string.range(of: name) {
                text.addAttribute(.link, value: link, range: NSRange(range, in: text.string))
            }
        }
        return text
    }

    var city: String

    init() {
        city = ""
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        city = try values.decodeIfPresent(String.self, forKey: .city) ?? city
    }

    @MainActor
    static func section(_ modules: ModuleManager?) -> SettingsSection {
        let field = SettingsTextField(
            placeholder: "Current Location", read: { load(from: modules).city },
            write: { city in
                var settings = load(from: modules)
                settings.city = city
                settings.save(to: modules)
            })
        field.isEnabled = modules != nil
        return SettingsSection(
            "Weather", [.init("Location", field)], footer: footer, accessory: nil)
    }
}
