//
//  InspectionFlowState.swift
//  HoMoold
//

import Combine
import Foundation

enum InspectionStep: Hashable {
    case roomType
    case record
    case preview
    case loading
    case report
}

@MainActor
final class InspectionFlowState: ObservableObject {
    @Published var path: [InspectionStep] = []
    @Published var propertyName: String = ""
    @Published var propertyLocation: String = ""
    @Published var roomType: RoomType?
    @Published var recordedVideoURL: URL?
    @Published var resultInspection: RoomInspection?

    func reset() {
        path = []
        propertyName = ""
        propertyLocation = ""
        roomType = nil
        recordedVideoURL = nil
        resultInspection = nil
    }
}
