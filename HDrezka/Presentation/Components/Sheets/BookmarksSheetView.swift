import Combine
import FactoryKit
import Flow
import Pow
import SwiftUI

struct BookmarksSheetView: View {
    private let movie: MovieSimple

    @Binding private var isCreateBookmarkPresented: Bool

    init(movie: MovieSimple, isCreateBookmarkPresented: Binding<Bool>) {
        self.movie = movie
        self._isCreateBookmarkPresented = isCreateBookmarkPresented
    }

    @Injected(\.addToBookmarksUseCase) private var addToBookmarksUseCase
    @Injected(\.removeFromBookmarksUseCase) private var removeFromBookmarksUseCase
    @Injected(\.getMovieBookmarksUseCase) private var getMovieBookmarksUseCase

    @State private var subscriptions: Set<AnyCancellable> = []

    @Environment(\.dismiss) private var dismiss

    @State private var state: DataState<[Bookmark]> = .loading

    @State private var error: Error?
    @State private var isErrorPresented: Bool = false

    @State private var scrollViewContentSize: CGSize = .zero

    var body: some View {
        VStack(alignment: .center, spacing: 25) {
            VStack(alignment: .center, spacing: 5) {
                Image(systemName: "bookmark.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)

                Text("key.bookmarks")
                    .font(.largeTitle.weight(.semibold))

                Text("key.bookmarks.description")
                    .font(.title3)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.center)
            }

            Group {
                if let error = state.error {
                    VStack(alignment: .center, spacing: 8) {
                        Text(error.localizedDescription)
                            .lineLimit(nil)

                        Button {
                            withAnimation(.easeInOut) {
                                state = .loading
                            }

                            getMovieBookmarksUseCase(movieId: movie.movieId)
                                .receive(on: DispatchQueue.main)
                                .sink { completion in
                                    guard case let .failure(error) = completion else { return }

                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        withAnimation(.easeInOut) {
                                            state = .error(error as NSError)
                                        }
                                    }
                                } receiveValue: { bookmarks in
                                    withAnimation(.easeInOut) {
                                        self.state = .data(bookmarks)
                                    }
                                }
                                .store(in: &subscriptions)
                        } label: {
                            Text("key.retry")
                                .foregroundStyle(.accent)
                                .highlightOnHover()
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if var bookmarks = state.data {
                    if bookmarks.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Text("key.bookmark.empty")

                            Button {
                                withAnimation(.easeInOut) {
                                    state = .loading
                                }

                                getMovieBookmarksUseCase(movieId: movie.movieId)
                                    .receive(on: DispatchQueue.main)
                                    .sink { completion in
                                        guard case let .failure(error) = completion else { return }

                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            withAnimation(.easeInOut) {
                                                state = .error(error as NSError)
                                            }
                                        }
                                    } receiveValue: { bookmarks in
                                        withAnimation(.easeInOut) {
                                            self.state = .data(bookmarks)
                                        }
                                    }
                                    .store(in: &subscriptions)
                            } label: {
                                Text("key.retry")
                                    .foregroundStyle(.accent)
                                    .highlightOnHover()
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(.vertical) {
                            HFlow(horizontalAlignment: .center, verticalAlignment: .center, horizontalSpacing: 5, verticalSpacing: 5, distributeItemsEvenly: true) {
                                ForEach(bookmarks) { bookmark in
                                    if let index = bookmarks.firstIndex(where: { b in
                                        b == bookmark
                                    }) {
                                        let isChecked = bookmark.isChecked ?? false

                                        Button {
                                            if let movieId = movie.movieId.id {
                                                if isChecked {
                                                    removeFromBookmarksUseCase(movies: [movieId], bookmarkUserCategory: bookmark.bookmarkId)
                                                        .receive(on: DispatchQueue.main)
                                                        .sink { completion in
                                                            guard case let .failure(error) = completion else { return }

                                                            self.error = error
                                                            self.isErrorPresented = true
                                                        } receiveValue: { success in
                                                            if success {
                                                                bookmarks[index] -= 1

                                                                withAnimation(.easeInOut) {
                                                                    state = .data(bookmarks)
                                                                }
                                                            }
                                                        }
                                                        .store(in: &subscriptions)
                                                } else {
                                                    addToBookmarksUseCase(movieId: movieId, bookmarkUserCategory: bookmark.bookmarkId)
                                                        .receive(on: DispatchQueue.main)
                                                        .sink { completion in
                                                            guard case let .failure(error) = completion else { return }

                                                            self.error = error
                                                            self.isErrorPresented = true
                                                        } receiveValue: { success in
                                                            if success {
                                                                bookmarks[index] += 1

                                                                withAnimation(.easeInOut) {
                                                                    state = .data(bookmarks)
                                                                }
                                                            }
                                                        }
                                                        .store(in: &subscriptions)
                                                }
                                            }
                                        } label: {
                                            HStack(alignment: .center) {
                                                if #available(macOS 14.0, *) {
                                                    Image(systemName: isChecked ? "bookmark.fill" : "bookmark")
                                                        .contentTransition(.symbolEffect(.replace))

                                                    Text(verbatim: "\(bookmark.name) (\(bookmark.count.description))")
                                                        .monospacedDigit()
                                                        .lineLimit(nil)
                                                        .multilineTextAlignment(.center)
                                                        .contentTransition(.numericText(value: Double(bookmark.count)))
                                                } else {
                                                    Image(systemName: isChecked ? "bookmark.fill" : "bookmark")

                                                    Text(verbatim: "\(bookmark.name) (\(bookmark.count.description))")
                                                        .monospacedDigit()
                                                        .lineLimit(nil)
                                                        .multilineTextAlignment(.center)
                                                }
                                            }
                                            .highlightOnHover()
                                        }
                                        .buttonStyle(.plain)
                                        .changeEffect(
                                            .rise(origin: UnitPoint(x: 0.5, y: 0.25), layer: .named("rise")) {
                                                Text(verbatim: bookmarks[index].firstState != true ? "+1" : "-1")
                                                Text(verbatim: bookmarks[index].firstState != true ? "-1" : "+1")
                                            },
                                            value: bookmark.count
                                        )
                                        .disabled(movie.movieId.id == nil)
                                    }
                                }
                            }
                            .padding(5)
                            .onGeometryChange(for: CGSize.self) { geometry in
                                geometry.size
                            } action: { size in
                                withAnimation(.easeInOut) {
                                    self.scrollViewContentSize = size
                                }
                            }
                        }
                        .scrollIndicators(.never)
                        .frame(maxWidth: .infinity)
                        .frame(height: scrollViewContentSize.height > 140 ? 140 : scrollViewContentSize.height)
                        .background(.quinary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.tertiary, lineWidth: 1)
                        }
                    }
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            VStack(alignment: .center, spacing: 10) {
                Button {
                    isCreateBookmarkPresented = true
                } label: {
                    Text("key.create")
                        .frame(width: 250, height: 30)
                        .background(.quinary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                Button {
                    dismiss()
                } label: {
                    Text("key.done")
                        .frame(width: 250, height: 30)
                        .background(.quinary.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 35)
        .padding(.top, 35)
        .padding(.bottom, 25)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: 520)
        .task {
            getMovieBookmarksUseCase(movieId: movie.movieId)
                .receive(on: DispatchQueue.main)
                .sink { completion in
                    guard case let .failure(error) = completion else { return }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeInOut) {
                            state = .error(error as NSError)
                        }
                    }
                } receiveValue: { bookmarks in
                    withAnimation(.easeInOut) {
                        self.state = .data(bookmarks)
                    }
                }
                .store(in: &subscriptions)
        }
        .alert("key.ops", isPresented: $isErrorPresented) {
            Button(role: .cancel) {
                dismiss()
            } label: {
                Text("key.ok")
            }
        } message: {
            if let error {
                Text(error.localizedDescription)
            }
        }
        .dialogSeverity(.critical)
        .particleLayer(name: "rise")
    }
}
