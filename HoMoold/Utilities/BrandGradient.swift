//
//  BrandGradient.swift
//  HoMoold
//
//  Gradient mint-ke-teal yang dipakai di layar Home/Detail rumah, sesuai
//  desain Figma (HomeGradientTop #b2dfdc -> HomeGradientBottom rgba(97,121,119,0.8)).
//

import SwiftUI

extension LinearGradient {
    static var hoomoldHome: LinearGradient {
        LinearGradient(
            colors: [Color("HomeGradientTop"), Color("HomeGradientBottom")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
