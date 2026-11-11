// FitWorkoutEncoderTests.swift
// Test de non-régression : le fichier produit par l'encodeur Swift doit être identique, octet pour octet,
// au fichier de référence validé avec le décodeur officiel Garmin (fit_samples/3_fractionne_long_3x8.fit).
// Remplacer AppSport par le nom du module de l'app.

import XCTest
@testable import AppSport

final class FitWorkoutEncoderTests: XCTestCase {

    private let golden =
        "0e205c08c30000002e464954747e400000000004000100010284020284040486" +
        "0005ff00000080f850454100001a000304010006028408080701010500337838" +
        "206d696e004200001b0008fe0284010100020486030100040486050486060486" +
        "07010002000000a0bb0d000100000000e0000000f30000000202010000005307" +
        "000000000000050d0000530e00000002020000c0d40100020000000000000000" +
        "00000000040203000601000000020300000000000000000000000002040000c0" +
        "2709000100000000e0000000f3000000030431"

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    func testGoldenFile() {
        let zones = Zones(maxHR: 190, vmaKmh: 15)
        let workout = RunLibrary.build(.longIntervals, variant: .threeBy8, durationMin: 55,
                                       level: .planned, zones: zones)
        let data = FitWorkoutEncoder.encode(workout, createdAt: Date(timeIntervalSince1970: 1_794_000_000))
        XCTAssertEqual(workout.name, "3x8 min")
        XCTAssertEqual(hex(data), golden)
    }

    func testHeaderConsistency() {
        let zones = Zones(maxHR: 190, vmaKmh: 15)
        let data = [UInt8](FitWorkoutEncoder.encode(
            RunLibrary.build(.easyRun, durationMin: 45, level: .planned, zones: zones)))
        XCTAssertEqual(data[0], 14)
        XCTAssertEqual(Array(data[8..<12]), Array(".FIT".utf8))
        let dataSize = Int(data[4]) | Int(data[5]) << 8 | Int(data[6]) << 16 | Int(data[7]) << 24
        XCTAssertEqual(dataSize, data.count - 14 - 2)
    }

    func testSanitizedName() {
        XCTAssertEqual(FitWorkoutEncoder.sanitizedName("Fractionné 3×8"), "Fractionne 3x8")
        XCTAssertEqual(FitWorkoutEncoder.sanitizedName("Endurance fondamentale 45").count, 15)
    }
}
