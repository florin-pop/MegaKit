//
//  MegaClient.swift
//  MegaKit
//
//  Created by Florin Pop on 10.12.21.
//

import BigInt
import CryptoSwift
import Foundation

public protocol Sequence {
    func next() -> Int
}

public class MegaSequence: Sequence {
    private var val = Int.random(in: 0 ..< 0xFFFF_FFFF)

    public static var instance: MegaSequence = .init()

    public func next() -> Int {
        val += 1
        return val
    }
}

public struct MegaFileAttributes: Decodable {
    public let name: String

    enum CodingKeys: String, CodingKey {
        case name = "n"
    }

    init?(from attributeData: Data) throws {
        guard let attributeString = String(data: attributeData, encoding: .utf8),
              attributeString.starts(with: "MEGA{"),
              let attributeJSONData = attributeString[attributeString.index(attributeString.startIndex, offsetBy: 4)...].data(using: .utf8),
              let attributes = try? JSONDecoder().decode(Self.self, from: attributeJSONData)
        else {
            return nil
        }

        self = attributes
    }
}

public struct MegaFileMetadata: Decodable {
    public let size: Int64
    public let encryptedAttributes: String
    public let downloadLink: String

    enum CodingKeys: String, CodingKey {
        case size = "s"
        case encryptedAttributes = "at"
        case downloadLink = "g"
    }
}

extension MegaFileMetadata {
    func decryptAttributes(using cipher: Cipher) -> MegaFileAttributes? {
        guard let attributeData = try? encryptedAttributes.base64Decoded()?.decrypt(cipher: cipher)
        else {
            return nil
        }
        return try? MegaFileAttributes(from: attributeData)
    }
}

public struct DecryptedMegaFileMetadata {
    public let url: URL
    public let name: String
    public let size: Int64
    public let key: Data
}

public struct DecryptedMegaNodeMetadata {
    public enum NodeType: Int {
        case file = 0
        case folder = 1
    }

    public let type: NodeType
    public let id: String
    public let parent: String
    public let attributes: MegaFileAttributes
    public let key: Data
    public let timestamp: Int
    public let size: Int?
}

struct MegaNodeMetadata: Decodable {
    let type: Int
    let id: String
    let parent: String
    let encryptedAttributes: String
    let encryptedKey: String
    let timestamp: Int
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case type = "t"
        case id = "h"
        case parent = "p"
        case encryptedAttributes = "a"
        case encryptedKey = "k"
        case timestamp = "ts"
        case size = "s"
    }
}

extension MegaNodeMetadata {
    func decryptKey(using cipher: Cipher) -> Data? {
        guard let base64EncryptedKey = encryptedKey.components(separatedBy: ":").last?.base64Decoded()
        else {
            return nil
        }

        let decryptedKey = base64EncryptedKey.blocks(of: 16).compactMap { try? $0.decrypt(cipher: cipher).padded(to: 16, padding: 0) }.reduce([], +)
        return Data(decryptedKey)
    }

    fileprivate func decryptAttributes(using cipher: Cipher) -> MegaFileAttributes? {
        guard let decryptedKey = decryptKey(using: cipher)
        else {
            return nil
        }

        guard let cipher = AES(key: decryptedKey, blockMode: .cbc, padding: .zeroPadding),
              let attributeData = try? encryptedAttributes.base64Decoded()?.decrypt(cipher: cipher)
        else {
            return nil
        }

        return try? MegaFileAttributes(from: attributeData)
    }
}

struct MegaTreeMetadata: Decodable {
    let nodes: [MegaNodeMetadata]

    enum CodingKeys: String, CodingKey {
        case nodes = "f"
    }
}

extension URLRequest {
    init(sequence: Sequence, sessionID: String? = nil, payload: [[String: String]], queryItems: [URLQueryItem] = []) throws {
        var urlComponents = URLComponents(string: "https://g.api.mega.co.nz/cs")

        urlComponents?.queryItems = [
            URLQueryItem(name: "id", value: "\(sequence.next())"),
        ]

        if let sessionID = sessionID {
            urlComponents?.queryItems?.append(URLQueryItem(name: "sid", value: sessionID))
        }

        urlComponents?.queryItems?.append(contentsOf: queryItems)

        guard let url = urlComponents?.url else {
            throw MegaError.badURL
        }

        self.init(url: url)
        httpMethod = "POST"

        guard let requestData = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]) else {
            throw MegaError.requestFailed
        }

        httpBody = requestData
    }

    func execute<T>(in session: URLSession, completion: @escaping (Result<T, MegaError>) -> Void) where T: Decodable {
        session.dataTask(with: self) { data, response, error in
            guard error == nil else {
                completion(.failure(.requestFailed))
                return
            }

            if let statusCode = (response as? HTTPURLResponse)?.statusCode, !(200 ..< 300).contains(statusCode) {
                completion(.failure(.httpError(statusCode)))
                return
            }

            if let data = data {
                if let response = try? JSONDecoder().decode([T].self, from: data),
                   let fileInfo = response.first
                {
                    completion(.success(fileInfo))
                } else if let response = try? JSONDecoder().decode([Int].self, from: data),
                          let errorCode = response.first
                {
                    completion(.failure(.apiError(errorCode)))
                } else {
                    completion(.failure(.badResponse))
                }
            } else {
                completion(.failure(.unknown))
            }
        }.resume()
    }
}

public struct MegaClient {
    let urlSession: URLSession
    let sequence: Sequence

    public init(urlSession: URLSession = URLSession.shared, sequence: Sequence = MegaSequence.instance) {
        self.urlSession = urlSession
        self.sequence = sequence
    }

    public func getDownloadLink(from handle: String, parentNode: String? = nil, sessionID: String? = nil, completion: @escaping (Result<MegaFileMetadata, MegaError>) -> Void) {
        let queryItems = parentNode.map { [URLQueryItem(name: "n", value: $0)] }

        let requestPayload = [[
            "a": "g", // action
            "g": "1",
            "ssl": "1",
            parentNode != nil ? "n" : "p": handle,
        ]]

        let request: URLRequest

        do {
            request = try URLRequest(sequence: sequence, sessionID: sessionID, payload: requestPayload, queryItems: queryItems ?? [])
        } catch {
            completion(.failure(error as! MegaError))
            return
        }

        request.execute(in: urlSession) { (result: Result<MegaFileMetadata, MegaError>) in
            switch result {
            case let .success(fileInfo):
                completion(.success(fileInfo))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func getFileMetadata(from link: MegaLink, sessionID: String? = nil, completion: @escaping (Result<DecryptedMegaFileMetadata, MegaError>) -> Void) {
        getDownloadLink(from: link.id, sessionID: sessionID) { result in
            switch result {
            case let .success(fileInfo):
                guard let url = URL(string: fileInfo.downloadLink) else {
                    completion(.failure(.badURL))
                    return
                }

                guard let base64Key = link.key.base64Decoded(),
                      let cipher = AES(key: base64Key, blockMode: .cbc, padding: .zeroPadding),
                      let fileName = fileInfo.decryptAttributes(using: cipher)?.name
                else {
                    completion(.failure(.decryptionFailed))
                    return
                }

                completion(.success(DecryptedMegaFileMetadata(url: url, name: fileName, size: fileInfo.size, key: base64Key)))

            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    public func getContents(of link: MegaLink, sessionID: String? = nil, completion: @escaping (Result<[String: DecryptedMegaNodeMetadata], MegaError>) -> Void) {
        guard let base64Key = link.key.base64Decoded(),
              let cipher = AES(key: base64Key, blockMode: .cbc, padding: .zeroPadding)
        else {
            completion(.failure(.decryptionFailed))
            return
        }

        let requestPayload = [[
            "a": "f", // action
            "c": "1",
            "r": "1",
        ]]

        let request: URLRequest

        do {
            request = try URLRequest(sequence: sequence, sessionID: sessionID, payload: requestPayload, queryItems: [URLQueryItem(name: "n", value: link.id)])
        } catch {
            completion(.failure(error as! MegaError))
            return
        }

        request.execute(in: urlSession) { (result: Result<MegaTreeMetadata, MegaError>) in
            switch result {
            case let .success(tree):
                let decryptedNodes: [String: DecryptedMegaNodeMetadata]

                do {
                    decryptedNodes = try tree.nodes.reduce([String: DecryptedMegaNodeMetadata]()) { dict, encryptedMetadata in
                        guard let decryptedKey = encryptedMetadata.decryptKey(using: cipher)
                        else {
                            throw MegaError.decryptionFailed
                        }

                        guard let attributes = encryptedMetadata.decryptAttributes(using: cipher),
                              let nodeType = DecryptedMegaNodeMetadata.NodeType(rawValue: encryptedMetadata.type)
                        else {
                            throw MegaError.decryptionFailed
                        }
                        var dict = dict
                        dict[encryptedMetadata.id] = DecryptedMegaNodeMetadata(type: nodeType, id: encryptedMetadata.id, parent: encryptedMetadata.parent, attributes: attributes, key: decryptedKey, timestamp: encryptedMetadata.timestamp, size: encryptedMetadata.size)
                        return dict
                    }
                } catch {
                    completion(.failure(.decryptionFailed))
                    return
                }

                completion(.success(decryptedNodes))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    struct MegaLoginVersion: Decodable {
        let number: Int

        enum CodingKeys: String, CodingKey {
            case number = "v"
        }
    }

    public func login(using email: String, password: String, completion: @escaping (Result<String, MegaError>) -> Void) {
        let email = email.lowercased()
        let requestPayload = [[
            "a": "us0",
            "user": email,
        ]]

        let request: URLRequest

        do {
            request = try URLRequest(sequence: sequence, payload: requestPayload)
        } catch {
            completion(.failure(error as! MegaError))
            return
        }

        request.execute(in: urlSession) { (result: Result<MegaLoginVersion, MegaError>) in
            switch result {
            case let .success(loginVersion):
                guard loginVersion.number == 1 else {
                    completion(.failure(.unimplemented))
                    return
                }

                guard let arr = password.data(using: .utf8)?.toUInt32Array() else {
                    completion(.failure(.unknown))
                    return
                }

                // https://github.com/odwyersoftware/mega.py/blob/c27d8379e48af23072c46350396ae75f84ec1e30/src/mega/crypto.py#L55
                var passwordKey: [UInt32] = [0x93C4_67E3, 0x7DB0_C7A4, 0xD1BE_3F81, 0x0152_CB56]
                for _ in 0 ..< 0x10000 {
                    for j in stride(from: 0, to: arr.count, by: 4) {
                        var key: [UInt32] = [0, 0, 0, 0]
                        for i in 0 ..< 4 {
                            if i + j < arr.count {
                                key[i] = arr[i + j]
                            }
                        }

                        guard let cipher = AES(key: Data(uInt32Array: key), blockMode: .cbc, padding: .noPadding),
                              let encryptedKey = try? Data(uInt32Array: passwordKey).encrypt(cipher: cipher).toUInt32Array()
                        else {
                            completion(.failure(.decryptionFailed))
                            return
                        }
                        passwordKey = encryptedKey
                    }
                }

                guard let s32 = email.data(using: .utf8)?.toUInt32Array(),
                      let cipher = AES(key: Data(uInt32Array: passwordKey), blockMode: .cbc, padding: .noPadding)
                else {
                    completion(.failure(.decryptionFailed))
                    return
                }

                var h32: [UInt32] = [0, 0, 0, 0]
                for i in 0 ..< s32.count {
                    h32[i % 4] ^= s32[i]
                }

                var h32Data = Data(uInt32Array: h32)
                for _ in 0 ..< 0x4000 {
                    guard let encryptedHash = try? h32Data.encrypt(cipher: cipher) else {
                        completion(.failure(.decryptionFailed))
                        return
                    }
                    h32Data = encryptedHash
                }

                h32 = h32Data.toUInt32Array()

                let passwordHash = Data(uInt32Array: [h32[0], h32[2]]).base64EncodedString()

                openSession(email: email, userHash: passwordHash) { result in
                    switch result {
                    case let .success(loginSession):
                        getSessionId(passwordKey: Data(uInt32Array: passwordKey), loginSession: loginSession) { result in
                            switch result {
                            case let .success(sessionID):
                                completion(.success(sessionID))
                            case let .failure(error):
                                completion(.failure(error))
                            }
                        }
                    case let .failure(error):
                        completion(.failure(error))
                    }
                }
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    func openSession(email: String, userHash: String, completion: @escaping (Result<MegaLoginSession, MegaError>) -> Void) {
        let requestPayload = [[
            "a": "us",
            "user": email,
            "uh": userHash,
        ]]

        let request: URLRequest

        do {
            request = try URLRequest(sequence: sequence, payload: requestPayload)
        } catch {
            completion(.failure(error as! MegaError))
            return
        }

        request.execute(in: urlSession) { (result: Result<MegaLoginSession, MegaError>) in
            switch result {
            case let .success(loginSession):
                completion(.success(loginSession))
            case let .failure(error):
                completion(.failure(error))
            }
        }
    }

    struct MegaLoginSession: Decodable {
        let encryptedMasterKey: String
        let encryptedSessionID: String
        let encryptedRSAPrivateKey: String

        enum CodingKeys: String, CodingKey {
            case encryptedMasterKey = "k"
            case encryptedSessionID = "csid"
            case encryptedRSAPrivateKey = "privk"
        }
    }

    func getSessionId(passwordKey: Data, loginSession: MegaLoginSession, completion: @escaping (Result<String, MegaError>) -> Void) {
        guard let cipher = AES(key: passwordKey, blockMode: .cbc, padding: .noPadding),
              let masterKey = try? loginSession.encryptedMasterKey.base64Decoded()?.decrypt(cipher: cipher)
        else {
            completion(.failure(.decryptionFailed))
            return
        }

        guard let cipher = AES(key: masterKey, blockMode: .cbc, padding: .noPadding),
              let encryptedRSAPrivateKeyData = loginSession.encryptedRSAPrivateKey.base64Decoded()?.toUInt32Array()
        else {
            completion(.failure(.decryptionFailed))
            return
        }

        var decryptedRSAPrivateKey = Data()

        for i in stride(from: 0, to: encryptedRSAPrivateKeyData.count, by: 4) {
            guard let decryptedRSAPrivateKeyPart = try? Data(uInt32Array: [encryptedRSAPrivateKeyData[i], encryptedRSAPrivateKeyData[i + 1], encryptedRSAPrivateKeyData[i + 2], encryptedRSAPrivateKeyData[i + 3]]).decrypt(cipher: cipher) else {
                completion(.failure(.decryptionFailed))
                return
            }
            decryptedRSAPrivateKey.append(decryptedRSAPrivateKeyPart)
        }

        var j = 0
        var rsaPrivateKey: [BigUInt] = [0, 0, 0, 0]
        for i in 0 ..< 4 {
            let bitlength = (Int(decryptedRSAPrivateKey[j]) * 256) + Int(decryptedRSAPrivateKey[j + 1])
            var bytelength = bitlength / 8
            bytelength = bytelength + 2
            let data = Data(decryptedRSAPrivateKey[j + 2 ..< j + bytelength])
            rsaPrivateKey[i] = BigUInt(data)
            j = j + bytelength
        }

        let first_factor_p = rsaPrivateKey[0]
        let second_factor_q = rsaPrivateKey[1]
        let private_exponent_d = rsaPrivateKey[2]
        let rsa_modulus_n = first_factor_p * second_factor_q

        guard let encryptedSessionID = loginSession.encryptedSessionID.base64Decoded() else {
            completion(.failure(.decryptionFailed))
            return
        }

        let decryptedSessionID = BigInt(Data(encryptedSessionID)).power(BigInt(private_exponent_d), modulus: BigInt(rsa_modulus_n))

        var binarySessionID = decryptedSessionID.serialize()
        if binarySessionID[0] == 0 {
            binarySessionID = Data(binarySessionID[1...])
        }
        var hexSessionID = binarySessionID.hexEncodedString()
        if hexSessionID.count % 2 != 0 {
            hexSessionID = "0" + hexSessionID
        }

        let sessionID = Data(hexSessionID.hexDecodedData()[..<43])
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        completion(.success(sessionID))
    }
}
