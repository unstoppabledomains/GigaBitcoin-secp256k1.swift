//
//  Recovery.swift
//  GigaBitcoin/secp256k1.swift
//
//  Copyright (c) 2022 GigaBitcoin LLC
//  Distributed under the MIT software license
//
//  See the accompanying file LICENSE for information
//

import Foundation

// MARK: - secp256k1 + Recovery

/// An extension for secp256k1 with a nested Recovery enum.
public extension secp256k1 {
    enum Recovery {
        /// A representation of a secp256k1 private key used for signing.
        public struct PrivateKey: Equatable {
            /// Generated secp256k1 Signing Key.
            private let baseKey: PrivateKeyImplementation

            /// The associated public key for verifying signatures created with this private key.
            ///
            /// - Returns: The associated public key.
            public var publicKey: PublicKey {
                PublicKey(baseKey: baseKey.publicKey)
            }

            /// A data representation of the private key.
            public var dataRepresentation: Data {
                baseKey.dataRepresentation
            }

            /// Creates a random secp256k1 private key for signing.
            ///
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the private key cannot be generated.
            public init(format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(format: format)
            }

            /// Creates a secp256k1 private key for signing from a data representation.
            ///
            /// - Parameter data: A data representation of the key.
            /// - Parameter format: The key format, default is .compressed.
            /// - Throws: An error if the raw representation does not create a private key for signing.
            public init<D: ContiguousBytes>(dataRepresentation data: D, format: secp256k1.Format = .compressed) throws {
                self.baseKey = try PrivateKeyImplementation(dataRepresentation: data, format: format)
            }

            /// Determines if two private keys are equal.
            ///
            /// - Parameters:
            ///   - lhs: The left-hand side private key.
            ///   - rhs: The right-hand side private key.
            /// - Returns: True if the private keys are equal, false otherwise.
            public static func == (lhs: Self, rhs: Self) -> Bool {
                lhs.baseKey.key == rhs.baseKey.key
            }
        }

        /// A struct representing a secp256k1 public key for recovery purposes.
        public struct PublicKey {
            /// A data representation of the public key.
            public var dataRepresentation: Data { baseKey.dataRepresentation }

            /// A raw representation of the public key.
            public var rawRepresentation: secp256k1_pubkey { baseKey.rawRepresentation }

            /// Generated secp256k1 Public Key.
            private let baseKey: PublicKeyImplementation

            /// Initializes a secp256k1 public key using a data message and a recovery signature.
            /// - Parameters:
            ///   - data: The data to be hash and assumed signed.
            ///   - signature: A raw representation of the initialized signature that supports pubkey recovery.
            ///   - format: The format of the public key object.
            public init<D: DataProtocol>(
                _ data: D,
                signature: secp256k1.Recovery.ECDSASignature,
                format: secp256k1.Format = .compressed
            ) throws {
                self.baseKey = try PublicKeyImplementation(
                    SHA256.hash(data: data),
                    signature: signature,
                    format: format
                )
            }

            /// Initializes a secp256k1 public key using a hash digest and a recovery signature.
            /// - Parameters:
            ///   - digest: The hash digest assumed to be signed.
            ///   - signature: A raw representation of the initialized signature that supports pubkey recovery.
            ///   - format: The format of the public key object.
            public init<D: Digest>(
                _ digest: D,
                signature: secp256k1.Recovery.ECDSASignature,
                format: secp256k1.Format = .compressed
            ) throws {
                self.baseKey = try PublicKeyImplementation(digest, signature: signature, format: format)
            }

            /// Initializes a secp256k1 public key for recovery.
            /// - Parameter baseKey: Generated secp256k1 public key.
            init(baseKey: PublicKeyImplementation) {
                self.baseKey = baseKey
            }
        }
    }
}

/// An ECDSA (Elliptic Curve Digital Signature Algorithm) Recovery Signature
public extension secp256k1.Recovery {
    /// Recovery Signature
    struct ECDSACompactSignature {
        public let signature: Data
        public let recoveryId: Int32
    }

    struct ECDSASignature: ContiguousBytes, DataSignature {
        /// Returns the raw signature.
        public var dataRepresentation: Data

        /// Serialize an ECDSA signature in compact (64 byte) format.
        /// - Throws: If there is a failure parsing signature
        /// - Returns: a 64-byte data representation of the compact serialization
        public var compactRepresentation: ECDSACompactSignature {
            get throws {
                let context = secp256k1.Context.rawRepresentation
                let compactSignatureLength = 64
                var recoveryId = Int32()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()
                var compactSignature = [UInt8](repeating: 0, count: compactSignatureLength)

                dataRepresentation.copyToUnsafeMutableBytes(of: &recoverableSignature.data)

                guard secp256k1_ecdsa_recoverable_signature_serialize_compact(
                    context,
                    &compactSignature,
                    &recoveryId,
                    &recoverableSignature
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return secp256k1.Recovery.ECDSACompactSignature(
                    signature: Data(bytes: &compactSignature, count: compactSignatureLength),
                    recoveryId: recoveryId
                )
            }
        }

        /// Convert a recoverable signature into a normal signature.
        public var normalize: secp256k1.Signing.ECDSASignature {
            get throws {
                let context = secp256k1.Context.rawRepresentation
                var normalizedSignature = secp256k1_ecdsa_signature()
                var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

                dataRepresentation.copyToUnsafeMutableBytes(of: &recoverableSignature.data)

                guard secp256k1_ecdsa_recoverable_signature_convert(
                    context,
                    &normalizedSignature,
                    &recoverableSignature
                ).boolValue else {
                    throw secp256k1Error.underlyingCryptoError
                }

                return try secp256k1.Signing.ECDSASignature(normalizedSignature.dataValue)
            }
        }

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        public init<D: DataProtocol>(dataRepresentation: D) throws {
            guard dataRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount + 1 else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = Data(dataRepresentation)
        }

        /// Initializes ECDSASignature from the raw representation.
        /// - Parameters:
        ///   - dataRepresentation: A data representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with the dataRepresentation count
        internal init(_ dataRepresentation: Data) throws {
            guard dataRepresentation.count == 4 * secp256k1.CurveDetails.coordinateByteCount + 1 else {
                throw secp256k1Error.incorrectParameterSize
            }

            self.dataRepresentation = dataRepresentation
        }

        /// Initializes ECDSASignature from the Compact representation.
        /// - Parameter compactRepresentation: A Compact representation of the key as a collection of contiguous bytes.
        /// - Throws: If there is a failure with parsing the derRepresentation
        public init<D: DataProtocol>(compactRepresentation: D, recoveryId: Int32) throws {
            let context = secp256k1.Context.rawRepresentation
            var recoverableSignature = secp256k1_ecdsa_recoverable_signature()

            guard secp256k1_ecdsa_recoverable_signature_parse_compact(
                context,
                &recoverableSignature,
                Array(compactRepresentation),
                recoveryId
            ).boolValue else {
                throw secp256k1Error.underlyingCryptoError
            }

            self.dataRepresentation = recoverableSignature.dataValue
        }

        /// Invokes the given closure with a buffer pointer covering the raw bytes of the digest.
        /// - Parameter body: A closure that takes a raw buffer pointer to the bytes of the digest and returns the digest.
        /// - Throws: If there is a failure with underlying `withUnsafeBytes`
        /// - Returns: The signature as returned from the body closure.
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
            try dataRepresentation.withUnsafeBytes(body)
        }
    }
}

// MARK: - secp256k1 + Recovery

extension secp256k1.Recovery.PrivateKey: DigestSigner {
    public typealias Signature = secp256k1.Recovery.ECDSASignature

    ///  Generates a recoverable ECDSA signature.
    ///
    /// - Parameter digest: The digest to sign.
    /// - Returns: The recoverable ECDSA Signature.
    /// - Throws: If there is a failure producing the signature
    public func signature<D: Digest>(for digest: D) throws -> Signature {
        let context = secp256k1.Context.rawRepresentation
        var signature = secp256k1_ecdsa_recoverable_signature()

        guard secp256k1_ecdsa_sign_recoverable(
            context,
            &signature,
            Array(digest),
            Array(dataRepresentation),
            nil,
            nil
        ).boolValue else {
            throw secp256k1Error.underlyingCryptoError
        }

        return try secp256k1.Recovery.ECDSASignature(signature.dataValue)
    }
}

extension secp256k1.Recovery.PrivateKey: Signer {
    /// Generates a recoverable ECDSA signature. SHA256 is used as the hash function.
    ///
    /// - Parameter data: The data to sign.
    /// - Returns: The ECDSA Signature.
    /// - Throws: If there is a failure producing the signature.
    public func signature<D: DataProtocol>(for data: D) throws -> Signature {
        try signature(for: SHA256.hash(data: data))
    }
}
