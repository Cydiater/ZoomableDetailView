//
//  SwiftUIView.swift
//  
//
//  Created by Cydiater on 23/6/2024.
//

import SwiftUI

let numImages = 128

let urls : [URL] = {
    let dims = [200, 300, 400, 500, 600, 700]
    var urls: [URL] = []
    for idx in 0..<numImages {
        let width = dims.randomElement()!
        let height = dims.randomElement()!
        let urlString = "https://picsum.photos/id/\(idx)/\(width)/\(height)"
        let url = URL(string: urlString)!
        urls.append(url)
    }
    return urls
}()

struct ExampleView: View {
    @Namespace var namespace
    
    var body: some View {
        WithZoomableDetailViewOverlay(namespace: namespace) { vm in
            ScrollView {
                VStack {
                    HStack {
                        ZoomableSquareAsyncImage(url: urls[0], vm: vm)
                        ZoomableSquareAsyncImage(url: urls[1], vm: vm)
                        ZoomableSquareAsyncImage(url: URL(string: "https://picsum.photos/id/0/200/700")!, vm: vm)
                    }
                    Text("image-via-async-fn")
                    ZoomableSquareImageViaAsyncFn(vm: vm, async_fn: { () async in
                        let url = urls[3]
                        if let (imageData, _) = try? await URLSession.shared.data(from: url) {
                            if let uiImage = UIImage(data: imageData) {
                                return Image(uiImage: uiImage)
                            }
                        }
                        return Image(systemName: "exclamationmark.icloud")
                    }, id: "image-via-async-fn")
                    .frame(width: 128)
                    ZoomableSquareImageViaAsyncFn(vm: vm, async_fn: { () async in
                        return nil
                    }, id: "image-via-async-fn")
                    .frame(width: 128)
                }
            }
        }
    }
}

#Preview {
    ExampleView()
}
