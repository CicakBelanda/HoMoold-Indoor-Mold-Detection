//
//  ConditionFormView.swift
//  HoMoold
//
//  Figma 1339:7292 ("Condition Page") — layar PERTAMA dari alur "Add new Room",
//  langsung kebuka pas user tap kartu "Add new Room".
//
//  Bukan `Form`. Desainnya: latar `#f7f7f7`, label section tebal di LUAR kartu,
//  kartu putih radius 20 isinya baris-baris checkbox. `Form` bakal maksa gaya
//  inset-grouped-nya sendiri (header abu kecil huruf kapital, inset baris beda),
//  jadi ini disusun manual pakai ScrollView.
//
//  Tombol bawah punya dua perilaku, tergantung "Visible Mold":
//    - kecentang  -> "Next", buka guidance lalu kamera (fotonya itu bahan utama
//                    buat ngukur luas jamur)
//    - nggak      -> "Submit", langsung ke loading + report (nggak ada yang
//                    perlu difoto)
//
//  Cuaca (suhu/kelembapan) diambil DIAM-DIAM di background — di desainnya nggak
//  ada section cuaca, dan nambahin satu lagi bikin layarnya kepanjangan. Yang
//  muncul cuma catatan kecil kalau izin lokasinya ditolak, karena itu satu-satunya
//  keadaan yang user perlu tau + bisa dia benerin.
//

import SwiftUI
import CoreLocation

struct ConditionFormView: View {
    @ObservedObject var flow: InspectionFlowState

    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isNameFocused: Bool
    private let weatherService = WeatherService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                typeField
                nameField
                availabilitySection
                conditionsSection

                if locationService.isPermissionDenied {
                    locationDeniedNote
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 24)
            // Tap di area kosong buat nutup keyboard. `Form` dulu ngasih ini
            // gratis; ScrollView nggak, jadi harus eksplisit. Ditempel ke
            // KONTEN, bukan ke latar — latarnya sekarang bukan view yang bisa
            // ditap.
            .contentShape(.rect)
            .onTapGesture { isNameFocused = false }
        }
        // Geser buat nutup keyboard, ngikutin jari (`.interactively`), bukan
        // `.immediately` yang ngilangin keyboard begitu layar kesenggol dikit.
        .scrollDismissesKeyboard(.interactively)
        // Latar lewat `.background`, BUKAN sibling di dalam ZStack.
        //
        // Ini juga yang bikin keyboard-nya kerasa aneh: begitu ada sibling yang
        // `ignoresSafeArea`, ScrollView-nya kehilangan inset safe area — dan
        // keyboard ITU salah satu inset safe area. Jadi pas keyboard naik,
        // kontennya nggak digeser dan field yang lagi diketik bisa ketutupan.
        .background(Theme.color.surfaceMuted.ignoresSafeArea())
        .navigationTitle("Room")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }

            // Aksesori "Done" di atas keyboard — pola standar iOS. Tanpa ini
            // satu-satunya jalan nutup keyboard cuma tap di tempat kosong, dan
            // itu nggak keliatan sebagai pilihan.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isNameFocused = false }
            }
        }
        .task { await refreshLocationAndWeather() }
        .safeAreaInset(edge: .bottom) {
            Button(primaryButtonTitle) { advance() }
                .buttonStyle(.pillProminent)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
        }
    }

    // MARK: - Fields

    private var typeField: some View {
        labeledSection("Type") {
            // Menu, bukan Picker(.wheel)/NavigationLink — di Figma field-nya
            // pipih dengan chevron.up.chevron.down di kanan, dan itu tampilan
            // menu-style picker.
            Menu {
                Picker("Type", selection: $flow.roomType) {
                    ForEach(RoomType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            } label: {
                HStack {
                    Text(flow.roomType.rawValue)
                        .font(Theme.font.body)
                        .foregroundStyle(Theme.color.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.up.chevron.down")
                        .font(Theme.font.body)
                        .foregroundStyle(Theme.color.textSecondary)
                }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(
                    Theme.color.fieldFill,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
            }
        }
    }

    private var nameField: some View {
        labeledSection("Name") {
            TextField("Input room name...", text: $flow.roomName)
                .font(Theme.font.body)
                .focused($isNameFocused)
                .submitLabel(.done)
                .onSubmit { isNameFocused = false }
                .padding(.horizontal, 18)
                .frame(height: 56)
                .background(
                    Theme.color.fieldFill,
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
    }

    private var availabilitySection: some View {
        labeledSection("Availability") {
            CheckboxCard {
                CheckboxRow(title: "AC", isOn: $flow.hasAC)
                Divider()
                CheckboxRow(title: "Window", isOn: $flow.hasWindow)
            }
        }
    }

    private var conditionsSection: some View {
        labeledSection("Conditions") {
            CheckboxCard {
                CheckboxRow(title: "Dampness", isOn: $flow.dampness)
                Divider()
                CheckboxRow(title: "Wall Crack", isOn: $flow.wallCrack)
                Divider()
                CheckboxRow(title: "Visible Mold", isOn: $flow.hasVisibleMold)
            }

            Button("What does mold look like?") {
                flow.path.append(.moldReference)
            }
            .font(Theme.font.footnote)
            .padding(.horizontal, 10)
            .padding(.top, 2)
        }
    }

    /// Label tebal di luar kartu + isinya — pola yang keulang 4x di desainnya.
    private func labeledSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.font.headline)
                .foregroundStyle(Theme.color.textPrimary)
                .padding(.horizontal, 6)

            content()
        }
    }

    /// iOS nggak mau nanya izin lokasi dua kali, jadi kalau udah ditolak
    /// satu-satunya jalan balik itu lewat Settings. Ditulis apa adanya + dibilang
    /// laporannya tetap jalan, biar user nggak ngerasa kejebak.
    private var locationDeniedNote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Location is off, so the local temperature and humidity can't be included. The report still works without them.")
                .font(Theme.font.footnote)
                .foregroundStyle(Theme.color.textSecondary)

            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .font(Theme.font.footnote)
        }
        .padding(.horizontal, 10)
    }

    // MARK: - Actions

    private var primaryButtonTitle: String {
        flow.hasVisibleMold ? "Next" : "Submit"
    }

    private func advance() {
        isNameFocused = false
        if flow.hasVisibleMold {
            flow.path.append(.guidance)
        } else {
            flow.path.append(.loading)
        }
    }

    /// Ambil GPS SEKALI, lalu pakai koordinatnya buat dua hal: cuaca (input
    /// model) dan nama wilayah (ditampilin di kartu rumah).
    ///
    /// Nama wilayahnya sempat kelewat: waktu form ini ditulis ulang, yang
    /// dipanggil cuma `fetchCurrentCoordinate`, jadi `flow.location` nggak pernah
    /// keisi dan tiap rumah kebaca "No location yet" walaupun izin lokasinya
    /// udah dikasih.
    private func refreshLocationAndWeather() async {
        guard let coord = await locationService.fetchCurrentCoordinate() else { return }

        // Cuma isi kalau rumahnya emang belum punya lokasi — jangan nimpa yang
        // udah kesimpan cuma karena ruangan baru diperiksa di tempat lain.
        if flow.location.isEmpty, let place = await locationService.placemark(for: coord) {
            flow.location = place
        }

        do {
            let snap = try await weatherService.fetchCurrent(lat: coord.latitude, lon: coord.longitude)
            flow.temperature = snap.temperature
            flow.humidity = snap.humidity
        } catch {
            // Cuaca itu bonus, bukan syarat — gagal di sini nggak perlu
            // diributin ke user, laporannya tetap bisa dibikin.
            locationService.errorMessage = nil
        }
    }
}

#Preview {
    let property = KosProperty(name: "House Assetti", location: HomeLocation(region: "", city: "", district: ""), price: nil, rooms: [])
    return NavigationStack {
        ConditionFormView(flow: InspectionFlowState(existingProperty: property))
    }
}
