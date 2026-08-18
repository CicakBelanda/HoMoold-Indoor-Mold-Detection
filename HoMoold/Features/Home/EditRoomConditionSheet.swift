//
//  EditRoomConditionSheet.swift
//  HoMoold
//
//  Ubah checklist kondisi ruangan (AC/Jendela/Lembap/Retak Dinding) yang
//  sudah tersimpan — dibuka dari context menu kartu ruangan di PropertyDetailView.
//  Gak ngubah temuan jamur/skor risiko, cuma kondisi manual ini.
//

import SwiftUI

struct EditRoomConditionSheet: View {
    let room: RoomInspection
    let onSave: (_ hasAC: Bool, _ hasWindow: Bool, _ dampness: Bool, _ wallCrack: Bool) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var hasAC: Bool
    @State private var hasWindow: Bool
    @State private var dampness: Bool
    @State private var wallCrack: Bool

    init(room: RoomInspection, onSave: @escaping (Bool, Bool, Bool, Bool) -> Void) {
        self.room = room
        self.onSave = onSave
        _hasAC = State(initialValue: room.hasAC)
        _hasWindow = State(initialValue: room.hasWindow)
        _dampness = State(initialValue: room.dampness)
        _wallCrack = State(initialValue: room.wallCrack)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Dampness", isOn: $dampness)
                    Toggle("Wall crack", isOn: $wallCrack)
                    Toggle("Air conditioner", isOn: $hasAC)
                    Toggle("Window", isOn: $hasWindow)
                } header: {
                    Text("Room Condition")
                }
            }
            .navigationTitle(room.roomType.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(hasAC, hasWindow, dampness, wallCrack)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let room = RoomInspection(
        roomType: .bedroom, riskLevel: .medium, riskScore: 52, findings: [],
        hasAC: true, hasWindow: true, dampness: false, wallCrack: false, date: Date()
    )
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            EditRoomConditionSheet(room: room, onSave: { _, _, _, _ in })
        }
}
