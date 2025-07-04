import Defaults
import SwiftUI

struct ListView: View {
    @State private var viewModel: ListViewModel

    init(movies: [MovieSimple], title: String) {
        viewModel = ListViewModel(movies: movies, title: title)
    }

    init(list: MovieList) {
        viewModel = ListViewModel(list: list)
    }

    init(country: MovieCountry) {
        viewModel = ListViewModel(country: country)
    }

    init(genre: MovieGenre) {
        viewModel = ListViewModel(genre: genre)
    }

    init(category: Categories) {
        viewModel = ListViewModel(category: category)
    }

    init(collection: MoviesCollection) {
        viewModel = ListViewModel(collection: collection)
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: .infinity), spacing: 18, alignment: .topLeading)]

    @State private var showBar: Bool = false

    @Default(.isLoggedIn) private var isLoggedIn

    var body: some View {
        Group {
            if let error = viewModel.state.error {
                ErrorStateView(error, viewModel.title) {
                    viewModel.load()
                }
                .padding(.vertical, 52)
                .padding(.horizontal, 36)
            } else if let movies = viewModel.state.data {
                if movies.isEmpty {
                    EmptyStateView(String(localized: "key.nothing_found"), viewModel.title, String(localized: "key.filter.empty")) {
                        viewModel.load()
                    }
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
                                viewModel.loadMore()
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
                    viewModel.load()
                } label: {
                    Image(systemName: "arrow.trianglehead.clockwise")
                }
                .buttonStyle(NavbarButtonStyle(width: 30, height: 22))
                .keyboardShortcut("r", modifiers: .command)
            }
        }, toolbar: {
            if viewModel.state != .loading, !viewModel.isCustomMovies, !viewModel.isList {
                Image(systemName: "line.3.horizontal.decrease.circle")

                if viewModel.isGenre || viewModel.isCollection || viewModel.isCountry {
                    Picker("key.filter.select", selection: $viewModel.filter) {
                        ForEach(Filters.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                }

                if viewModel.isCategory(.newest) {
                    Picker("key.filter.select", selection: $viewModel.newFilter) {
                        ForEach(NewFilters.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))

                    Divider()
                        .padding(.vertical, 18)
                }

                if viewModel.isCountry {
                    Divider()
                        .padding(.vertical, 18)
                }

                if viewModel.isCategory || viewModel.isCountry {
                    Picker("key.genre.select", selection: $viewModel.filterGenre) {
                        ForEach(Genres.allCases.filter { $0 != .show || !viewModel.isCategory(.hot) }) { genre in
                            Text(genre.rawValue).tag(genre)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .buttonStyle(.accessoryBar)
                    .controlSize(.large)
                    .background(.tertiary.opacity(0.05))
                    .clipShape(.rect(cornerRadius: 6))
                    .contentShape(.rect(cornerRadius: 6))
                    .overlay(.tertiary.opacity(0.2), in: .rect(cornerRadius: 6).stroke(lineWidth: 1))
                }
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
        .onChange(of: viewModel.filterGenre) {
            viewModel.load()
        }
        .onChange(of: viewModel.filter) {
            viewModel.load()
        }
        .onChange(of: viewModel.newFilter) {
            viewModel.load()
        }
        .background(.background)
    }
}

enum Genres: LocalizedStringKey, CaseIterable, Identifiable {
    case all = "key.genres.all"
    case films = "key.genres.films"
    case series = "key.genres.series"
    case cartoons = "key.genres.cartoons"
    case anime = "key.genres.anime"
    case show = "key.genres.show"

    var id: Genres { self }

    var genreCode: Int {
        switch self {
        case .all:
            0
        case .films:
            1
        case .series:
            2
        case .cartoons:
            3
        case .anime:
            82
        case .show:
            4
        }
    }
}

enum Filters: LocalizedStringKey, CaseIterable, Identifiable {
    case latest = "key.filters.latest"
    case popular = "key.filters.popular"
    case soon = "key.filters.soon"
    case watching = "key.filters.watching_now"

    var id: Filters { self }
}

enum NewFilters: LocalizedStringKey, CaseIterable, Identifiable {
    case latest = "key.filters.latest"
    case popular = "key.filters.popular"
    case watching = "key.filters.watching_now"

    var id: NewFilters { self }
}
