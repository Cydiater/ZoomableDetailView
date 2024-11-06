// The Swift Programming Language
// https://docs.swift.org/swift-book

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
    @State private var zoomScale = 1.0
    @State private var currentZoomScale = 0.0
    @State private var dragIsTracking = false
    @State private var scaleAnchor = UnitPoint.center
    
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
                zoomScale = 1.0
                currentZoomScale = 0.0
                scaleAnchor = .center
            } completion: {
                vm.imageSelected = nil
                vm.imageIdSelected = nil
            }
        }
    }
    
    var isDragging: Bool {
        distance > 0
    }
    
    var combinedScaleEffect: Double {
        isDragging ? detailViewScaleEffect : (zoomScale + currentZoomScale)
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
                                    .scaleEffect(combinedScaleEffect, anchor: scaleAnchor)
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
                                    .scaleEffect(combinedScaleEffect, anchor: scaleAnchor)
                                    .clipped()
                                    .matchedGeometryEffect(id: vm.presentingImage ? "enlarged" : "base", in: vm.namespace, isSource: false)
                                    .allowsHitTesting(vm.presentingImage)
                            }
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if zoomScale != 1 {
                                        return
                                    }
                                    dragIsTracking = true
                                    if vm.presentingImage {
                                        offset = value.translation
                                    }
                                }
                                .onEnded { _ in
                                    if zoomScale != 1 {
                                        return
                                    }
                                    dragIsTracking = false
                                    if vm.presentingImage {
                                        if detailViewBackgroundOpacity < 0.8 {
                                            dismissDetailView()
                                        } else {
                                            withAnimation {
                                                offset = CGSize.zero
                                                zoomScale = 1.0
                                                currentZoomScale = 0.0
                                                scaleAnchor = .center
                                            }
                                        }
                                    }
                                }
                        )
                        .gesture(
                            MagnifyGesture()
                                .onChanged { value in
                                    currentZoomScale = value.magnification - 1
                                    scaleAnchor = value.startAnchor
                                }
                                .onEnded { _ in
                                    zoomScale += currentZoomScale
                                    currentZoomScale = 0
                                    if zoomScale < 1.0 {
                                        withAnimation(animation) {
                                            zoomScale = 1.0
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
