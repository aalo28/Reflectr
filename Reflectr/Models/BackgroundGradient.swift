//
//  BackgroundGradient.swift
//  Reflectr
//
//  Created by Aalohan Thileepan on 22.09.2026.
//

import SwiftUI

struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [.backgroundColor1, .backgroundColor2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    BackgroundGradient()
}
