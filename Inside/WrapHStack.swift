
import SwiftUI

struct WrapHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let items: Data
    let content: (Data.Element) -> Content
    @Binding var totalHeight: CGFloat
    
    init(items: Data, totalHeight: Binding<CGFloat>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.items = items
        self._totalHeight = totalHeight
        self.content = content
    }
    
    var body: some View {
        GeometryReader { geometry in
            self.generateContent(in: geometry)
        }
        .frame(height: totalHeight)
    }
    
    private func generateContent(in g: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        
        return ZStack(alignment: .topLeading) {
            ForEach(Array(items), id: \.self) { item in
                self.content(item)
                    .padding([.horizontal, .vertical], 4) // spacing between tags
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > g.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == items.last {
                            width = 0 // reset at end
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == items.last {
                            height = 0 // reset at end
                        }
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo -> Color in
                DispatchQueue.main.async {
                    self.totalHeight = geo.size.height
                }
                return Color.clear
            }
        )
    }
}
