import SwiftUI

struct LoadingIcon: View {
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 6)
                .frame(width: 80, height: 80)
            
            ArcShape()
                .trim(from: 0.0, to: 0.25)
                .stroke(Color.white, lineWidth: 6)
                .frame(width: 80, height: 80)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: rotate)
        }
        .onAppear {
            rotate = true
        }
    }
}

struct ArcShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: .degrees(0),
            endAngle: .degrees(270),
            clockwise: false
        )
        return path
    }
}
