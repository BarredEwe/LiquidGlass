//
//  ContentView.swift
//  LiquidGlass Example
//
//  Created by m.grishutin on 09.12.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#if DEBUG
import SwiftUI
import LiquidGlass

@available(iOS 17.0, *)
#Preview("Simple Grid Preview") {
    SimpleAnimatedGrid()
}

struct SimpleAnimatedGrid: View {
    @State private var offset: CGFloat = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.cyan, .gray, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            GridPattern(offset: offset)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
            
            Text("PREVIEW")
                .font(.system(size: 60, weight: .bold))
                .foregroundColor(.white)
                .padding(40)
                .liquidGlassBackground(
                    blurScale: 0.1,
                    tintColor: UIColor.white.withAlphaComponent(0.1)
                )
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                offset = 50
            }
        }
    }
}

struct GridPattern: Shape {
    var offset: CGFloat
    let gridSize: CGFloat = 50
    
    var animatableData: CGFloat {
        get { offset }
        set { offset = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        var x = fmod(offset, gridSize) - gridSize
        while x < rect.width + gridSize {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
            x += gridSize
        }
        
        var y = fmod(-offset, gridSize) - gridSize
        while y < rect.height + gridSize {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
            y += gridSize
        }
        
        return path
    }
}
#endif

