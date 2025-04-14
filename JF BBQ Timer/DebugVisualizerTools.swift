//
//  DebugVisualizerTools.swift
//  JF BBQ Timer
//
//  Created by James Farruggia
//

import SwiftUI

// A ViewModifier to visualize UI element frames, padding, and layouts
struct DebugVisualizer: ViewModifier {
    let showFrame: Bool
    let frameColor: Color
    let showPadding: Bool
    let paddingColor: Color
    let showBackground: Bool
    let backgroundColor: Color
    let label: String?
    
    init(
        showFrame: Bool = true,
        frameColor: Color = .red,
        showPadding: Bool = true,
        paddingColor: Color = .blue.opacity(0.2),
        showBackground: Bool = false,
        backgroundColor: Color = .green.opacity(0.1),
        label: String? = nil
    ) {
        self.showFrame = showFrame
        self.frameColor = frameColor
        self.showPadding = showPadding
        self.paddingColor = paddingColor
        self.showBackground = showBackground
        self.backgroundColor = backgroundColor
        self.label = label
    }
    
    func body(content: Content) -> some View {
        content
            .background(showBackground ? backgroundColor : Color.clear)
            .overlay(
                GeometryReader { geo in
                    ZStack(alignment: .topLeading) {
                        if showFrame {
                            Rectangle()
                                .stroke(frameColor, lineWidth: 1)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                        
                        if let label = label {
                            Text(label)
                                .font(.system(size: 10))
                                .foregroundColor(frameColor)
                                .padding(2)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(3)
                        }
                    }
                }
            )
            .padding(showPadding ? 5 : 0)
            .background(showPadding ? paddingColor : Color.clear)
    }
}

// Extension to easily apply the debug visualizer
extension View {
    func debugFrame(
        _ enabled: Bool = true,
        color: Color = .red,
        showPadding: Bool = true,
        paddingColor: Color = .blue.opacity(0.2),
        showBackground: Bool = false,
        backgroundColor: Color = .green.opacity(0.1),
        label: String? = nil
    ) -> some View {
        self.modifier(
            DebugVisualizer(
                showFrame: enabled,
                frameColor: color,
                showPadding: showPadding,
                paddingColor: paddingColor,
                showBackground: showBackground,
                backgroundColor: backgroundColor,
                label: label
            )
        )
    }
}

// A struct to measure and display view dimensions
struct ViewSizeReader: View {
    var label: String
    @Binding var size: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .preference(key: SizePreferenceKey.self, value: geometry.size)
                .onPreferenceChange(SizePreferenceKey.self) { newSize in
                    size = newSize
                }
                .overlay(
                    Text("\(label): \(Int(size.width))×\(Int(size.height))")
                        .font(.system(size: 10))
                        .foregroundColor(.black)
                        .padding(2)
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(3)
                        .padding(4),
                    alignment: .topLeading
                )
        }
    }
}

struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

// Grid overlay to help with alignment
struct GridOverlay: ViewModifier {
    let spacing: CGFloat
    let color: Color
    let lineWidth: CGFloat
    
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geometry in
                ZStack {
                    // Vertical lines
                    ForEach(0..<Int(geometry.size.width / spacing) + 1, id: \.self) { i in
                        Path { path in
                            let x = CGFloat(i) * spacing
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                        }
                        .stroke(color, lineWidth: lineWidth)
                    }
                    
                    // Horizontal lines
                    ForEach(0..<Int(geometry.size.height / spacing) + 1, id: \.self) { i in
                        Path { path in
                            let y = CGFloat(i) * spacing
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                        }
                        .stroke(color, lineWidth: lineWidth)
                    }
                }
            }
        )
    }
}

extension View {
    func gridOverlay(spacing: CGFloat = 10, color: Color = .blue.opacity(0.2), lineWidth: CGFloat = 0.5) -> some View {
        self.modifier(GridOverlay(spacing: spacing, color: color, lineWidth: lineWidth))
    }
    
    // Helper for conditional modifiers
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// A global app state for managing debug visualization
class DebugVisualizerSettings: ObservableObject {
    @Published var isEnabled: Bool = false
    @Published var showFrames: Bool = true
    @Published var showPadding: Bool = true
    @Published var showBackgrounds: Bool = false
    @Published var showLabels: Bool = true
    @Published var showGrid: Bool = false
    @Published var gridSpacing: CGFloat = 20
    
    static let shared = DebugVisualizerSettings()
}
