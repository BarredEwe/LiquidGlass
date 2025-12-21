<p align="center">
  <img src="Docs/Logo.png" width="380" alt="LiquidGlass logo" />
</p>

> **Metal-powered frosted glass effect with real-time background blur for SwiftUI and UIKit**

A Swift library that creates liquid glass visual effects using custom Metal shaders. Automatically captures and blurs the view hierarchy behind UI elements without manual screenshot management.

<p align="center">
  <a href="https://swiftpackageindex.com/BarredEwe/LiquidGlass"><img src="https://img.shields.io/badge/Swift_Package-Compatible-5E5E5E?style=for-the-badge&logo=swift"/></a>
  <img src="https://img.shields.io/badge/iOS‑14%2B-blue?style=for-the-badge&logo=apple"/>
  <img src="https://img.shields.io/badge/Swift‑5.9-orange?style=for-the-badge&logo=swift"/>
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge"/>
</p>

---

## What is LiquidGlass?

LiquidGlass is an iOS library that creates a translucent frosted glass effect with blur and refraction. Unlike standard `UIVisualEffectView`, this implementation uses custom Metal shaders and view hierarchy capturing to achieve more advanced visual effects with fine-grained control over update frequency and appearance.

## ✨ Features

|                              |                                                                                                    |
| ---------------------------- | -------------------------------------------------------------------------------------------------- |
| 🔍 **Automatic capture**      | Background is captured automatically – just drop `liquidGlassBackground` on any view.           |
| ⚡ **Real‑time rendering**    | Optimised `MTLTexture` snapshots + lazy redraw; redraws only when the background actually changes. |
| 🛠 **Flexible update modes** | `.continuous`, `.once`, `.manual` via the `updateMode` parameter.                    |
| 🧩 **SwiftUI + UIKit**       | Works seamlessly in both frameworks with native APIs and shared Metal backend.                                            |
| 💤 **Battery‑friendly**      | MTKView stays paused until the provider notifies it – no wasted frames.                            |
| 🎨 **Customizable shader**   | Modify Metal shader code to adjust blur, refraction, and visual effects.                           |

## 🛠 Installation

Add *LiquidGlass* through Swift Package Manager:

```
https://github.com/BarredEwe/LiquidGlass.git
```

Or via **Xcode → File → Add Package Dependencies…**  
Select ***LiquidGlass*** and you're done.

## 🚀 Quick Start

### SwiftUI

```
import SwiftUI
import LiquidGlass

Button("Glass Text") { }
    .liquidGlassBackground(cornerRadius: 60)
```

### UIKit

```
import UIKit
import LiquidGlass

// Using extension (recommended)
button.addLiquidGlassBackground(cornerRadius: 25)

// Or using LiquidGlassUIView directly
let glassView = LiquidGlassUIView(cornerRadius: 30, blurScale: 0.8)
containerView.addSubview(glassView)
```

## How It Works

LiquidGlass uses a four-stage pipeline to achieve the glass effect:

1. **Hierarchy Capture** — `HierarchySnapshotCapturer` renders the entire view hierarchy above the glass view into a `CGImage`
2. **Texture Creation** — `BackgroundTextureProvider` converts the image to `MTLTexture` and applies GPU-based blur
3. **Metal Rendering** — `MetalShaderView.Coordinator` renders the effect through `MTKView` with custom fragment shader
4. **Update Management** — Depending on `updateMode`, the background updates automatically or on-demand


## 🖼 Examples

### SwiftUI Example

<table>
<tr>
<td width="50%">
  
```
import SwiftUI
import LiquidGlass

struct ContentView: View {
    var body: some View {
        ZStack {
            AnimatedColorsMeshGradientView()

            VStack(spacing: 20) {
                Text("Liquid Glass Button")
                    .font(.title.bold())
                    .foregroundColor(.white)

                Button("Click Me 🔥") {
                    print("Tapped")
                }
                .foregroundStyle(.white)
                .font(.headline)
                .padding()
                .liquidGlassBackground(cornerRadius: 60)
            }
        }
    }
}
```
</td>

<td width="50%" align="center">
  <img src="Docs/Example.gif" width="340" alt="LiquidGlass live example" />
</td>
</tr>
</table>

### UIKit Example

```
import UIKit
import LiquidGlass

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let button = UIButton(type: .system)
        button.setTitle("Glass Button", for: .normal)
        button.setTitleColor(.white, for: .normal)
        
        // Add liquid glass background
        button.addLiquidGlassBackground(
            cornerRadius: 25,
            updateMode: .continuous(interval: 0.1),
            blurScale: 0.7,
            tintColor: .white.withAlphaComponent(0.1)
        )
        
        view.addSubview(button)
        // ... setup constraints
    }
}
```

## ⚙️ Update Modes

| Mode                     | What it does                              | Best for                                    |
| ------------------------ | ----------------------------------------- | ------------------------------------------- |
| `.continuous(interval:)` | Captures every *n* seconds.               | Animating backgrounds, parallax, fancy UIs. |
| `.once`                  | Captures exactly one frame.               | Static dialogs, settings sheets.            |
| `.manual`                | Capture only when you call `invalidate()` | Power‑saving, custom triggers.              |

### SwiftUI

```
Button("Glass Button") { }
    .liquidGlassBackground(
        cornerRadius: 20,
        updateMode: .continuous(interval: 0.1),
        blurScale: 0.5
    )
```

### UIKit

```
// Using extension
button.addLiquidGlassBackground(updateMode: .manual)

// Manual invalidation
button.liquidGlassBackground?.invalidateBackground()

// Using LiquidGlassUIView directly
let glassView = LiquidGlassUIView(updateMode: .once)
glassView.invalidateBackground() // for manual updates
```

## 🎛 API Reference

### SwiftUI Modifier

```
.liquidGlassBackground(
    cornerRadius: CGFloat = 20,                          // Corner radius
    updateMode: SnapshotUpdateMode = .continuous(),      // Update frequency
    blurScale: CGFloat = 0.3,                            // Blur intensity (0.0-1.0)
    tintColor: UIColor = .white.withAlphaComponent(0.1) // Tint color overlay
)
```

### LiquidGlassUIView

```
// Initialization
let glassView = LiquidGlassUIView(
    cornerRadius: 20,
    updateMode: .continuous(),
    blurScale: 0.5,
    tintColor: .gray.withAlphaComponent(0.2)
)

// Properties (all animatable with UIView.animate)
glassView.cornerRadius = 25
glassView.blurScale = 0.8
glassView.tintColor = .blue.withAlphaComponent(0.1)
glassView.updateMode = .manual

// Methods
glassView.invalidateBackground()  // Force update
```

### UIView Extensions

```
// Add glass background (fills entire view)
view.addLiquidGlassBackground(cornerRadius: 20)

// Add glass background with custom frame
view.addLiquidGlassBackground(
    frame: CGRect(x: 0, y: 0, width: 200, height: 50),
    cornerRadius: 25
)

// Access glass backgrounds
let glassView = view.liquidGlassBackground        // First glass view
let allGlassViews = view.liquidGlassBackgrounds   // All glass views

// Remove glass backgrounds
view.removeLiquidGlassBackgrounds()
```

## 🎨 Shader Customization

Modify `Sources/LiquidGlass/Shaders/LiquidGlassShader.metal` to customize the visual effect:

- **`sampleBackground()`** — Distort UV coordinates, add wave/ripple effects
- **`postProcess()`** — Adjust saturation, add vignette, chromatic aberration, bloom

### Example Modification

```
// In LiquidGlassShader.metal
float3 sampleBackground(float2 uv, texture2d<float> bgTexture, sampler bgSampler) {
    // Add wave distortion
    float wave = sin(uv.y * 10.0 + uniforms.time) * 0.01;
    uv.x += wave;
    
    return bgTexture.sample(bgSampler, uv).rgb;
}
```

## 📈 Performance

**Optimizations:**
- Snapshot covers only the area behind the glass – minimal memory footprint
- Layers above the glass are never hidden → no flicker
- Lazy redraw means nearly zero GPU usage when nothing changes
- Capture happens at reduced scale (0.8× screen scale) for memory savings
- UIKit and SwiftUI versions share the same optimized Metal backend

**Recommendations:**
- Use `.once` for static UI (dialogs, modals)
- Use `.continuous(interval: 0.05)` (≈20 FPS) for animated backgrounds
- Avoid many simultaneous glass views
- Test on real devices, not just simulator

## 📱 Requirements

- iOS 14.0+
- Swift 5.9+
- Xcode 15.0+
- Metal-capable device

## ⚠️ Known Limitations

- **View hierarchy only** — Cannot capture other windows
- **Metal required** — Won't work on very old devices without GPU support
- **Performance** — High update frequencies may impact older devices (A9 and below)
- **SwiftUI layout** — Background captures the underlying view hierarchy, not SwiftUI's logical structure

## 🙋‍♂️ FAQ

> **The glass doesn't update when I scroll.**  
> Use `.continuous(interval: 0.016)` (≈60 fps) or trigger `.manual`'s `invalidate()` in `scrollViewDidScroll`.

> **Can I animate the glass properties?**  
> Yes! In UIKit, all properties (`cornerRadius`, `blurScale`, `tintColor`) are animatable with `UIView.animate()`.

> **How do I use this in a table view cell?**  
> Use `.once` or `.manual` update mode for better performance, and call `invalidateBackground()` when the cell is reused.

> **Can I mix SwiftUI and UIKit glass views?**  
> Absolutely! They use the same Metal backend and work seamlessly together.

> **Why does this look different from Apple's Liquid Glass?**  
> This is an independent implementation of a similar effect. Apple's official Liquid Glass is available only in iOS 26+ and uses private APIs.

> **What's the performance impact?**  
> Minimal when using `.once` or `.manual`. With `.continuous`, expect ~5-10% GPU usage depending on update frequency and device.

## 🛡 License

MIT © 2025 • BarredEwe / Prefire

## 🙏 Acknowledgments

- Inspired by Apple's Liquid Glass design language
- Metal shaders based on GPU Gems blur techniques

---

**Made with ❤️ & Metal**
