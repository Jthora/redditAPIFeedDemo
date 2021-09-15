//
//  InfiniteList.swift
//  RedditAPIFeedDemo
//
//  Created by Jordan Trana on 9/14/21.
//

import SwiftUI

struct InfiniteList<Data, Content>: View
    where Data : RandomAccessCollection, Data.Element : Hashable, Content : View  {
  @Binding var data: Data
  @Binding var loading: Bool
  let loadMore: () -> Void
  let content: (Data.Element) -> Content

  init(data: Binding<Data>,
       loading: Binding<Bool>,
       loadMore: @escaping () -> Void,
       @ViewBuilder content: @escaping (Data.Element) -> Content) {
    _data = data
    _loading = loading
    self.loadMore = loadMore
    self.content = content
  }

  var body: some View {
    List {
       ForEach(data, id: \.self) { item in
         content(item)
           .onAppear {
              if item == data.last {
                loadMore()
              }
           }
       }
       if loading {
         ProgressView()
           .frame(idealWidth: .infinity, maxWidth: .infinity, alignment: .center)
       }
    }.onAppear(perform: loadMore)
  }
}
