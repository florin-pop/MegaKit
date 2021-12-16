//
//  MegaClientTests.swift
//  MegaKitTests
//
//  Created by Florin Pop on 12.12.21.
//

import DVR
import MegaKit
import XCTest

class SequenceMock: Sequence {
    private var val = 3_020_759_116

    public func next() -> Int {
        val += 1
        return val
    }
}

class GetDownloadLinkTests: XCTestCase {
    func testGetDownloadLink() throws {
        let session = Session(cassetteName: "getDownloadLink")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let linkID = "Q64TCAoZ"

        let expectation = XCTestExpectation(description: "getDownloadLink")

        megaClient.getDownloadLink(from: linkID) { result in
            switch result {
            case let .success(metadata):
                XCTAssertEqual(metadata.size, 5)
                XCTAssertEqual(metadata.downloadLink, "https://gfs270n074.userstorage.mega.co.nz/dl/1nzVx5oo1BXvEQLuPBqmCJJO3Sf2XMmOd5pjSRaN4N3ifkVFm0fqSLujl9SSkCn_tSiDhmAgshYSfCUkijRZmcLlsZVZr8gdlpNerC5zQvW2waXmTNUFydtDQ4ASZw")
                XCTAssertEqual(metadata.encryptedAttributes, "EZY15byenXBGPA7bQw3c44tf51J8uFSKt3wXakv0NX6wd9OM08-VkNzTJzALGPyAgOS6B1lJAPYHgjiYhqVZbA")
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetDownloadLinkReturnsAPIError() throws {
        let session = Session(cassetteName: "getDownloadLinkReturnsAPIError")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let linkID = "not-a-valid-link"

        let expectation = XCTestExpectation(description: "getDownloadLink")

        megaClient.getDownloadLink(from: linkID) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .apiError(-2))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetDownloadLinkReturnsHTTPError() throws {
        let session = Session(cassetteName: "getDownloadLinkReturnsHTTPError")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let linkID = "Q64TCAoZ"

        let expectation = XCTestExpectation(description: "getDownloadLink")

        megaClient.getDownloadLink(from: linkID) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .httpError(404))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetDownloadLinkReturnsBadResponse() throws {
        let session = Session(cassetteName: "getDownloadLinkReturnsBadResponse")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let linkID = "Q64TCAoZ"

        let expectation = XCTestExpectation(description: "getDownloadLink")

        megaClient.getDownloadLink(from: linkID) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .badResponse)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
}

class GetContentsTests: XCTestCase {
    func testGetContents() throws {
        let session = Session(cassetteName: "getContents")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let megaLink = try! MegaLink(url: "https://mega.nz/folder/0nwH1AAZ#SlkmWJZEv0YRwPViikeLQQ")

        let expectation = XCTestExpectation(description: "getContents")

        megaClient.getContents(of: megaLink) { result in
            switch result {
            case let .success(metadata):
                XCTAssertEqual(metadata.count, 4)
                XCTAssertEqual(metadata.keys.sorted(), ["AvxX2IIA", "E7oSWQJA", "Ezx1FQxQ", "tr4yFSBa"])
                let rootID = "tr4yFSBa"
                XCTAssertEqual(metadata[rootID]?.type, .folder)
                XCTAssertEqual(metadata[rootID]?.key.base64EncodedString(), "kNkZcKUzjuMVLbv6wrdZMw==")
                // subfolder
                XCTAssertEqual(metadata["E7oSWQJA"]?.parent, rootID)
                XCTAssertEqual(metadata["E7oSWQJA"]?.type, .folder)
                XCTAssertEqual(metadata["E7oSWQJA"]?.key.base64EncodedString(), "ga/qjKbCoHL1dYtHEWomYw==")
                // text file
                XCTAssertEqual(metadata["AvxX2IIA"]?.parent, "E7oSWQJA")
                XCTAssertEqual(metadata["AvxX2IIA"]?.type, .file)
                XCTAssertEqual(metadata["AvxX2IIA"]?.key.base64EncodedString(), "1h9D4DUWbbiguPuXiIAk1H/fBUmCa442lUwdjE2zvoo=")
                XCTAssertEqual(metadata["AvxX2IIA"]?.size, 5)
                // image
                XCTAssertEqual(metadata["Ezx1FQxQ"]?.parent, rootID)
                XCTAssertEqual(metadata["Ezx1FQxQ"]?.type, .file)
                XCTAssertEqual(metadata["Ezx1FQxQ"]?.key.base64EncodedString(), "8LBl1PVt6Kybr1T/jX0msGtN1PlqfEfuxnCkWnboz1g=")
                XCTAssertEqual(metadata["Ezx1FQxQ"]?.size, 254_082)
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetContentsAPIError() throws {
        let session = Session(cassetteName: "getContentsReturnsAPIError")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let megaLink = try! MegaLink(url: "https://mega.nz/folder/AAAAAAAA#SlkmWJZEv0YRwPViikeLQQ")

        let expectation = XCTestExpectation(description: "getContents")

        megaClient.getContents(of: megaLink) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .apiError(-2))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetContentsUnknownError() throws {
        let session = Session(cassetteName: "getContentsUnknownError")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let megaLink = try! MegaLink(url: "https://mega.nz/folder/AAAAAAAA#SlkmWJZEv0YRwPViikeLQQ")

        let expectation = XCTestExpectation(description: "getContents")

        megaClient.getContents(of: megaLink) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .unknown)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetContentsReturnsHTTPError() throws {
        let session = Session(cassetteName: "getContentsReturnsHTTPError")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let megaLink = try! MegaLink(url: "https://mega.nz/folder/AAAAAAAA#SlkmWJZEv0YRwPViikeLQQ")

        let expectation = XCTestExpectation(description: "getContents")

        megaClient.getContents(of: megaLink) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .httpError(400))
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }

    func testGetContentsReturnsBadResponse() throws {
        let session = Session(cassetteName: "getContentsReturnsBadResponse")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let megaLink = try! MegaLink(url: "https://mega.nz/folder/AAAAAAAA#SlkmWJZEv0YRwPViikeLQQ")

        let expectation = XCTestExpectation(description: "getContents")

        megaClient.getContents(of: megaLink) { result in
            switch result {
            case .success:
                XCTFail()
            case let .failure(error):
                XCTAssertEqual(error, .badResponse)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
}

class GetFileMetadataTests: XCTestCase {
    func testGetFileMetadata() throws {
        let session = Session(cassetteName: "getFileMetadata")
        let megaClient = MegaClient(urlSession: session, sequence: SequenceMock())

        let megaLink = try! MegaLink(url: "https://mega.nz/file/Q64TCAoZ#1h9D4DUWbbiguPuXiIAk1H_fBUmCa442lUwdjE2zvoo")

        let expectation = XCTestExpectation(description: "getFileMetadata")

        megaClient.getFileMetadata(from: megaLink) { result in
            switch result {
            case let .success(metadata):
                XCTAssertEqual(metadata.name, "ABC.txt")
            case .failure:
                XCTFail()
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2)
    }
}
