import Algorithms
import Combine
import Defaults
import Pow
import SwiftUI

struct CommentsView: View {
    private let title: String

    @State private var viewModel: CommentsViewModel

    init(details: MovieDetailed) {
        title = details.commentsCount > 0 ? String(localized: "key.comments-\(details.commentsCount.description)") : String(localized: "key.comments")
        viewModel = CommentsViewModel(id: details.movieId, adb: details.adb, type: details.type)
    }

    @State private var showBar: Bool = false

    @Default(.isLoggedIn) private var isLoggedIn

    var body: some View {
        Group {
            if let error = viewModel.state.error {
                ErrorStateView(error, title) {
                    viewModel.load()
                }
                .padding(.vertical, 52)
                .padding(.horizontal, 36)
            } else if let comments = viewModel.state.data {
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

                            CommentTextArea()
                        }
                        .padding(.vertical, 52)
                        .padding(.horizontal, 36)
                    }
                    .scrollIndicators(.never)
                    .onScrollGeometryChange(for: Bool.self) { geometry in
                        geometry.contentOffset.y >= 52
                    } action: { _, showBar in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            self.showBar = showBar
                        }
                    }
                    .environment(viewModel)
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
                                    if viewModel.reply == nil {
                                        CommentTextArea()
                                    }

                                    LazyVStack(alignment: .leading, spacing: 16) {
                                        ForEach(comments) { comment in
                                            CommentsViewComponent(comment: comment)
                                        }
                                    }
                                    .scrollTargetLayout()
                                }
                            }
                            .padding(.vertical, 52)
                            .padding(.horizontal, 36)
                        }
                        .scrollIndicators(.never)
                        .onScrollGeometryChange(for: Bool.self) { geometry in
                            geometry.contentOffset.y >= 52
                        } action: { _, showBar in
                            withAnimation(.easeInOut(duration: 0.15)) {
                                self.showBar = showBar
                            }
                        }
                        .onScrollTargetVisibilityChange(idType: Comment.ID.self) { onScreenComments in
                            if let last = comments.last, onScreenComments.contains(where: { $0 == last.id }), viewModel.paginationState == .idle {
                                viewModel.loadMore()
                            }
                        }
                        .environment(viewModel)

                        if viewModel.paginationState == .loading {
                            LoadingPaginationStateView()
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
            if let comments = viewModel.state.data, !comments.isEmpty {
                Button {
                    viewModel.load()
                } label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                }
                .buttonStyle(NavbarButtonStyle(width: 30, height: 22))
                .keyboardShortcut("r", modifiers: .command)
            }
        })
        .task(id: isLoggedIn) {
            switch viewModel.state {
            case .data:
                break
            default:
                viewModel.load()
            }
        }
        .alert("key.ops", isPresented: $viewModel.isErrorPresented) {
            Button(role: .cancel) {} label: { Text("key.ok") }
        } message: {
            if let message = viewModel.message {
                Text(message)
            } else if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
        .dialogSeverity(.critical)
        .alert("key.comments.success", isPresented: $viewModel.isOnModerationPresented) {
            Button(role: .cancel) {} label: { Text("key.ok") }
        } message: {
            if let message = viewModel.message {
                Text(message)
            }
        }
        .dialogSeverity(.automatic)
        .sheet(isPresented: $viewModel.isCommentPresented) {
            VStack(alignment: .center, spacing: 25) {
                if let comment = viewModel.comment {
                    ScrollView(.vertical) {
                        CommentsViewComponent(comment: comment)
                    }
                    .scrollIndicators(.never)
                    .environment(viewModel)
                } else {
                    ProgressView()
                }

                Button {
                    viewModel.isCommentPresented = false
                } label: {
                    Text("key.done")
                        .frame(width: 250, height: 30)
                        .background(.quinary.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 6))
                        .contentShape(.rect(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 35)
            .padding(.top, 35)
            .padding(.bottom, 25)
            .frame(width: 650)
            .frame(maxHeight: 520)
        }
        .sheet(item: $viewModel.reportComment) { comment in
            CommentReportSheet(comment: comment)
        }
        .confirmationDialog("key.comment.delete.label", isPresented: Binding {
            viewModel.deleteComment != nil
        } set: {
            if !$0 {
                viewModel.deleteComment = nil
            }
        }) {
            if let comment = viewModel.deleteComment {
                Button {
                    viewModel.deleteComment(comment: comment)
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

        init(comment: Comment) {
            self.comment = comment
        }

        @State private var delayShow: DispatchWorkItem?

        @Default(.isLoggedIn) private var isLoggedIn

        @Environment(AppState.self) private var appState
        @Environment(CommentsViewModel.self) private var viewModel

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        AsyncImage(url: URL(string: comment.photo), transaction: .init(animation: .easeInOut)) { phase in
                            if let image = phase.image {
                                image.resizable()
                            } else {
                                Color.gray.shimmering()
                            }
                        }
                        .scaledToFill()
                        .frame(width: 24, height: 24)
                        .clipShape(.circle)
                        .overlay(.tertiary.opacity(0.2), in: .circle.stroke(lineWidth: 1))

                        Text(comment.author)
                            .font(.system(size: 13, weight: .bold))
                            .textSelection(.enabled)

                        Text(comment.date)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    CommentText(comment: comment)

                    HStack(alignment: .center, spacing: 8) {
                        @Bindable var viewModel = viewModel

                        Button {
                            if isLoggedIn {
                                viewModel.like(comment: comment)
                            } else {
                                appState.isSignInPresented = true
                            }
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                if comment.isLiked {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 17))
                                        .transition(.movingParts.pop(Color.accentColor))
                                } else {
                                    Image(systemName: "hand.thumbsup")
                                        .foregroundColor(.accentColor)
                                        .font(.system(size: 17))
                                }

                                if comment.likesCount > 0 {
                                    Text(comment.likesCount.description)
                                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                                        .contentTransition(.numericText(value: Double(comment.likesCount)))
                                }
                            }
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05), in: .capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(comment.selfComment)
                        .onHover { hovering in
                            delayShow?.cancel()

                            if hovering {
                                delayShow = DispatchWorkItem {
                                    viewModel.getLikes(comment: comment)
                                }

                                if let delayShow {
                                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: delayShow)
                                }
                            }
                        }
                        .popover(item: $viewModel.likes[comment.commentId], attachmentAnchor: .rect(.bounds), arrowEdge: .top) { like in
                            VStack(alignment: .center, spacing: 10) {
                                if !like.likes.isEmpty {
                                    let chunks = like.likes.chunks(ofCount: 8)

                                    ForEach(chunks.indices, id: \.self) { chunkIndex in
                                        let likes = chunks[chunkIndex]

                                        HStack(alignment: .center, spacing: 10) {
                                            ForEach(likes) { like in
                                                VStack(alignment: .center, spacing: 5) {
                                                    AsyncImage(url: URL(string: like.photo), transaction: .init(animation: .easeInOut)) { phase in
                                                        if let image = phase.image {
                                                            image.resizable()
                                                        } else {
                                                            Color.gray.shimmering()
                                                        }
                                                    }
                                                    .scaledToFill()
                                                    .frame(width: 60, height: 60)
                                                    .clipShape(.circle)

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
                                viewModel.reply = (viewModel.reply == comment.commentId) ? nil : comment.commentId
                            }
                        } label: {
                            Group {
                                if viewModel.reply == comment.commentId {
                                    Image(systemName: "chevron.up")
                                } else {
                                    Text("key.reply")
                                }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        if !comment.isAdmin {
                            Button {
                                viewModel.reportComment = comment
                            } label: {
                                Image(systemName: "exclamationmark.bubble.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 17))
                                    .frame(height: 28)
                                    .padding(.horizontal, 16)
                                    .background(.tertiary.opacity(0.05))
                                    .clipShape(.capsule)
                                    .contentShape(.capsule)
                                    .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        if comment.deleteHash != nil {
                            Button {
                                viewModel.deleteComment = comment
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 17))
                                    .frame(height: 28)
                                    .padding(.horizontal, 16)
                                    .background(.tertiary.opacity(0.05))
                                    .clipShape(.capsule)
                                    .contentShape(.capsule)
                                    .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.reply == comment.commentId {
                        CommentTextArea()
                    }
                }

                if !comment.replies.isEmpty {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(comment.replies) { reply in
                            CommentsViewComponent(comment: reply)
                        }
                    }
                    .padding(.leading, 16)
                }
            }
        }
    }

    private struct CommentText: View {
        @State private var comment: Comment

        @Environment(AppState.self) private var appState
        @Environment(CommentsViewModel.self) private var viewModel

        init(comment: Comment) {
            self.comment = comment
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
                                    .clipShape(.rect)
                                    .contentShape(.rect)
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

                        viewModel.getComment(movieId: movieId, commentId: commentId)

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
        @State private var feedback: String = ""
        @State private var name: String = ""
        @State private var selection: TextSelection?

        @Default(.isLoggedIn) private var isLoggedIn
        @Default(.allowedComments) private var allowedComments

        @Environment(AppState.self) private var appState
        @Environment(CommentsViewModel.self) private var viewModel

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Button {
                        switch selection?.indices {
                        case let .selection(range):
                            feedback.insert(contentsOf: "[/b]", at: range.upperBound)
                            feedback.insert(contentsOf: "[b]", at: range.lowerBound)

                            selection = TextSelection(range: feedback.index(range.lowerBound, offsetBy: 3) ..< feedback.index(range.upperBound, offsetBy: 3))
                        case let .multiSelection(rangeSet):
                            let sortedRanges = rangeSet.ranges.sorted(by: { $0.lowerBound > $1.lowerBound })

                            for range in sortedRanges {
                                feedback.insert(contentsOf: "[/b]", at: range.upperBound)
                                feedback.insert(contentsOf: "[b]", at: range.lowerBound)
                            }

                            let updatedRanges = sortedRanges.indexed().map { index, range in
                                feedback.index(range.lowerBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1)) ..< feedback.index(range.upperBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1))
                            }

                            selection = TextSelection(ranges: .init(updatedRanges))
                        default:
                            feedback.append("[b][/b]")

                            selection = TextSelection(insertionPoint: feedback.index(feedback.endIndex, offsetBy: -4))
                        }
                    } label: {
                        Image(systemName: "bold")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        switch selection?.indices {
                        case let .selection(range):
                            feedback.insert(contentsOf: "[/i]", at: range.upperBound)
                            feedback.insert(contentsOf: "[i]", at: range.lowerBound)

                            selection = TextSelection(range: feedback.index(range.lowerBound, offsetBy: 3) ..< feedback.index(range.upperBound, offsetBy: 3))
                        case let .multiSelection(rangeSet):
                            let sortedRanges = rangeSet.ranges.sorted(by: { $0.lowerBound > $1.lowerBound })

                            for range in sortedRanges {
                                feedback.insert(contentsOf: "[/i]", at: range.upperBound)
                                feedback.insert(contentsOf: "[i]", at: range.lowerBound)
                            }

                            let updatedRanges = sortedRanges.indexed().map { index, range in
                                feedback.index(range.lowerBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1)) ..< feedback.index(range.upperBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1))
                            }

                            selection = TextSelection(ranges: .init(updatedRanges))
                        default:
                            feedback.append("[i][/i]")

                            selection = TextSelection(insertionPoint: feedback.index(feedback.endIndex, offsetBy: -4))
                        }
                    } label: {
                        Image(systemName: "italic")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        switch selection?.indices {
                        case let .selection(range):
                            feedback.insert(contentsOf: "[/u]", at: range.upperBound)
                            feedback.insert(contentsOf: "[u]", at: range.lowerBound)

                            selection = TextSelection(range: feedback.index(range.lowerBound, offsetBy: 3) ..< feedback.index(range.upperBound, offsetBy: 3))
                        case let .multiSelection(rangeSet):
                            let sortedRanges = rangeSet.ranges.sorted(by: { $0.lowerBound > $1.lowerBound })

                            for range in sortedRanges {
                                feedback.insert(contentsOf: "[/u]", at: range.upperBound)
                                feedback.insert(contentsOf: "[u]", at: range.lowerBound)
                            }

                            let updatedRanges = sortedRanges.indexed().map { index, range in
                                feedback.index(range.lowerBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1)) ..< feedback.index(range.upperBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1))
                            }

                            selection = TextSelection(ranges: .init(updatedRanges))
                        default:
                            feedback.append("[u][/u]")

                            selection = TextSelection(insertionPoint: feedback.index(feedback.endIndex, offsetBy: -4))
                        }
                    } label: {
                        Image(systemName: "underline")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        switch selection?.indices {
                        case let .selection(range):
                            feedback.insert(contentsOf: "[/s]", at: range.upperBound)
                            feedback.insert(contentsOf: "[s]", at: range.lowerBound)

                            selection = TextSelection(range: feedback.index(range.lowerBound, offsetBy: 3) ..< feedback.index(range.upperBound, offsetBy: 3))
                        case let .multiSelection(rangeSet):
                            let sortedRanges = rangeSet.ranges.sorted(by: { $0.lowerBound > $1.lowerBound })

                            for range in sortedRanges {
                                feedback.insert(contentsOf: "[/s]", at: range.upperBound)
                                feedback.insert(contentsOf: "[s]", at: range.lowerBound)
                            }

                            let updatedRanges = sortedRanges.indexed().map { index, range in
                                feedback.index(range.lowerBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1)) ..< feedback.index(range.upperBound, offsetBy: 3 + 7 * (sortedRanges.count - index - 1))
                            }

                            selection = TextSelection(ranges: .init(updatedRanges))
                        default:
                            feedback.append("[s][/s]")

                            selection = TextSelection(insertionPoint: feedback.index(feedback.endIndex, offsetBy: -4))
                        }
                    } label: {
                        Image(systemName: "strikethrough")
                            .font(.system(size: 17))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Button {
                        switch selection?.indices {
                        case let .selection(range):
                            feedback.insert(contentsOf: "[/spoiler]", at: range.upperBound)
                            feedback.insert(contentsOf: "[spoiler]", at: range.lowerBound)

                            selection = TextSelection(range: feedback.index(range.lowerBound, offsetBy: 9) ..< feedback.index(range.upperBound, offsetBy: 9))
                        case let .multiSelection(rangeSet):
                            let sortedRanges = rangeSet.ranges.sorted(by: { $0.lowerBound > $1.lowerBound })

                            for range in sortedRanges {
                                feedback.insert(contentsOf: "[/spoiler]", at: range.upperBound)
                                feedback.insert(contentsOf: "[spoiler]", at: range.lowerBound)
                            }

                            let updatedRanges = sortedRanges.indexed().map { index, range in
                                feedback.index(range.lowerBound, offsetBy: 9 + 19 * (sortedRanges.count - index - 1)) ..< feedback.index(range.upperBound, offsetBy: 9 + 19 * (sortedRanges.count - index - 1))
                            }

                            selection = TextSelection(ranges: .init(updatedRanges))
                        default:
                            feedback.append("[spoiler][/spoiler]")

                            selection = TextSelection(insertionPoint: feedback.index(feedback.endIndex, offsetBy: -10))
                        }
                    } label: {
                        Text("Spoiler!".uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    Spacer(minLength: 0)

                    if !isLoggedIn {
                        TextField("key.name", text: $name, prompt: Text(String(localized: "key.name.full").lowercased()))
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .onChange(of: name) {
                                if name.count > 60 {
                                    name = String(name.prefix(60))
                                }
                            }
                    }

                    Button {
                        viewModel.sendComment(name: isLoggedIn ? nil : name, text: feedback)

                        name = ""
                        feedback = ""
                    } label: {
                        Text("key.send")
                            .font(.system(size: 15, weight: .bold))
                            .frame(height: 28)
                            .padding(.horizontal, 16)
                            .background(.tertiary.opacity(0.05))
                            .clipShape(.capsule)
                            .contentShape(.capsule)
                            .overlay(.tertiary.opacity(0.2), in: .capsule.stroke(lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isLoggedIn && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || !allowedComments)
                    .animation(.easeInOut, value: feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (!isLoggedIn && name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) || !allowedComments)
                }

                TextField("key.comments", text: $feedback, selection: $selection, prompt: Text(String(localized: "key.comments.placeholder").lowercased()))
                    .textFieldStyle(.plain)
                    .textSelectionAffinity(.downstream)
            }
            .padding(12)
            .clipShape(.rect(cornerRadius: 6))
            .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
            .onChange(of: feedback) {
                if !allowedComments, !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    appState.commentsRulesPresented = true
                }
            }
        }
    }
}
