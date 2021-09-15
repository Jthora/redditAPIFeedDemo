//
//  Post.swift
//  RedditAPIFeedDemo
//
//  Created by Jordan Trana on 9/14/21.
//

import Foundation

struct Post: Hashable {
    var title:String
    var textOnly:Bool
    var image:String
    var width:Int
    var height:Int
    var commentCount:Int
    var score:Int
    
    init?(title:String?, textOnly:Bool, image:String?, width:Int?, height:Int?, commentCount:Int?, score:Int?) {
        guard let t = title,
              let i = image,
              let w = width,
              let h = height,
              let c = commentCount,
              let s = score else { return nil}
        self.title = t
        self.textOnly = textOnly
        self.image = i
        self.width = w
        self.height = h
        self.commentCount = c
        self.score = s
    }
}
