// IntervalsExportTests.swift
// Vérifie le texte et la requête envoyés à intervals.icu. Remplacer AppSport par le nom du module si besoin.

import XCTest
@testable import AppSport

final class IntervalsExportTests: XCTestCase {

    private let zones = Zones(maxHR: 190, vmaKmh: 15)

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    func testLongIntervalsText() {
        let workout = RunLibrary.build(.longIntervals, variant: .threeBy8, durationMin: 55,
                                       level: .planned, zones: zones)
        let expected = """
        Échauffement
        - 15m 65-75% HR

        Série 3x
        - 8m 4:33-5:00/km Pace
        - 2m 50-65% HR

        Retour au calme
        - 10m 65-75% HR
        """
        XCTAssertEqual(IntervalsExport.workoutText(workout, maxHR: 190), expected)
    }

    func testDistanceRepeatsAndMinutesWithSeconds() {
        let workout = RunLibrary.build(.longIntervals, variant: .fiveBy1000, durationMin: 55,
                                       level: .planned, zones: zones)
        let text = IntervalsExport.workoutText(workout, maxHR: 190)
        XCTAssertTrue(text.contains("Série 5x"))
        XCTAssertTrue(text.contains("- 1km 4:33-5:00/km Pace"))
        XCTAssertTrue(text.contains("- 1m30 50-65% HR"))      // 90 s s'écrit 1m30, jamais "90m"
    }

    func testShortRepeatsUseSecondsAndNoNestedRepeat() {
        let workout = RunLibrary.build(.shortIntervals, durationMin: 37, level: .planned, zones: zones)
        let text = IntervalsExport.workoutText(workout, maxHR: 190)
        XCTAssertTrue(text.contains("- 30s "))
        XCTAssertEqual(text.components(separatedBy: "x\n").count, 2, "un seul bloc de répétition")
    }

    func testPayloadFields() throws {
        let monday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16)) ?? Date()
        let session = TrainingSession(date: monday, kind: .run(.longIntervals), durationMin: 55)
        let workout = RunLibrary.build(.longIntervals, variant: .threeBy8, durationMin: 55,
                                       level: .planned, zones: zones)
        let payload = try XCTUnwrap(IntervalsExport.payload(for: session, workout: workout,
                                                            name: "Fractionné long", maxHR: 190,
                                                            calendar: calendar))
        let data = try JSONEncoder().encode(payload)
        let json = (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        XCTAssertEqual(json["category"] as? String, "WORKOUT")
        XCTAssertEqual(json["type"] as? String, "Run")
        XCTAssertEqual(json["name"] as? String, "Fractionné long")
        XCTAssertEqual(json["start_date_local"] as? String, "2026-11-16T00:00:00")
        XCTAssertEqual(json["external_id"] as? String, "appsport-" + session.id.uuidString.lowercased())
        XCTAssertTrue((json["description"] as? String ?? "").hasPrefix("Échauffement"))
    }

    func testBikeIsARideAndStrengthIsNotSent() {
        let workout = BikeLibrary.build(durationMin: 60, level: .planned, zones: zones)
        let bike = TrainingSession(date: Date(), kind: .bike, durationMin: 60)
        XCTAssertEqual(IntervalsExport.payload(for: bike, workout: workout, name: "Vélo", maxHR: 190)?.type, "Ride")

        let strength = TrainingSession(date: Date(), kind: .strength(.legs, .home), durationMin: 45)
        XCTAssertNil(IntervalsExport.payload(for: strength, workout: workout, name: "Muscu", maxHR: 190))
    }
}
