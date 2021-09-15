//
//  PostView.swift
//  RedditAPIFeedDemo
//
//  Created by Jordan Trana on 9/14/21.
//

import SwiftUI

struct PostView: View {
    
    let title:String
    let imageURL:URL?
    let commentCount:Int
    let score:Int
    let width:CGFloat
    let height:CGFloat
    
    init(_ post:Post) {
        title = post.title
        imageURL = post.textOnly ? nil : URL(string:post.image)
        commentCount = post.commentCount
        score = post.score
        
        width = UIScreen.main.bounds.width
        height = post.textOnly ? 0 : (CGFloat(post.height)/CGFloat(post.width))*UIScreen.main.bounds.width
    }
    
    var body: some View {
        Group {
            VStack {
                Text(title)
                
                if let imageURL = imageURL {
                    AsyncImage(url: imageURL,
                               placeholder: { Text("Loading ...") },
                               image: {
                                Image(uiImage: $0)
                                .resizable()
                                
                               }
                    )
                    .frame(idealWidth: width, idealHeight: height)
                }
                HStack {
                    Text("Comments: \(commentCount)")
                    Spacer()
                    Text("Score: \(score)")
                }
            }
        }
    }
}
