// FitWorkoutEncoder.swift
// App Sport : encodage d'un EnduranceWorkout (course, vélo) en fichier FIT de type workout.
// Aucune dépendance : Garmin ne fournit pas de SDK Swift officiel, et le format workout est simple.
// Le format de référence (en-tête, CRC, messages file_id, workout, workout_step) a été validé avec
// le décodeur officiel Garmin (Python) sur 4 séances. Ce fichier Swift n'est pas encore compilé.

import Foundation

enum FitWorkoutEncoder {

    // Types de base FIT
    private static let baseEnum: UInt8 = 0x00
    private static let baseUInt16: UInt8 = 0x84
    private static let baseUInt32: UInt8 = 0x86
    private static let baseString: UInt8 = 0x07

    /// Secondes entre 1970-01-01 et l'époque FIT (1989-12-31).
    private static let fitEpochOffset = 631_065_600

    /// Nom interne du workout : ASCII, 15 caractères au maximum (limite prudente, à confirmer sur Forerunner).
    static func sanitizedName(_ name: String, maxLength: Int = 15) -> String {
        let prepared = name.replacingOccurrences(of: "×", with: "x")
        let folded = prepared.folding(options: [.diacriticInsensitive, .widthInsensitive],
                                      locale: Locale(identifier: "en_US_POSIX"))
        var ascii = ""
        for u in folded.unicodeScalars where u.isASCII && u.value >= 32 && u.value < 127 {
            ascii.unicodeScalars.append(u)
        }
        return String(ascii.prefix(maxLength))
    }

    /// Encode la séance en fichier FIT workout.
    /// `manufacturer` : 255 (development) par défaut ; à passer à 1 (Garmin) si la montre refuse le fichier.
    static func encode(_ workout: EnduranceWorkout, name: String? = nil, createdAt: Date = Date(),
                       manufacturer: UInt16 = 255) -> Data {
        let records = flatten(workout.items)
        let nameBytes = Array(sanitizedName(name ?? workout.name).utf8)
        let nameSize = nameBytes.count + 1                  // + octet nul de fin de chaîne

        var data = ByteWriter()

        // file_id (local 0, global 0) : type workout (5), fabricant, produit, date de création
        data.append(definition(local: 0, global: 0, fields: [
            (0, 1, baseEnum), (1, 2, baseUInt16), (2, 2, baseUInt16), (4, 4, baseUInt32)
        ]))
        data.u8(0)
        data.u8(5)
        data.u16(manufacturer)
        data.u16(0)
        data.u32(UInt32(max(0, Int(createdAt.timeIntervalSince1970) - fitEpochOffset)))

        // workout (local 1, global 26) : sport, nombre d'étapes, nom
        data.append(definition(local: 1, global: 26, fields: [
            (4, 1, baseEnum), (6, 2, baseUInt16), (8, UInt8(nameSize), baseString)
        ]))
        data.u8(1)
        data.u8(workout.sport == .bike ? 2 : 1)             // 1 = running, 2 = cycling
        data.u16(UInt16(records.count))
        data.append(nameBytes)
        data.u8(0)

        // workout_step (local 2, global 27) : une définition commune à toutes les étapes
        data.append(definition(local: 2, global: 27, fields: [
            (254, 2, baseUInt16),   // message_index
            (1, 1, baseEnum),       // duration_type
            (2, 4, baseUInt32),     // duration_value
            (3, 1, baseEnum),       // target_type
            (4, 4, baseUInt32),     // target_value (0 avec une cible personnalisée, nombre de tours pour une répétition)
            (5, 4, baseUInt32),     // custom_target_value_low
            (6, 4, baseUInt32),     // custom_target_value_high
            (7, 1, baseEnum)        // intensity
        ]))
        for (index, record) in records.enumerated() {
            data.u8(2)
            data.u16(UInt16(index))
            switch record {
            case .step(let s):
                let f = fields(of: s)
                data.u8(f.durationType)
                data.u32(f.durationValue)
                data.u8(f.targetType)
                data.u32(0)
                data.u32(f.low)
                data.u32(f.high)
                data.u8(f.intensity)
            case .repeatFrom(let startIndex, let count):
                data.u8(6)                                  // repeat_until_steps_cmplt
                data.u32(UInt32(startIndex))                // index de la première étape du bloc
                data.u8(2)                                  // target open
                data.u32(UInt32(count))                     // nombre de tours
                data.u32(0)
                data.u32(0)
                data.u8(0)                                  // intensité active
            }
        }

        // En-tête de 14 octets : taille, protocole 2.0, profil 21.40, taille des données, ".FIT", CRC d'en-tête
        var header = ByteWriter()
        header.u8(14)
        header.u8(0x20)
        header.u16(2140)
        header.u32(UInt32(data.bytes.count))
        header.append(Array(".FIT".utf8))
        header.u16(crc16(header.bytes))

        // CRC de fin de fichier : en-tête complet + données
        var file = header.bytes + data.bytes
        let crc = crc16(file)
        file.append(UInt8(crc & 0xFF))
        file.append(UInt8(crc >> 8))
        return Data(file)
    }

    // MARK: - Étapes

    private enum StepRecord {
        case step(WorkoutStep)
        case repeatFrom(index: Int, count: Int)
    }

    /// Un bloc de répétition devient ses étapes suivies d'une étape de répétition qui renvoie à la première.
    private static func flatten(_ items: [WorkoutItem]) -> [StepRecord] {
        var out: [StepRecord] = []
        for item in items {
            switch item {
            case .step(let s):
                out.append(.step(s))
            case .repeatBlock(let count, let steps):
                let start = out.count
                steps.forEach { out.append(.step($0)) }
                out.append(.repeatFrom(index: start, count: count))
            }
        }
        return out
    }

    private static func fields(of s: WorkoutStep) -> (durationType: UInt8, durationValue: UInt32,
                                                      targetType: UInt8, low: UInt32, high: UInt32,
                                                      intensity: UInt8) {
        let durationType: UInt8
        let durationValue: UInt32
        switch s.duration {
        case .time(let seconds):
            durationType = 0                                        // time, en millisecondes
            durationValue = UInt32(max(0, seconds) * 1000)
        case .distance(let meters):
            durationType = 1                                        // distance, en centimètres
            durationValue = UInt32(max(0, meters) * 100)
        case .open:
            durationType = 5
            durationValue = 0
        }

        let targetType: UInt8
        let low: UInt32
        let high: UInt32
        switch s.target {
        case .pace(let minMps, let maxMps):
            targetType = 0                                          // speed, en mm/s
            low = UInt32(max(0, (minMps * 1000).rounded()))
            high = UInt32(max(0, (maxMps * 1000).rounded()))
        case .heartRate(let minBpm, let maxBpm):
            targetType = 1                                          // FC absolue : bpm + 100
            low = UInt32(max(0, minBpm) + 100)
            high = UInt32(max(0, maxBpm) + 100)
        case .open:
            targetType = 2
            low = 0
            high = 0
        }

        let intensity: UInt8
        switch s.intensity {
        case .active: intensity = 0
        case .rest: intensity = 1
        case .warmup: intensity = 2
        case .cooldown: intensity = 3
        case .recovery: intensity = 4
        }
        return (durationType, durationValue, targetType, low, high, intensity)
    }

    // MARK: - Bas niveau

    private struct ByteWriter {
        var bytes: [UInt8] = []
        mutating func u8(_ v: UInt8) { bytes.append(v) }
        mutating func u16(_ v: UInt16) {
            bytes.append(UInt8(truncatingIfNeeded: v))
            bytes.append(UInt8(truncatingIfNeeded: v >> 8))
        }
        mutating func u32(_ v: UInt32) {
            for shift in stride(from: 0, to: 32, by: 8) {
                bytes.append(UInt8(truncatingIfNeeded: v >> UInt32(shift)))
            }
        }
        mutating func append(_ other: [UInt8]) { bytes.append(contentsOf: other) }
    }

    /// Message de définition : petit-boutiste, un champ = (numéro, taille en octets, type de base).
    private static func definition(local: UInt8, global: UInt16,
                                   fields: [(UInt8, UInt8, UInt8)]) -> [UInt8] {
        var w = ByteWriter()
        w.u8(0x40 | local)
        w.u8(0)                     // réservé
        w.u8(0)                     // architecture : petit-boutiste
        w.u16(global)
        w.u8(UInt8(fields.count))
        for f in fields {
            w.u8(f.0)
            w.u8(f.1)
            w.u8(f.2)
        }
        return w.bytes
    }

    /// CRC-16 du format FIT.
    private static func crc16(_ bytes: [UInt8]) -> UInt16 {
        let table: [UInt16] = [0x0000, 0xCC01, 0xD801, 0x1400, 0xF001, 0x3C00, 0x2800, 0xE401,
                               0xA001, 0x6C00, 0x7800, 0xB401, 0x5000, 0x9C01, 0x8801, 0x4400]
        var crc: UInt16 = 0
        for b in bytes {
            var tmp = table[Int(crc & 0xF)]
            crc = (crc >> 4) & 0x0FFF
            crc = crc ^ tmp ^ table[Int(b & 0xF)]
            tmp = table[Int(crc & 0xF)]
            crc = (crc >> 4) & 0x0FFF
            crc = crc ^ tmp ^ table[Int((b >> 4) & 0xF)]
        }
        return crc
    }
}

// MARK: - Export par feuille de partage

enum FitExport {

    /// Écrit le fichier dans le dossier temporaire et renvoie son URL, à donner à ShareLink ou UIActivityViewController.
    static func writeTemporaryFile(session: TrainingSession, workout: EnduranceWorkout) throws -> URL {
        let names = session.fitNames(for: workout)
        let data = FitWorkoutEncoder.encode(workout, name: names.watchName)

        // Nom de fichier simple : ASCII, sans espace ni barre oblique.
        let base = String(names.fileName.dropLast(4))        // retire ".fit"
        let safe = FitWorkoutEncoder.sanitizedName(base, maxLength: 40)
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).fit")
        try data.write(to: url, options: .atomic)
        return url
    }
}

// Usage (SwiftUI) :
//
//   if case .endurance(let workout) = session.render(profile: profile, goal: goal),
//      let url = try? FitExport.writeTemporaryFile(session: session, workout: workout) {
//       ShareLink(item: url)
//   }
//
// Sur la montre : copier le fichier dans GARMIN/NewFiles (par USB, depuis un ordinateur).
// Il n'existe pas d'import de fichier workout dans Garmin Connect.
