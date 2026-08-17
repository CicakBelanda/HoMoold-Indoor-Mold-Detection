//
//  SaveHouseSheet.swift
//  HoMoold
//
//  Sheet kecil dari FAB Home buat bikin rumah baru — cuma nama (sesuai Figma
//  "Save a house"). Lokasi & ruangan diisi belakangan lewat "Tambah Ruangan"
//  di halaman detail rumah, begitu properti ini langsung dibuka setelah disimpan.
//

import SwiftUI

struct SaveHouseSheet: View {
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @FocusState private var isNameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Save House")
                .font(.headline)

            TextField("House name, e.g. Orchid House 1", text: $name)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit(save)

            HStack(spacing: 12) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.pillSecondary)

                Button("Add", action: save)
                    .buttonStyle(.pillProminent)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .presentationDetents([.height(220)])
        .presentationDragIndicator(.visible)
        .onAppear { isNameFocused = true }
    }

    private func save() {
        guard canSave else { return }
        onSave(name.trimmingCharacters(in: .whitespaces))
        dismiss()
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            SaveHouseSheet(onSave: { _ in })
        }
}
