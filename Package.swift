// swift-tools-version:5.9
// Ce fichier ne sert qu'à compiler et tester le domaine (dossier Domain) sur un serveur Linux gratuit,
// sans interface ni SwiftData. L'app complète est construite par XcodeGen (project.yml) sur un Mac hébergé.

import PackageDescription

let package = Package(
    name: "AppSport",
    platforms: [.iOS(.v17), .macOS(.v14)],
    targets: [
        .target(name: "AppSport", path: "Domain"),
        .testTarget(name: "AppSportTests", dependencies: ["AppSport"], path: "Tests")
    ]
)
