//
//  AppDataStore.swift
//  HoMoold
//
//  Sumber data buat seluruh app (Non-Goal: tidak ada backend/API — datanya
//  cuma disimpan LOKAL di device ini, bukan di server). Disimpan sebagai satu
//  file JSON di folder Application Support (termasuk foto-fotonya, dikodekan
//  jadi JPEG Data), jadi tetap ada walau app ditutup/dibuka lagi — auto-load
//  pas store dibuat, auto-save tiap kali `properties` berubah.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class AppDataStore: ObservableObject {
    @Published var properties: [KosProperty] {
        didSet { save() }
    }
    /// Diset setelah inspeksi baru disimpan, supaya Home bisa langsung membuka
    /// halaman detail rumah yang bersangkutan.
    @Published var lastSavedPropertyID: UUID?

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("properties.json")
    }()

    /// `properties: nil` (dipakai app beneran, lihat HoMooldApp/RootView) —
    /// load dari disk. Preview/test bisa passing array eksplisit biar gak
    /// kesenggol data asli di device.
    init(properties: [KosProperty]? = nil) {
        self.properties = properties ?? Self.loadFromDisk()
    }

    private static func loadFromDisk() -> [KosProperty] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        do {
            return try JSONDecoder().decode([KosProperty].self, from: data)
        } catch {
            print("[AppDataStore] gagal load data tersimpan: \(error)")
            return []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(properties)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            print("[AppDataStore] gagal nyimpen data: \(error)")
        }
    }

    /// Tambah inspeksi ke rumah yang sudah ada. `location` ditulis ulang ke
    /// properti-nya juga — no-op kalau rumahnya sudah punya lokasi (ConditionFormView
    /// cuma isi field ini kalau propertinya belum punya lokasi sama sekali).
    func attachInspection(_ inspection: RoomInspection, toExistingPropertyID propertyID: UUID, location: HomeLocation) {
        guard let index = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        properties[index].rooms.append(inspection)
        properties[index].location = location
    }

    /// Buat entri rumah baru — cuma nama (sesuai sheet "Simpan Rumah" dari FAB
    /// Home). Lokasi & ruangan nyusul belakangan lewat "Tambah Ruangan".
    @discardableResult
    func createProperty(name: String) -> UUID {
        let newProperty = KosProperty(name: name, location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
        properties.append(newProperty)
        return newProperty.id
    }

    func toggleReviewed(findingID: UUID, inRoom roomID: UUID, ofProperty propertyID: UUID) {
        guard let pIndex = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        guard let rIndex = properties[pIndex].rooms.firstIndex(where: { $0.id == roomID }) else { return }
        guard let fIndex = properties[pIndex].rooms[rIndex].findings.firstIndex(where: { $0.id == findingID }) else { return }
        properties[pIndex].rooms[rIndex].findings[fIndex].isReviewed.toggle()
    }

    func deleteProperty(id: UUID) {
        properties.removeAll { $0.id == id }
    }

    func deleteRoom(roomID: UUID, fromProperty propertyID: UUID) {
        guard let index = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        properties[index].rooms.removeAll { $0.id == roomID }
    }

    /// Ubah kondisi ruangan yang udah tersimpan (lewat EditRoomConditionSheet
    /// di halaman detail rumah) — gak ngubah findings/riskScore, cuma
    /// checklist AC/Jendela/Lembap/Retak Dinding.
    func updateRoomCondition(
        roomID: UUID, ofProperty propertyID: UUID,
        hasAC: Bool, hasWindow: Bool, dampness: Bool, wallCrack: Bool
    ) {
        guard let pIndex = properties.firstIndex(where: { $0.id == propertyID }) else { return }
        guard let rIndex = properties[pIndex].rooms.firstIndex(where: { $0.id == roomID }) else { return }
        properties[pIndex].rooms[rIndex].hasAC = hasAC
        properties[pIndex].rooms[rIndex].hasWindow = hasWindow
        properties[pIndex].rooms[rIndex].dampness = dampness
        properties[pIndex].rooms[rIndex].wallCrack = wallCrack
    }

    func renameProperty(id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let index = properties.firstIndex(where: { $0.id == id }) else { return }
        properties[index].name = trimmed
    }
}
