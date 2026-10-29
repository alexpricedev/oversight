import Foundation

enum GitHubJSON {
    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = GitHubDates.parse(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unrecognised GitHub date: \(string)"
                )
            }
            return date
        }
        return decoder
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try makeDecoder().decode(type, from: data)
    }
}
