//
//  ContentView.swift
//  RedditAPIFeedDemo
//
//  Created by Jordan Trana on 9/14/21.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var viewModel = ContentViewModel<DispatchQueue>(scheduler: DispatchQueue.main)
    
    var body: some View {
        HStack {
            VStack(alignment: .center) {
                InfiniteList(data: $viewModel.posts,
                             loading: $viewModel.loading,
                             loadMore: { self.viewModel.loadMore() }) { post in
                    PostView(post)
                }
            }
            .padding(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
