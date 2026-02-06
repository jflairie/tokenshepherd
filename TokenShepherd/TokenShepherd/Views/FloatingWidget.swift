import SwiftUI

struct FloatingWidget: View {
    @ObservedObject var dataService: DataService
    @State private var isExpanded = false
    @State private var isHovering = false

    var body: some View {
        Group {
            if isExpanded {
                ExpandedView(dataService: dataService) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                    removal: .scale(scale: 0.9).combined(with: .opacity)
                ))
            } else {
                CompactView(dataService: dataService)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isExpanded = true
                        }
                    }
                    .scaleEffect(isHovering ? 1.02 : 1.0)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = hovering
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
            }
        }
        .fixedSize()
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

#Preview("Compact") {
    let service = DataService()
    return FloatingWidget(dataService: service)
        .padding(50)
        .background(Color.gray.opacity(0.5))
}

#Preview("Expanded") {
    let service = DataService()
    return FloatingWidget(dataService: service)
        .padding(50)
        .background(Color.gray.opacity(0.5))
}
