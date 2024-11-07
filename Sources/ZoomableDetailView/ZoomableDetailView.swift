import SwiftUI

public class ZoomableImageViewModel: ObservableObject {
    @Published var imageSelected: Image? = nil
    @Published var imageIdSelected: String? = nil
    @Published var presentingImage = false
    
    let namespace: Namespace.ID
    
    init(namespace: Namespace.ID) {
        self.namespace = namespace
    }
}

struct ImageFailedToLoadView: View {
    var body: some View {
        ZStack {
            Color.secondary
            Image(systemName: "exclamationmark.icloud")
                .font(.title)
        }
        .opacity(0.5)
    }
}

public struct ZoomableSquareImageViaAsyncFn: View {
    @ObservedObject var vm: ZoomableImageViewModel
        
    enum FnState {
        case not_called_yet
        case calling
        case finishedWith(Image)
        case failed
    }
    
    @State private var state = FnState.not_called_yet
    
    let async_fn: () async -> Image?
    let id: String
    
    let animation = Animation.easeInOut(duration: 0.2)
    
    public init(vm: ZoomableImageViewModel, async_fn: @escaping () async -> Image?, id: String) {
        self.vm = vm
        self.async_fn = async_fn
        self.id = id
    }
    
    public var body: some View {
        switch state {
        case .not_called_yet, .calling:
            Color.clear
                .aspectRatio(contentMode: .fit)
                .overlay {
                    ProgressView()
                        .onAppear {
                            Task {
                                self.state = .calling
                                if let image = await async_fn() {
                                    self.state = .finishedWith(image)
                                } else {
                                    self.state = .failed
                                }
                            }
                        }
                }
        case .finishedWith(let image):
            Color.clear
                .aspectRatio(contentMode: .fit)
                .matchedGeometryEffect(id: vm.imageIdSelected == id ? "base" : UUID().uuidString, in: vm.namespace, isSource: true)
                .overlay {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onChange(of: vm.imageIdSelected) {
                            if vm.imageIdSelected == id {
                                vm.imageSelected = image
                                withAnimation(animation) {
                                    vm.presentingImage = true
                                }
                            }
                        }
                }
                .clipped()
                .opacity(vm.imageIdSelected == id ? 0 : 1)
                .contentShape(Rectangle())
                .onTapGesture {
                    if vm.imageIdSelected == nil {
                        vm.imageIdSelected = id
                    }
                }
        case .failed:
            Color.clear
                .aspectRatio(contentMode: .fit)
                .overlay {
                    ImageFailedToLoadView()
                }
        }
    }
}

struct ZoomableSquareAsyncImage: View {
    let url: URL
    
    @ObservedObject var vm: ZoomableImageViewModel
    
    let animation = Animation.easeInOut(duration: 0.2)
    
    var body: some View {
        Color.clear
            .aspectRatio(contentMode: .fit)
            .matchedGeometryEffect(id: vm.imageIdSelected == url.absoluteString ? "base" : UUID().uuidString, in: vm.namespace, isSource: true)
            .overlay {
                AsyncImage(url: url, content: { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .onChange(of: vm.imageIdSelected) {
                            if vm.imageIdSelected == url.absoluteString {
                                vm.imageSelected = image
                                withAnimation(animation) {
                                    vm.presentingImage = true
                                }
                            }
                        }
                }) {
                    ProgressView()
                }
            }
            .clipped()
            .opacity(vm.imageIdSelected == url.absoluteString ? 0 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                if vm.imageIdSelected == nil {
                    vm.imageIdSelected = url.absoluteString
                }
            }
    }
}

public struct WithZoomableDetailViewOverlay<Content: View>: View {
    let content: (ZoomableImageViewModel) -> Content
    @StateObject var vm: ZoomableImageViewModel
    
    @State private var offset = CGSize.zero
    @State private var dragIsTracking = false
    
    @State private var lastScaleValue = 1.0
    @State private var scale = 1.0
    @State private var anchor: UnitPoint = .center
    @State private var anchorDiffX = 0.0
    @State private var anchorDiffY = 0.0
    
    let animation = Animation.easeInOut(duration: 0.2)
    
    var distance: Double { sqrt(offset.width * offset.width + offset.height * offset.height) }

    var detailViewBackgroundOpacity: Double {
        if vm.presentingImage {
            let maximumDistance: Double = 200
            return max(0, maximumDistance - distance) / maximumDistance
        } else {
            return 0
        }
    }
    
    var computedAnchor: UnitPoint {
        .init(x: anchor.x + anchorDiffX, y: anchor.y + anchorDiffY)
    }
    
    var minAnchorDiffX: CGFloat { -anchor.x }
    var maxAnchorDiffX: CGFloat { 1 - anchor.x }
    var minAnchorDiffY: CGFloat { -anchor.y }
    var maxAnchorDiffY: CGFloat { 1 - anchor.y }
    
    var detailViewScaleEffect: Double {
        if vm.presentingImage {
            let maximumDistance: Double = 1000
            return max(max(0, maximumDistance - distance) / maximumDistance, 0.8)
        } else {
            return 1
        }
    }
    
    func dismissDetailView() {
        if vm.presentingImage {
            withAnimation(animation) {
                vm.presentingImage = false
                offset = CGSize.zero
                lastScaleValue = 1.0
                scale = 1.0
                anchor = .center
            } completion: {
                vm.imageSelected = nil
                vm.imageIdSelected = nil
            }
        }
    }
    
    var isDragging: Bool {
        scale == 1 && distance > 0
    }
    
    var combinedScaleEffect: Double {
        isDragging ? detailViewScaleEffect : scale
    }
    
    public init(namespace: Namespace.ID, content: @escaping (ZoomableImageViewModel) -> Content) {
        self.content = content
        self._vm = StateObject(wrappedValue: ZoomableImageViewModel(namespace: namespace))
    }
    
    public var body: some View {
        content(vm)
            .overlay {
                ZStack {
                    Color.clear
                        .matchedGeometryEffect(id: "enlarged", in: vm.namespace, isSource: true)
                    
                    if let image = vm.imageSelected {
                        ZStack {
                            Color.black
                                .ignoresSafeArea()
                                .opacity(detailViewBackgroundOpacity)
                            
                            if dragIsTracking {
                                Color.clear
                                    .overlay {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: vm.presentingImage ? .fit : .fill)
                                    }
                                    .offset(offset)
                                    .scaleEffect(combinedScaleEffect, anchor: computedAnchor)
                                    .matchedGeometryEffect(id: vm.presentingImage ? "enlarged" : "base", in: vm.namespace, isSource: false)
                                    .allowsHitTesting(vm.presentingImage)
                            } else {
                                Color.clear
                                    .overlay {
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: vm.presentingImage ? .fit : .fill)
                                    }
                                    .offset(offset)
                                    .scaleEffect(combinedScaleEffect, anchor: computedAnchor)
                                    .clipped()
                                    .matchedGeometryEffect(id: vm.presentingImage ? "enlarged" : "base", in: vm.namespace, isSource: false)
                                    .allowsHitTesting(vm.presentingImage)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if scale != 1 {
                                        anchorDiffX = -value.translation.width / UIScreen.main.bounds.width / scale
                                        anchorDiffX = max(minAnchorDiffX, anchorDiffX)
                                        anchorDiffX = min(maxAnchorDiffX, anchorDiffX)
                                        anchorDiffY = -value.translation.height / UIScreen.main.bounds.height / scale
                                        anchorDiffY = max(minAnchorDiffY, anchorDiffY)
                                        anchorDiffY = min(maxAnchorDiffY, anchorDiffY)
                                    } else {
                                        dragIsTracking = true
                                        if vm.presentingImage {
                                            offset = value.translation
                                        }
                                    }
                                }
                                .onEnded { _ in
                                    if scale != 1 {
                                        anchor.x += anchorDiffX
                                        anchor.y += anchorDiffY
                                        anchorDiffX = 0.0
                                        anchorDiffY = 0.0
                                    } else {
                                        dragIsTracking = false
                                        if vm.presentingImage {
                                            if detailViewBackgroundOpacity < 0.8 {
                                                dismissDetailView()
                                            } else {
                                                withAnimation {
                                                    offset = CGSize.zero
                                                    scale = 1.0
                                                    lastScaleValue = 0.0
                                                    anchor = .center
                                                }
                                            }
                                        }
                                    }
                                }
                        )
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    if scale == 1 {
                                        anchor = value.startAnchor
                                    }
                                    let delta = value.magnification / lastScaleValue
                                    lastScaleValue = value.magnification
                                    self.scale *= delta
                                }
                                .onEnded { _ in
                                    lastScaleValue = 1.0
                                    if scale < 1.0 {
                                        withAnimation(animation) {
                                            scale = 1.0
                                            anchor = .center
                                        }
                                    }
                                }
                        )
                        .onTapGesture {
                            dismissDetailView()
                        }
                    }
                }
            }
    }
}
