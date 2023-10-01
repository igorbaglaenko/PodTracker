//
//  ActivationView.swift
//  PodTracker
//
//  Created by Igor Baglaenko on 2023-09-16.
//

import SwiftUI
import CommonCrypto
import CryptoKit

struct ActivationView: View {
    @EnvironmentObject var podData: PodGlobalData
    @State private var activationCode =  ""
    @State private var result         = ""
    @State private var prompt         = "Please copy activation code from email"
    let password                      = "A20FCRD1FDFBB797"
    let vector                        = "B46C7T5FBY174BDF"
 
    let addr     = "z7w9HXO7zNoW66AH"
    
    var body: some View {
        if !podData.showActivation {
            ContentView()
        }
        else {
            //NavigationStack(path: $path) {
            VStack {
                Image("logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                
                Text("Welcome to the PodTracker")
                    .font(.title2)
                //          padding ()
                TextField(prompt, text: $activationCode, onCommit: {
                    let keyData: [UInt8] = Array(password.utf8)
                    let ivData:  [UInt8] = Array(vector.utf8)
                    
                    if activationCode.count == 16 {
                        let encoddedBytes = decompressAray(inString: activationCode)
                        let decodedBytes = try! decryptAESCFB(key: keyData, iv: ivData, cyphertext: encoddedBytes)
                        if decodedBytes.count == 12 {
                            var i = 0
                            var macAddr = [UInt8](repeating: 0, count: 17)
                            for byte in decodedBytes {
                                if byte < 48 || (byte > 57 && byte < 65) || byte > 70 {
                                    break;
                                }
                                macAddr[i] = byte
                                i += 1
                                if (i + 1) % 3 == 0 && i < 17 {
                                    macAddr[i] = 0x3A
                                    i += 1
                                }
                            }
                            if i == 17 {
                                result  = String(decoding: macAddr, as: UTF8.self)
                            }
                        }
                    }
                    if !result.isEmpty {
                        podData.setDevId(devid: result)
                    }
                })
                .multilineTextAlignment(TextAlignment.center)
                .font(.headline)
                .onSubmit {
                    if result.isEmpty {
                        activationCode = ""
                        prompt = "incorrect code, try again please"
                    }
                }
            }
        }
    }
    func decryptAESCFB(key: [UInt8], iv: [UInt8], cyphertext: [UInt8]) throws -> [UInt8] {
        precondition([kCCKeySizeAES256, kCCKeySizeAES192, kCCKeySizeAES128].contains(key.count))
        assert(iv.count == kCCBlockSizeAES128)

        var cryptorQ: CCCryptorRef? = nil
        var err = CCCryptorCreateWithMode(
            CCOperation(kCCDecrypt),
            CCMode(kCCModeCFB),
            CCAlgorithm(kCCAlgorithmAES),
            CCPadding(ccNoPadding),
            iv,
            key, key.count,
            nil, 0,         // tweak
            0,              // rounds
            0,              // options
            &cryptorQ
        )
        guard err == kCCSuccess else { fatalError() }
        let cryptor = cryptorQ
        
        defer {
            let junk = CCCryptorRelease(cryptor)
            assert(junk == kCCSuccess)
        }

        let plaintextMaxCount = CCCryptorGetOutputLength(cryptor, cyphertext.count, true)
        var plaintext = [UInt8](repeating: 0, count: plaintextMaxCount)
        var plaintextCount = 0
        err = CCCryptorUpdate(
            cryptor,
            cyphertext, cyphertext.count,
            &plaintext, plaintext.count,
            &plaintextCount
        )
        guard err == errSecSuccess else { fatalError() }

        // In the general case you might need to deal with odd output sizes and
        // potentially call `CCCryptorFinal` but that’s never necessary for CFB
        // because it acts kinda like a stream cypher.
        assert(plaintextCount == plaintext.count)

        return plaintext
    }}
func decodeByte(inByte data:UInt8, position shift: Int ) -> UInt32 {
    
    var result: UInt32 = 0
    if data == 0x2B {
        result = 62
    }
    else if data == 0x2F {
        result = 63
    }
    else if data >= 0x30 && data <= 0x39 {
        result = UInt32(data) - 48 + 52
    }
    else if data >= 0x41 && data <= 0x5A {
        result = UInt32(data) - 0x41
    }
    else if data >= 0x61 && data <= 0x7A {
        result = UInt32(data) - 0x61 + 26
    }
    result = result << shift
    return result
}
func decompressAray (inString activationCode: String) -> [UInt8] {
    let keyData: [UInt8] = Array(activationCode.utf8)
    var outBytes = [UInt8]()
    var indx = 0
    for i in stride(from: 0, to: 12, by: 3) {
        var outData: UInt32 = 0
        for j in 0...3 {
            outData |= decodeByte(inByte: keyData[indx], position: 26 - j * 6)
            indx += 1
        }
        let d = withUnsafeBytes(of: outData.bigEndian, Array.init)
        outBytes.insert(contentsOf: d, at: i)
    }
    return Array(outBytes.prefix(12))
}

struct ActivationView_Previews: PreviewProvider {
    static var previews: some View {
        ActivationView()
            .environmentObject(PodGlobalData())
    }
}

//        // Decrypt
//        let sealedBoxRestored = try! AES.GCM.SealedBox( )(nonce: sealedBox.nonce, ciphertext: sealedBox.ciphertext, tag: sealedBox.tag)
//        let decrypted = try! AES.GCM.open(sealedBoxRestored, using: key)

//


// CCCryptorCreate(op: Operation., alg: kCCAlgorithmAES, UInt32(kCCModeCFB), keyData, <#T##keyLength: Int##Int#>, <#T##iv: UnsafeRawPointer!##UnsafeRawPointer!#>, <#T##cryptorRef: UnsafeMutablePointer<CCCryptorRef?>!##UnsafeMutablePointer<CCCryptorRef?>!#>)
