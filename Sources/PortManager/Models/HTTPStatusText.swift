import Foundation

enum HTTPStatusText {
    private static let reasons: [Int: String] = [
        200: "OK", 201: "Created", 202: "Accepted", 204: "No Content",
        301: "Moved Permanently", 302: "Found", 304: "Not Modified", 307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 408: "Request Timeout", 409: "Conflict", 426: "Upgrade Required", 429: "Too Many Requests",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway", 503: "Service Unavailable", 504: "Gateway Timeout",
    ]

    static func reason(for statusCode: Int) -> String {
        reasons[statusCode] ?? HTTPURLResponse.localizedString(forStatusCode: statusCode).capitalized
    }
}
