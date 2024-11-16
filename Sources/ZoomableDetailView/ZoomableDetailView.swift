import SwiftUI

public class ZoomableImageViewModel: ObservableObject {
    @Published var imageSelected: UIImage? = nil
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
        case finishedWith(UIImage)
        case failed
    }
    
    @State private var state = FnState.not_called_yet
    
    let async_fn: () async -> UIImage?
    let id: String
    
    let animation = Animation.easeInOut(duration: 0.2)
    
    public init(vm: ZoomableImageViewModel, async_fn: @escaping () async -> UIImage?, id: String) {
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
                    Image(uiImage: image)
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
    
    var body: some View {
        ZoomableSquareImageViaAsyncFn(vm: vm, async_fn: { () in
            if let (data, _) = try? await URLSession.shared.data(from: url) {
                return UIImage(data: data)
            } else {
                return nil
            }
        }, id: url.absoluteString)
    }
}

public struct WithZoomableDetailViewOverlay<Content: View>: View {
    let content: (ZoomableImageViewModel) -> Content
    @StateObject var vm: ZoomableImageViewModel
    
    @State private var offset = CGSize.zero
    @State private var currentOffset = CGSize.zero
    @State private var dragIsTracking = false
    
    @State private var lastScaleValue = 1.0
    @State private var scale = 1.0
    @State private var anchor: UnitPoint = .center
    
    let animation = Animation.easeInOut(duration: 0.2)
    
    var distance: Double { sqrt(offset.width * offset.width + offset.height * offset.height) }

    var detailViewBackgroundOpacity: Double {
        if vm.presentingImage {
            if scale != 1 {
                return 1
            } else {
                let maximumDistance: Double = 200
                return max(0, maximumDistance - distance) / maximumDistance
            }
        } else {
            return 0
        }
    }
    
    var detailViewScaleEffect: Double {
        if vm.presentingImage && scale == 1 {
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
    
    var combinedOffset: CGSize {
        CGSize(width: offset.width + currentOffset.width, height: offset.height + currentOffset.height)
    }
    
    public init(namespace: Namespace.ID, content: @escaping (ZoomableImageViewModel) -> Content) {
        self.content = content
        self._vm = StateObject(wrappedValue: ZoomableImageViewModel(namespace: namespace))
    }
    
    @ViewBuilder
    func imageView(image: UIImage, proxy: GeometryProxy) -> some View {
        Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: vm.presentingImage ? .fit : .fill)
            .offset(combinedOffset)
            .scaleEffect(combinedScaleEffect, anchor: anchor)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if scale != 1 {
                            currentOffset = CGSize(width: value.translation.width / scale, height: value.translation.height / scale)
                        } else {
                            dragIsTracking = true
                            if vm.presentingImage {
                                offset = value.translation
                            }
                        }
                    }
                    .onEnded { _ in
                        if scale != 1 {
                            withAnimation {
                                offset = CGSize(width: offset.width + currentOffset.width, height: offset.height + currentOffset.height)
                                currentOffset = .zero
                                let scaleToFit = min(proxy.size.width / image.size.width, proxy.size.height / image.size.height)
                                let initialImageSize = CGSize(width: image.size.width * scaleToFit, height: image.size.height * scaleToFit)
                                let scaledImageSize = CGSize(width: initialImageSize.width * self.scale, height: initialImageSize.height * self.scale)
                                if scaledImageSize.width < proxy.size.width {
                                    offset.width = 0
                                }
                                if scaledImageSize.height < proxy.size.height {
                                    offset.height = 0
                                }
                            }
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
                        anchor = value.startAnchor
                        let delta = value.magnification / lastScaleValue
                        lastScaleValue = value.magnification
                        self.scale *= delta
                    }
                    .onEnded { _ in
                        withAnimation(animation) {
                            lastScaleValue = 1.0
                            if scale < 1.0 {
                                scale = 1.0
                                anchor = .center
                                offset = .zero
                            } else {
                                let scaleToFit = min(proxy.size.width / image.size.width, proxy.size.height / image.size.height)
                                let initialImageSize = CGSize(width: image.size.width * scaleToFit, height: image.size.height * scaleToFit)
                                let scaledImageSize = CGSize(width: initialImageSize.width * self.scale, height: initialImageSize.height * self.scale)
                                if scaledImageSize.width > proxy.size.width {
                                    offset.width = -(anchor.x - 0.5) * (scaledImageSize.width - initialImageSize.width) / scale
                                }
                                if scaledImageSize.height > proxy.size.height {
                                    offset.height = -(anchor.y - 0.5) * (scaledImageSize.height - initialImageSize.height) / scale
                                }
                                anchor = .center
                            }
                        }
                    }
            )
    }
    
    public var body: some View {
        content(vm)
            .overlay {
                ZStack {
                    Color.clear
                        .matchedGeometryEffect(id: "enlarged", in: vm.namespace, isSource: true)
                    
                    if let image = vm.imageSelected {
                        GeometryReader { proxy in
                            ZStack {
                                Color.black
                                    .ignoresSafeArea()
                                    .opacity(detailViewBackgroundOpacity)
                                
                                if dragIsTracking {
                                    Color.clear
                                        .overlay {
                                            imageView(image: image, proxy: proxy)
                                        }
                                        .matchedGeometryEffect(id: vm.presentingImage ? "enlarged" : "base", in: vm.namespace, isSource: false)
                                        .allowsHitTesting(vm.presentingImage)
                                } else {
                                    Color.clear
                                        .overlay {
                                            imageView(image: image, proxy: proxy)
                                        }
                                        .clipped()
                                        .matchedGeometryEffect(id: vm.presentingImage ? "enlarged" : "base", in: vm.namespace, isSource: false)
                                        .allowsHitTesting(vm.presentingImage)
                                }
                            }
                            .onTapGesture {
                                dismissDetailView()
                            }
                        }
                    }
                }
            }
    }
}
