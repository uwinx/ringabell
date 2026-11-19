import ArgumentParser
import CommonCrypto
import CryptoKit
import Foundation
import zlib

enum PushTarget: String, CaseIterable, ExpressibleByArgument {
    case pushover
}

struct PushoverConfig {
    static let tokenVar = "PUSHOVER_TOKEN"
    static let userVar = "PUSHOVER_USER"
    static let keyVar = "PUSHOVER_E2E_KEY"
    static let environmentVars = [tokenVar, userVar, keyVar]

    let token: String
    let user: String
    let key: Data
    let emergency: Bool
    let sound: String?

    static func load(file: URL?, emergency: Bool, sound: String?) throws -> PushoverConfig {
        let values = try file.map(readSecretsFile) ?? ProcessInfo.processInfo.environment
        let source = file.map { "in \($0.path)" } ?? "in the environment"
        let missing = environmentVars.filter { (values[$0] ?? "").isEmpty }
        guard missing.isEmpty else {
            throw ValidationError("--push pushover needs \(missing.joined(separator: ", ")) \(source)")
        }
        guard let key = Data(hex: values[keyVar]!), key.count == 32 else {
            throw ValidationError("\(keyVar) \(source) must be a 64-character hex string (openssl rand -hex 32)")
        }
        // Pages get a long built-in sound; normal pushes keep the user's default tone unless overridden.
        return PushoverConfig(token: values[tokenVar]!, user: values[userVar]!, key: key, emergency: emergency,
                              sound: sound ?? (emergency ? "persistent" : nil))
    }

    // KEY=VALUE lines, the same format `op inject` and `op run --env-file` use.
    private static func readSecretsFile(_ url: URL) throws -> [String: String] {
        var info = stat()
        guard stat(url.path, &info) == 0 else {
            throw ValidationError("--pushover-config '\(url.path)' does not exist")
        }
        guard info.st_uid == getuid(), info.st_mode & 0o077 == 0 else {
            throw ValidationError("--pushover-config '\(url.path)' must be owned by you and private (chmod 600)")
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw ValidationError("--pushover-config '\(url.path)' is not readable UTF-8 text")
        }
        var values: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("#"), let eq = trimmed.firstIndex(of: "=") else { continue }
            let name = trimmed[..<eq].trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "export ", with: "")
            let value = trimmed[trimmed.index(after: eq)...].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            values[name] = value
        }
        return values
    }
}

enum Pushover {
    private static let endpoint = URL(string: "https://api.pushover.net/1/messages.json")!

    // Emergency priority repeats until acknowledged on the phone, capped by Pushover at 50 retries.
    private static let emergencyRetry = 60
    private static let emergencyExpire = 3600

    static func send(title: String, body: String, url: String?, config: PushoverConfig) async -> Bool {
        do {
            var fields = [
                "token": config.token,
                "user": config.user,
                "encrypted": "1",
                "message": try PushoverCrypto.encrypt(body, key: config.key),
            ]
            if !title.isEmpty {
                fields["title"] = try PushoverCrypto.encrypt(title, key: config.key)
            }
            if let url {
                fields["url"] = try PushoverCrypto.encrypt(url, key: config.key)
            }
            if let sound = config.sound {
                fields["sound"] = sound
            }
            if config.emergency {
                fields["priority"] = "2"
                fields["retry"] = String(emergencyRetry)
                fields["expire"] = String(emergencyExpire)
            }

            var request = URLRequest(url: endpoint, timeoutInterval: 15)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formEncode(fields)

            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            guard (json?["status"] as? Int) == 1 else {
                let errors = (json?["errors"] as? [String])?.joined(separator: "; ")
                    ?? String(decoding: data, as: UTF8.self)
                fputs("ringabell: pushover rejected the message: \(errors)\n", stderr)
                return false
            }
            return true
        } catch {
            fputs("ringabell: pushover send failed: \(error.localizedDescription)\n", stderr)
            return false
        }
    }

    private static func formEncode(_ fields: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = fields.map { key, value in
            "\(key)=\(value.addingPercentEncoding(withAllowedCharacters: allowed)!)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }
}

// Pushover's E2E scheme, per field: base64(iv || AES-256-CBC(gzip(plaintext)) || HMAC-SHA256(iv || ciphertext)),
// with the same 256-bit key for AES and HMAC.
enum PushoverCrypto {
    enum Failure: Error {
        case gzip(Int32)
        case aes(CCCryptorStatus)
    }

    static func encrypt(_ plaintext: String, key: Data) throws -> String {
        var rng = SystemRandomNumberGenerator()
        let iv = Data((0..<kCCBlockSizeAES128).map { _ in UInt8.random(in: .min ... .max, using: &rng) })
        let ciphertext = try aesCBC(try gzip(Data(plaintext.utf8)), key: key, iv: iv)
        let mac = HMAC<SHA256>.authenticationCode(for: iv + ciphertext, using: SymmetricKey(data: key))
        return (iv + ciphertext + Data(mac)).base64EncodedString()
    }

    static func gzip(_ data: Data) throws -> Data {
        var stream = z_stream()
        // windowBits + 16 makes zlib emit a gzip header and trailer instead of a zlib wrapper.
        var status = deflateInit2_(&stream, Z_BEST_COMPRESSION, Z_DEFLATED, MAX_WBITS + 16, 8,
                                   Z_DEFAULT_STRATEGY, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
        guard status == Z_OK else { throw Failure.gzip(status) }
        defer { deflateEnd(&stream) }

        var input = [UInt8](data)
        var output = [UInt8](repeating: 0, count: Int(deflateBound(&stream, uLong(input.count))))
        status = input.withUnsafeMutableBufferPointer { inBuf in
            output.withUnsafeMutableBufferPointer { outBuf in
                stream.next_in = inBuf.baseAddress
                stream.avail_in = uInt(inBuf.count)
                stream.next_out = outBuf.baseAddress
                stream.avail_out = uInt(outBuf.count)
                return deflate(&stream, Z_FINISH)
            }
        }
        guard status == Z_STREAM_END else { throw Failure.gzip(status) }
        return Data(output.prefix(Int(stream.total_out)))
    }

    private static func aesCBC(_ data: Data, key: Data, iv: Data) throws -> Data {
        let capacity = data.count + kCCBlockSizeAES128
        var output = Data(count: capacity)
        var written = 0
        let status = output.withUnsafeMutableBytes { out in
            data.withUnsafeBytes { input in
                key.withUnsafeBytes { keyBytes in
                    iv.withUnsafeBytes { ivBytes in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding),
                                keyBytes.baseAddress, key.count, ivBytes.baseAddress,
                                input.baseAddress, data.count, out.baseAddress, capacity, &written)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw Failure.aes(status) }
        return output.prefix(written)
    }
}

extension Data {
    init?(hex: String) {
        guard hex.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}
