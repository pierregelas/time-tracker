import XCTest
@testable import TimeTrackerApp

final class CSVExportServiceTests: XCTestCase {
    func testEscapeWrapsCommasQuotesAndNewlines() {
        let value = "hello, \"team\"\nnext"

        let escaped = CSVFormatter.escape(value)

        XCTAssertEqual(escaped, "\"hello, \"\"team\"\"\nnext\"")
    }
}
