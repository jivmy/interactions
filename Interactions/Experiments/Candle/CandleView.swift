import SwiftUI

/// One Metal candle. The slider only changes how strongly this same flame burns.
struct CandleView: View {
    @State private var power: Double = 0.55

    var body: some View {
        ZStack {
            CandleMetalView(power: Float(power))
                .accessibilityLabel("Candle")
                .accessibilityValue(powerLabel)

            VStack {
                Spacer()
                Slider(value: $power, in: 0...1)
                    .tint(Color(red: 0.20, green: 0.14, blue: 0.10).opacity(0.55))
                    .padding(.horizontal, 62)
                    .padding(.bottom, 54)
                    .accessibilityLabel("Power")
                    .accessibilityValue(powerLabel)
            }
        }
        .ignoresSafeArea()
    }

    private var powerLabel: String {
        "\(Int((power * 100).rounded())) percent"
    }
}

#Preview {
    CandleView()
}
