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

enum RiskClassifierError: LocalizedError {
    case modelNotFound
    case predictionFailed

    var errorDescription: String? {
        switch self {
        case .modelNotFound: return "Model RiskClassifier tidak ditemukan di bundle."
        case .predictionFailed: return "Gagal menjalankan prediksi risiko."
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
        let dict: [String: MLFeatureValue] = [
            "T_out": MLFeatureValue(double: Double(temperature)),
            "RH_out": MLFeatureValue(double: Double(humidity) + 5),
            "AC": MLFeatureValue(int64: hasAC ? 1 : 0),
            "Window": MLFeatureValue(int64: hasWindow ? 1 : 0),
            "Dampness": MLFeatureValue(int64: dampness ? 1 : 0),
            "Wall_Crack": MLFeatureValue(int64: wallCrack ? 1 : 0),
            "Mold": MLFeatureValue(int64: Int64(moldLevel))
        ]
        guard let input = try? MLDictionaryFeatureProvider(dictionary: dict) else { return nil }
        guard let output = try? model.prediction(from: input) else { return nil }
        return output.featureValue(for: "Risk_Class")?.stringValue
    }
}
