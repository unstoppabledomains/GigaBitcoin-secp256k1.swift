// swift-tools-version:5.6

import PackageDescription

let dependencies: [Package.Dependency] = []

let package = Package(
    name: "GigaBitcoin-secp256k1",
    products: [
        // WARNING: These APIs should not be considered stable and may change at any time.
        .library(
            name: "GigaBitcoin-secp256k1",
            targets: [
                "GigaBitcoin-secp256k1"
            ]
        ),
    ],
    dependencies: dependencies,
    targets: [
        .target(
            name: "GigaBitcoin-secp256k1",
            dependencies: [
                "GigaBitcoin-secp256k1_bindings"
            ]
        ),
        .target(
            name: "GigaBitcoin-secp256k1_bindings",
            cSettings: [
                // Basic config values that are universal and require no dependencies.
                .define("ECMULT_GEN_PREC_BITS", to: "4"),
                .define("ECMULT_WINDOW_SIZE", to: "15"),
                // Enabling additional secp256k1 modules.
                .define("ENABLE_MODULE_ECDH"),
                .define("ENABLE_MODULE_EXTRAKEYS"),
                .define("ENABLE_MODULE_RECOVERY"),
                .define("ENABLE_MODULE_SCHNORRSIG")
            ]
        ),
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c89
)
