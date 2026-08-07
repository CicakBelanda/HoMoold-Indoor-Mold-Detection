//
//  RoomNavigationTarget.swift
//  HoMoold
//
//  Nilai yang di-push ke NavigationPath buat buka Report dari dalam halaman
//  detail kos. Dibuat sebagai tipe sendiri (bukan langsung UUID) supaya tidak
//  ambigu dengan UUID kos yang juga dipush ke path yang sama.
//

import Foundation

struct RoomNavigationTarget: Hashable {
    let propertyID: UUID
    let roomID: UUID
}
