//
//  RiskClassifierService.swift
//  HoMoold
//
//  Bungkus RiskClassifier.mlmodel (CreateML tabular classifier): input
//  T_out, RH_out, AC, Window, Dampness, Wall_Crack, Mold (level 0–3) ->
//  output Risk_Class (Low/Medium/High). Dipakai buat kartu "Risiko
//  Pertumbuhan Jamur" di ReportView.
//
//  Penting: pakai .cpuOnly — model Decision Tree / small ML di GPU/ANE bisa
//  bikin SIGABRT (MPS graph assertion) di beberapa device, jadi paksa CPU.
//

import CoreML
import Foundation

/// Cuma dilempar dari `init` — prediksi yang gagal balikin `nil`, bukan throw,
/// karena laporannya tetap bisa ditampilin tanpa angka prediksi.
enum RiskClassifierError: LocalizedError {
    case modelNotFound

    var errorDescription: String? {
        switch self {
        case .modelNotFound: return "RiskClassifier model not found in the bundle."
        }
    }
}

struct RiskClassifierService {
    private let model: MLModel

    /// Run dengan .cpuOnly biar gak SIGABRT di GPU/ANE.
    init() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        guard let url = Bundle.main.url(forResource: "RiskClassifier", withExtension: "mlmodelc") else {
            throw RiskClassifierError.modelNotFound
        }
        self.model = try MLModel(contentsOf: url, configuration: config)
    }

    /// Panggil model. Semua input dikumpulin dulu (cuaca + kondisi ruangan +
    /// level keparahan 0–3), baru diprediksi. Balikin string Risk_Class
    /// ("Low"/"Medium"/"High"), atau nil kalau gagal.
    func predict(
        temperature: Float,
        humidity: Float,
        hasAC: Bool,
        hasWindow: Bool,
        dampness: Bool,
        wallCrack: Bool,
        moldLevel: Int
    ) -> String? {
        predictDetailed(
            temperature: temperature, humidity: humidity, hasAC: hasAC, hasWindow: hasWindow,
            dampness: dampness, wallCrack: wallCrack, moldLevel: moldLevel
        )?.riskClass
    }

    struct Prediction {
        let riskClass: String
        /// Peluang kelas yang kepilih, 0–1. `nil` kalau model nggak ngasih
        /// dictionary probabilitas.
        let confidence: Double?
        /// Peluang SEMUA kelas, mis. `["Low": 0.02, "Medium": 0.94, "High": 0.04]`.
        /// Totalnya 1.0 — jadi confidence itu BUKAN akumulasi antar level,
        /// melainkan porsi satu level dari total itu.
        let probabilities: [String: Double]
    }

    /// Sama kayak `predict`, tapi sekalian balikin tingkat keyakinannya —
    /// dipakai kartu "Confidence Level" di halaman detail prediksi.
    func predictDetailed(
        temperature: Float,
        humidity: Float,
        hasAC: Bool,
        hasWindow: Bool,
        dampness: Bool,
        wallCrack: Bool,
        moldLevel: Int
    ) -> Prediction? {
        let dict: [String: MLFeatureValue] = [
            "T_out": MLFeatureValue(double: Double(temperature)),
            "RH_out": MLFeatureValue(double: Double(humidity) + 5),
            "AC": MLFeatureValue(int64: hasAC ? 1 : 0),
            "Window": MLFeatureValue(int64: hasWindow ? 1 : 0),
            "Dampness": MLFeatureValue(int64: dampness ? 1 : 0),
            "Wall_Crack": MLFeatureValue(int64: wallCrack ? 1 : 0),
            "Mold": MLFeatureValue(int64: Int64(moldLevel))
        ]
        guard let input = try? MLDictionaryFeatureProvider(dictionary: dict),
              let output = try? model.prediction(from: input),
              let riskClass = output.featureValue(for: "Risk_Class")?.stringValue
        else { return nil }

        let probabilities = probabilityDistribution(in: output)
        return Prediction(
            riskClass: riskClass,
            confidence: probabilities[riskClass],
            probabilities: probabilities
        )
    }

    /// Classifier CreateML biasanya nyertain satu output dictionary berisi
    /// peluang tiap kelas. Namanya nggak dihardcode ("Risk_ClassProbability")
    /// — dicari berdasarkan TIPE feature-nya, karena nama itu ikut berubah
    /// kalau model-nya di-export ulang dengan target berbeda, dan kalau salah
    /// nama hasilnya diam-diam nil, bukan error.
    private func probabilityDistribution(in output: MLFeatureProvider) -> [String: Double] {
        for name in output.featureNames {
            guard let value = output.featureValue(for: name), value.type == .dictionary else { continue }
            var result: [String: Double] = [:]
            for (key, number) in value.dictionaryValue {
                if let key = key as? String { result[key] = number.doubleValue }
            }
            if !result.isEmpty { return result }
        }
        return [:]
    }
}
