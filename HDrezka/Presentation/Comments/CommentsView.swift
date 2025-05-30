import Algorithms
import Combine
import Defaults
import NukeUI
import Pow
import SwiftUI

struct CommentsView: View {
    private let details: MovieDetailed
    private let title: String

    @StateObject private var vm = CommentsViewModel()

    @State private var showBar: Bool = false

    @Default(.isLoggedIn) private var isLoggedIn

    init(details: MovieDetailed) {
        self.details = details
        self.title = details.commentsCount > 0 ? String(localized: "key.comments-\(details.commentsCount.description)") : String(localized: "key.comments")
    }

    var body: some View {
        Group {
            if let error = vm.state.error {
                ErrorStateView(error, title) {
                    vm.load(movieId: details.movieId)
                }
                .padding(.vertical, 52)
                .padding(.horizontal, 36)
            } else if let comments = vm.state.data {
                if comments.isEmpty {
                    ScrollView(.vertical) {
                        VStack(spacing: 18) {
                            VStack(alignment: .leading) {
                                Spacer()

                                Text(title)
                                    .font(.largeTitle.weight(.semibold))
                                    .lineLimit(1)

                                Spacer()

                                Divider()
                            }
                            .frame(height: 52)

                            CommentTextArea { name, text in
                                vm.sendComment(name: name, text: text, postId: details.movieId, adb: details.adb, type: details.type)
                            }
                        }
                        .padding(.vertical, 52)
                        .padding(.horizontal, 36)
                        .onGeometryChange(for: Bool.self) { geometry in
                            -geometry.frame(in: .named("scroll")).origin.y / 52 >= 1
                        } action: { showBar in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                self.showBar = showBar
                            }
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .scrollIndicators(.never)
                } else {
                    VStack {
                        ScrollView(.vertical) {
                            VStack(spacing: 18) {
                                VStack(alignment: .leading) {
                                    Spacer()

                                    Text(title)
                                        .font(.largeTitle.weight(.semibold))
                                        .lineLimit(1)

                                    Spacer()

                                    Divider()
                                }
                                .frame(height: 52)

                                VStack(spacing: 16) {
                                    if vm.reply == nil {
                                        CommentTextArea { name, text in
                                            vm.sendComment(name: name, text: text, postId: details.movieId, adb: details.adb, type: details.type)
                                        }
                                    }

                                    LazyVStack(alignment: .leading, spacing: 16) {
                                        ForEach(comments) { comment in
                                            CommentsViewComponent(comment: comment, details: details)
                                                .task {
                                                    if comments.last == comment, vm.paginationState == .idle {
                                                        vm.loadMore(movieId: details.movieId)
                                                    }
                                                }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 52)
                            .padding(.horizontal, 36)
                            .onGeometryChange(for: Bool.self) { geometry in
                                -geometry.frame(in: .named("scroll")).origin.y / 52 >= 1
                            } action: { showBar in
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    self.showBar = showBar
                                }
                            }
                        }
                        .coordinateSpace(name: "scroll")
                        .scrollIndicators(.never)
                        .environmentObject(vm)

                        if vm.paginationState == .loading {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                            .padding(.vertical, 10)
                        }
                    }
                }
            } else {
                LoadingStateView(title)
                    .padding(.vertical, 52)
                    .padding(.horizontal, 36)
            }
        }
        .navigationBar(title: title, showBar: showBar, navbar: {
            if let comments = vm.state.data, !comments.isEmpty {
                Button {
                    vm.load(movieId: details.movieId)
                } label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                }
                .buttonStyle(NavbarButtonStyle(width: 30, height: 22))
                .keyboardShortcut("r", modifiers: .command)
            }
        })
        .load(isLoggedIn) {
            switch vm.state {
            case .data:
                break
            default:
                vm.load(movieId: details.movieId)
            }
        }
        .alert("key.ops", isPresented: $vm.isErrorPresented) {
            Button(role: .cancel) {} label: { Text("key.ok") }
        } message: {
            if let message = vm.message {
                Text(message)
            } else if let error = vm.error {
                Text(error.localizedDescription)
            }
        }
        .dialogSeverity(.critical)
        .alert("key.comments.success", isPresented: $vm.isOnModerationPresented) {
            Button(role: .cancel) {} label: { Text("key.ok") }
        } message: {
            if let message = vm.message {
                Text(message)
            }
        }
        .dialogSeverity(.automatic)
        .sheet(isPresented: $vm.isCommentPresented) {
            VStack(alignment: .center, spacing: 25) {
                if let comment = vm.comment {
                    ScrollView(.vertical) {
                        CommentsViewComponent(comment: comment, details: details)
                    }
                    .scrollIndicators(.never)
                    .environmentObject(vm)
                } else {
                    ProgressView()
                }

                Button {
                    vm.isCommentPresented = false
                } label: {
                    Text("key.done")
                        .frame(width: 250, height: 30)
                        .background(.quinary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 35)
            .padding(.top, 35)
            .padding(.bottom, 25)
            .frame(width: 650)
            .frame(maxHeight: 520)
        }
        .sheet(item: $vm.reportComment) { comment in
            CommentReportSheet(comment: comment)
        }
        .confirmationDialog("key.comment.delete.label", isPresented: Binding {
            vm.deleteComment != nil
        } set: {
            if !$0 {
                vm.deleteComment = nil
            }
        }) {
            if let comment = vm.deleteComment {
                Button {
                    vm.deleteComment(comment: comment)
                } label: {
                    Text("key.comment.delete.confirm")
                }
            }
        } message: {
            Text("key.comment.delete")
        }
        .background(.background)
    }

    private struct CommentsViewComponent: View {
        private let comment: Comment
        private let details: MovieDetailed

        @Default(.isLoggedIn) private var isLoggedIn
        @EnvironmentObject private var appState: AppState
        @EnvironmentObject private var vm: CommentsViewModel

        @State private var delayShow: DispatchWorkItem?

        init(comment: Comment, details: MovieDetailed) {
            self.comment = comment
            self.details = details
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        LazyImage(url: URL(string: comment.photo), transaction: .init(animation: .easeInOut)) { state in
                            if let image = state.image {
                                image.resizable()
                                    .transition(
                                        .asymmetric(
                                            insertion: .wipe(blurRadius: 10),
                                            removal: .wipe(reversed: true, blurRadius: 10)
                                        )
                                    )
                            } else {
                                Rectangle()
                                    .fill(.gray)
                                    .shimmering()
                                    .transition(
                                        .asymmetric(
                                            insertion: .wipe(blurRadius: 10),
                                            removal: .wipe(reversed: true, blurRadius: 10)
                                        )
                                    )
                            }
                        }
                        .onDisappear(.cancel)
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                        }

                        Text(comment.author)
                            .font(.system(size: 13, weight: .bold))
                            .textSelection(.enabled)

                        Text(comment.date)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    CommentText(comment: comment, getComment: vm.getComment)

                    HStack(alignment: .center, spacing: 8) {
                        Button {
                            if isLoggedIn {
                                vm.like(comment: comment)
                            } else {
                                appState.isSignInPresented = true
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                if comment.isLiked {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 17))
                                        .transition(.movingParts.pop(.accent))
                                } else {
                                    Image(systemName: "hand.thumbsup")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 17))
                                }

                                if comment.likesCount > 0 {
                                    if #available(macOS 14.0, *) {
                                        Text(comment.likesCount.description)
                                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                            .contentTransition(.numericText(value: Double(comment.likesCount)))
                                    } else {
                                        Text(comment.likesCount.description)
                                            .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                    }
                                }
                            }
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 100)
                                    .fill(.tertiary.opacity(0.05))
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(comment.selfComment)
                        .onHover { hovering in
                            delayShow?.cancel()

                            if hovering {
                                delayShow = DispatchWorkItem {
                                    vm.getLikes(hovering: hovering, comment: comment)
                                }

                                if let delayShow {
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: delayShow)
                                }
                            } else {
                                vm.getLikes(hovering: hovering, comment: comment)
                            }
                        }
                        .popover(isPresented: Binding {
                            vm.likes[comment.commentId]?.0 == true
                        } set: {
                            vm.getLikes(hovering: $0, comment: comment)
                        }, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                            VStack(alignment: .center, spacing: 10) {
                                if let l = vm.likes[comment.commentId], !l.1.isEmpty {
                                    let chunks = l.1.chunks(ofCount: 8)

                                    ForEach(chunks.indices, id: \.self) { chunkIndex in
                                        let likes = chunks[chunkIndex]

                                        HStack(alignment: .center, spacing: 10) {
                                            ForEach(likes) { like in
                                                VStack(alignment: .center, spacing: 5) {
                                                    LazyImage(url: URL(string: like.photo), transaction: .init(animation: .easeInOut)) { state in
                                                        if let image = state.image {
                                                            image.resizable()
                                                        } else {
                                                            Rectangle()
                                                                .fill(.gray)
                                                                .shimmering()
                                                        }
                                                    }
                                                    .onDisappear(.cancel)
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(RoundedRectangle(cornerRadius: 30))

                                                    Text(like.name)
                                                        .lineLimit(1)
                                                        .font(.system(size: 13))
                                                }
                                                .frame(width: 60)
                                            }
                                        }
                                    }
                                } else {
                                    ProgressView()
                                }
                            }
                            .padding(15)
                        }

                        Button {
                            withAnimation(.easeInOut) {
                                vm.reply = (vm.reply == comment.commentId) ? nil : comment.commentId
                            }
                        } label: {
                            Group {
                                if vm.reply == comment.commentId {
                                    Image(systemName: "chevron.up")
                                } else {
                                    Text("key.reply")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)

                        if !comment.isAdmin {
                            Button {
                                vm.reportComment = comment
                            } label: {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 17))
                                    .frame(height: 28)
                                    .padding(.horizontal, 16)
                                    .background(.tertiary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 100))
                                    .contentShape(RoundedRectangle(cornerRadius: 100))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 100)
                                            .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if comment.deleteHash != nil {
                            Button {
                                vm.deleteComment = comment
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 17))
                                    .frame(height: 28)
                                    .padding(.horizontal, 16)
                                    .background(.tertiary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 100))
                                    .contentShape(RoundedRectangle(cornerRadius: 100))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 100)
                                            .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if vm.reply == comment.commentId {
                        CommentTextArea { name, text in
                            vm.sendComment(name: name, text: text, postId: details.movieId, adb: details.adb, type: details.type)
                        }
                    }
                }

                if !comment.replies.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(comment.replies) { reply in
                            CommentsViewComponent(comment: reply, details: details)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }

    private struct CommentText: View {
        @State private var comment: Comment
        private let getComment: (String, String) -> Void

        @EnvironmentObject private var appState: AppState

        init(comment: Comment, getComment: @escaping (String, String) -> Void) {
            self.comment = comment
            self.getComment = getComment
        }

        var body: some View {
            Text(AttributedString(comment.text))
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
                .textSelection(.enabled)
                .onGeometryChange(for: CGFloat.self) { geometry in
                    geometry.size.width
                } action: { width in
                    comment.updateRects(containerWidth: width)
                }
                .overlay {
                    ZStack(alignment: .topLeading) {
                        ForEach(comment.spoilers) { spoiler in
                            ForEach(spoiler.rects.indices, id: \.self) { rectIndex in
                                let rect = spoiler.rects[rectIndex]

//                                        Rectangle()
//                                            .stroke(.red, lineWidth: 1)
//                                            .frame(width: rect.width, height: rect.height)
//                                            .position(x: rect.x + rect.width * 0.5, y: rect.y + rect.height * 0.5)

                                SpoilerView()
                                    .background(.background)
                                    .clipShape(Rectangle())
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut) {
                                            comment.removeSpoiler(spoiler.id)
                                        }
                                    }
                                    .frame(width: rect.width, height: rect.height)
                                    .position(x: rect.midX, y: rect.midY)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .environment(\.openURL, OpenURLAction { url in
                    if let fragment = url.fragment(), fragment.contains("comment"), !url.path().isEmpty {
                        let movieId = String(url.path().dropFirst())
                        let commentId = fragment.replacingOccurrences(of: "comment", with: "")

                        getComment(movieId, commentId)

                        return .handled
                    } else if !url.path().isEmpty, String(url.path().dropFirst()).id != nil {
                        appState.path.append(.details(.init(movieId: String(url.path().dropFirst()))))

                        return .handled
                    }

                    return .systemAction
                })
        }
    }

    private struct CommentTextArea: View {
        private let sendComment: (String?, String) -> Void

        init(sendComment: @escaping (String?, String) -> Void) {
            self.sendComment = sendComment
        }

        @State private var feedback: String = ""
        @State private var name: String = ""
        @State private var selection: NSRange = .init(location: 0, length: 0)

        @Default(.isLoggedIn) private var isLoggedIn
        @Default(.allowedComments) private var allowedComments
        @EnvironmentObject private var appState: AppState

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Button {
                        feedback.insert(contentsOf: "[/b]", at: String.Index(utf16Offset: selection.location + selection.length, in: feedback))
                        feedback.insert(contentsOf: "[b]", at: String.Index(utf16Offset: selection.location, in: feedback))

                        selection = NSRange(location: selection.location + 3, length: selection.length)
                    } label: {
                        Image(systemName: "bold")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        feedback.insert(contentsOf: "[/i]", at: String.Index(utf16Offset: selection.location + selection.length, in: feedback))
                        feedback.insert(contentsOf: "[i]", at: String.Index(utf16Offset: selection.location, in: feedback))

                        selection = NSRange(location: selection.location + 3, length: selection.length)
                    } label: {
                        Image(systemName: "italic")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        feedback.insert(contentsOf: "[/u]", at: String.Index(utf16Offset: selection.location + selection.length, in: feedback))
                        feedback.insert(contentsOf: "[u]", at: String.Index(utf16Offset: selection.location, in: feedback))

                        selection = NSRange(location: selection.location + 3, length: selection.length)
                    } label: {
                        Image(systemName: "underline")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        feedback.insert(contentsOf: "[/s]", at: String.Index(utf16Offset: selection.location + selection.length, in: feedback))
                        feedback.insert(contentsOf: "[s]", at: String.Index(utf16Offset: selection.location, in: feedback))

                        selection = NSRange(location: selection.location + 3, length: selection.length)
                    } label: {
                        Image(systemName: "strikethrough")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Button {
                        feedback.insert(contentsOf: "[/spoiler]", at: String.Index(utf16Offset: selection.location + selection.length, in: feedback))
                        feedback.insert(contentsOf: "[spoiler]", at: String.Index(utf16Offset: selection.location, in: feedback))

                        selection = NSRange(location: selection.location + 9, length: selection.length)
                    } label: {
                        Text("Spoiler!".uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    if !isLoggedIn {
                        TextField("key.name", text: $name, prompt: Text(String(localized: "key.name.full").lowercased()))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .customOnChange(of: name) {
                                if name.count > 60 {
                                    name = String(name.prefix(60))
                                }
                            }
                    }

                    Button {
                        sendComment(isLoggedIn ? nil : name, feedback)

                        name = ""
                        feedback = ""
                    } label: {
                        Text("key.send")
                            .font(.system(size: 15, weight: .bold))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 100))
                            .contentShape(RoundedRectangle(cornerRadius: 100))
                            .overlay {
                                RoundedRectangle(cornerRadius: 100)
                                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isLoggedIn && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || !allowedComments)
                    .animation(.easeInOut, value: feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isLoggedIn && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || !allowedComments)
                }

                CursorPositionTextView(text: $feedback, selection: $selection, prompt: String(localized: "key.comments.placeholder").lowercased())
            }
            .padding(12)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.tertiary.opacity(0.2), lineWidth: 1)
            }
            .customOnChange(of: feedback) {
                if !allowedComments, !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appState.commentsRulesPresented = true
                }
            }
        }
    }
}
