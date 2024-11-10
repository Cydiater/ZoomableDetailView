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
                                return uiImage
                            }
                        }
                        return UIImage(systemName: "exclamationmark.icloud")
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

class MyUITableViewController<Content: View>: UIViewController, UITableViewDelegate {
    let tableView: UITableView
    let dataSource: UITableViewDiffableDataSource<Int, Int>
    
    init(content: @escaping () -> Content) {
        let tableView = UITableView()
        let dataSource = UITableViewDiffableDataSource<Int, Int>(tableView: tableView, cellProvider: { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "swiftui-hosting", for: indexPath)
            cell.selectionStyle = .none
            if item == 32 {
                cell.contentConfiguration = UIHostingConfiguration {
                    content()
                }
                .margins(.all, 0)
            } else {
                cell.contentConfiguration = UIHostingConfiguration {
                    let idx = item
                    HStack {
                        Text(idx.description)
                            .padding(.horizontal)
                        Spacer()
                        Text("1")
                            .padding(.horizontal)
                            .italic()
                    }
                    .font(.title)
                    .border(.black)
                    .background(.blue)
                    .padding(.horizontal)
                    .padding(.vertical, 3)
                }
                .margins(.all, 0)
            }
            return cell
        })
        
        self.tableView = tableView
        self.dataSource = dataSource
        
        super.init(nibName: nil, bundle: nil)
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "swiftui-hosting")
        
        tableView.delegate = self
        tableView.dataSource = dataSource
        tableView.separatorStyle = .none
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(tableView)
        
        view.addConstraints([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        
        var snapshot = NSDiffableDataSourceSnapshot<Int, Int>()
        snapshot.appendSections([0])
        snapshot.appendItems(Array(0..<2000))
        dataSource.apply(snapshot)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct MyTableView<Content: View>: UIViewControllerRepresentable {
    typealias UIViewControllerType = MyUITableViewController<Content>
    
    var content: () -> Content
    
    func makeUIViewController(context: Context) -> UIViewControllerType {
        let viewController = MyUITableViewController(content: content)
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {

    }
}


struct ExampleView2: View {
    @Namespace var namespace
    
    var body: some View {
        WithZoomableDetailViewOverlay(namespace: namespace) { vm in
            MyTableView {
                HStack {
                    ZoomableSquareAsyncImage(url: urls[0], vm: vm)
                    ZoomableSquareAsyncImage(url: urls[1], vm: vm)
                    ZoomableSquareAsyncImage(url: URL(string: "https://picsum.photos/id/0/200/700")!, vm: vm)
                }
            }
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ExampleView()
}

#Preview {
    ExampleView2()
}
