//
//  PostViewModel.swift
//  PostViewModel
//
//  Created by Ben Stone on 8/9/21.
//

import Foundation

@MainActor class PostViewModel: ObservableObject {
    @Published var posts: [Post] = []
    
    private let postService: PostServiceProtocol
    private let filter: PostFilter?
    
    init(postService: PostServiceProtocol, filter: PostFilter? = nil) {
        self.postService = postService
        self.filter = filter
    }
    
    func loadPosts() {
        Task {
            await refreshPosts()
        }
    }
    
    func refreshPosts() async {
        do {
            posts = try await postService.fetchPosts(matching: filter)
        } catch {
            print("[PostViewModel] Cannot load posts: \(error.localizedDescription)")
        }
    }
    
    func submitPost(_ post: Post.Partial) async throws {
        let post = try await postService.create(post)
        posts.insert(post, at: 0)
    }
    
    func deleteAction(for post: Post) -> (() async throws -> Void)? {
        guard postService.canDelete(post) else {
            return nil
        }
        return { [self] in
            try await postService.delete(post)
            posts.removeAll { $0.id == post.id }
        }
    }
    
    func favoriteAction(for post: Post) -> (() async throws -> Void) {
        return { [self] in
            if let i = posts.firstIndex(of: post) {
                posts[i].isFavorite = !post.isFavorite
            }
            try await (post.isFavorite ? postService.unfavorite(post) : postService.favorite(post))
        }
    }
}
