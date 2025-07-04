import Defaults
import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()

    private let searchText: String

    init(searchText: String) {
        self.searchText = searchText
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: .infinity), spacing: 18, alignment: .topLeading),
    ]

    @State private var showBar: Bool = false

    @Default(.isLoggedIn) private var isLoggedIn

    var body: some View {
        Group {
            if let error = viewModel.state.error {
                ErrorStateView(error, viewModel.title) {
                    viewModel.load(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .padding(.vertical, 52)
                .padding(.horizontal, 36)
            } else if let movies = viewModel.state.data {
                if movies.isEmpty {
                    EmptyStateView(String(localized: "key.nothing_found"), viewModel.title, String(localized: "key.search.empty"))
                        .padding(.vertical, 52)
                        .padding(.horizontal, 36)
                } else {
                    VStack {
                        ScrollView(.vertical) {
                            VStack(spacing: 18) {
                                VStack(alignment: .leading) {
                                    Spacer()

                                    Text(viewModel.title)
                                        .font(.largeTitle.weight(.semibold))
                                        .lineLimit(1)

                                    Spacer()

                                    Divider()
                                }
                                .frame(height: 52)

                                LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
                                    ForEach(movies) { movie in
                                        CardView(movie: movie)
                                    }
                                }
                                .scrollTargetLayout()
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
                        .onScrollTargetVisibilityChange(idType: MovieSimple.ID.self) { onScreenCards in
                            if let last = movies.last, onScreenCards.contains(where: { $0 == last.id }), viewModel.paginationState == .idle {
                                viewModel.loadMore(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }

                        if viewModel.paginationState == .loading {
                            LoadingPaginationStateView()
                        }
                    }
                }
            } else {
                LoadingStateView(viewModel.title)
                    .padding(.vertical, 52)
                    .padding(.horizontal, 36)
            }
        }
        .navigationBar(title: viewModel.title, showBar: showBar, navbar: {
            if let movies = viewModel.state.data, !movies.isEmpty {
                Button {
                    viewModel.load(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
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
                viewModel.load(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
        .background(.background)
        .onChange(of: searchText.trimmingCharacters(in: .whitespacesAndNewlines)) {
            viewModel.load(query: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
