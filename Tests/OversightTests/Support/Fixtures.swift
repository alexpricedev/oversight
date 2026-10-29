import Foundation
@testable import Oversight

final class FixtureToken {}

enum Fixtures {
    static var bundle: Bundle {
        Bundle(for: FixtureToken.self)
    }

    static func data(_ name: String) throws -> Data {
        if let url = bundle.url(forResource: name, withExtension: "json") {
            return try Data(contentsOf: url)
        }
        if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures") {
            return try Data(contentsOf: url)
        }
        throw FixtureError.missing(name)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try GitHubJSON.decode(type, from: data(name))
    }

    enum FixtureError: Error {
        case missing(String)
    }
}
