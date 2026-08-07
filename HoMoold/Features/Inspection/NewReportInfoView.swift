//
//  NewReportInfoView.swift
//  HoMoold
//
//  Langkah terakhir flow kos-baru: isi nama & harga kos setelah lihat hasil
//  Report. Lokasi sudah didapat otomatis lewat GPS (lihat RoomTypeSelectionView),
//  jadi tidak perlu ditanya lagi di sini.
//

import SwiftUI

struct NewReportInfoView: View {
    let store: AppDataStore
    let inspection: RoomInspection
    let autoDetectedLocation: String
    let onSaved: () -> Void
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var priceText: String = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, price
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(uiColor: .tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 10)

            HStack {
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(Color(uiColor: .secondarySystemBackground), in: Circle())
                }
                .accessibilityLabel("Batal")

                Spacer()

                Text("Laporan Baru")
                    .font(.headline)

                Spacer()

                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(canSave ? Color.accentColor : Color.gray.opacity(0.35), in: Circle())
                }
                .disabled(!canSave)
                .accessibilityLabel("Simpan laporan")
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 22)

            VStack(spacing: 0) {
                row(label: "Nama Kos") {
                    TextField("Kos Anggrek 1, Blok C3", text: $name)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .name)
                }
                Divider().padding(.leading, 16)
                row(label: "Harga (Rp)") {
                    TextField("Belum diisi", text: $priceText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: .price)
                }
            }
            .padding(.horizontal, 16)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 20)

            Spacer()
        }
        .background(Color(uiColor: .systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
    }

    private func row<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.primary)
            Spacer()
            content()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 14)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let price = Int(priceText)
        let location = autoDetectedLocation.isEmpty ? "Lokasi tidak diketahui" : autoDetectedLocation
        let propertyID = store.createProperty(
            name: name.trimmingCharacters(in: .whitespaces),
            location: location,
            price: price,
            firstInspection: inspection
        )
        store.lastSavedPropertyID = propertyID
        onSaved()
    }
}

#Preview {
    NewReportInfoView(
        store: AppDataStore(),
        inspection: DummyDataFactory.seedProperties()[0].rooms[0],
        autoDetectedLocation: "Kec. Cisauk",
        onSaved: {},
        onCancel: {}
    )
}
