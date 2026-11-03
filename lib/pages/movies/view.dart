import 'package:PiliPlus/pages/movies/movie_catalog_service.dart';
import 'package:PiliPlus/pages/recorder_center/recorder_material_localizations.dart';
import 'package:PiliPlus/pages/webview/view.dart';
import 'package:PiliPlus/http/init.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class MovieHomePage extends StatefulWidget {
  const MovieHomePage({this.service, super.key});

  @visibleForTesting
  final MovieCatalogService? service;

  @override
  State<MovieHomePage> createState() => _MovieHomePageState();
}

class _MovieHomePageState extends State<MovieHomePage> {
  static const _categories = <(String, String)>[
    ('电视剧热播', 'tv'),
    ('电影热播', 'movie'),
    ('动漫热播', 'anime'),
    ('综艺热播', 'variety'),
  ];

  late final _service = widget.service ?? MovieCatalogService();
  final _searchController = TextEditingController();
  late Map<String, Future<List<MovieHotItem>>> _sections;

  @override
  void initState() {
    super.initState();
    Request.proxyConfigurationVersion.addListener(_onProxyConfigurationChanged);
    _loadSections();
  }

  void _onProxyConfigurationChanged() {
    if (mounted) setState(_loadSections);
  }

  void _loadSections() {
    _sections = {
      for (final category in _categories)
        category.$2: _service.fetchHot(category.$2),
    };
  }

  @override
  void dispose() {
    Request.proxyConfigurationVersion.removeListener(
      _onProxyConfigurationChanged,
    );
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(_loadSections);
    await Future.wait(
      _sections.values.map(
        (future) => future.catchError((_) => <MovieHotItem>[]),
      ),
    );
  }

  void _search(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    Get.to(() => MovieSearchPage(query: query));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RecorderMaterialLocalizations(
      child: Scaffold(
        appBar: AppBar(title: const Text('影视')),
        backgroundColor: colors.surfaceContainerLowest,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Material(
                    color: colors.surfaceContainerLow,
                    shape: StadiumBorder(
                      side: BorderSide(color: colors.outlineVariant),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      onSubmitted: _search,
                      decoration: InputDecoration(
                        hintText: '搜索电影、电视剧或动漫',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          tooltip: '搜索',
                          onPressed: () => _search(_searchController.text),
                          icon: const Icon(Icons.arrow_forward_rounded),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              for (final category in _categories)
                _buildSection(category.$1, category.$2),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
                  child: Text(
                    '影片信息由 SOTVLA 提供；选择影片后将在应用内打开来源页面。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String tab) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: FutureBuilder<List<MovieHotItem>>(
        future: _sections[tab],
        builder: (context, snapshot) {
          final colors = Theme.of(context).colorScheme;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (snapshot.hasError)
                _SectionError(onRetry: () => setState(_loadSections))
              else if (snapshot.hasData && snapshot.data!.isNotEmpty)
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: snapshot.data!.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = snapshot.data![index];
                      return _HotMovieCard(
                        item: item,
                        onTap: () => _search(item.title),
                      );
                    },
                  ),
                )
              else if (snapshot.hasData)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Text(
                    '暂无热播内容',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                )
              else
                const SizedBox(height: 250),
            ],
          );
        },
      ),
    ),
  );
}

class MovieSearchPage extends StatefulWidget {
  const MovieSearchPage({required this.query, super.key});

  final String query;

  @override
  State<MovieSearchPage> createState() => _MovieSearchPageState();
}

class _MovieSearchPageState extends State<MovieSearchPage> {
  final _service = MovieCatalogService();
  late Future<MovieSearchResponse> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.search(widget.query);
  }

  @override
  Widget build(BuildContext context) => RecorderMaterialLocalizations(
    child: Scaffold(
      appBar: AppBar(title: Text('搜索「${widget.query}」')),
      body: FutureBuilder<MovieSearchResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _PageMessage(
              icon: Icons.wifi_off_rounded,
              title: '暂时无法获取搜索结果',
              message: '影视站接口可能暂时不可用，请稍后重试。',
              action: FilledButton.tonal(
                onPressed: () => setState(() {
                  _future = _service.search(widget.query);
                }),
                child: const Text('重试'),
              ),
            );
          }
          final result = snapshot.data!;
          if (result.items.isEmpty) {
            return const _PageMessage(
              icon: Icons.movie_outlined,
              title: '没有找到相关影片',
              message: '试试简短片名或其他关键词。',
            );
          }
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Text(
                    '找到 ${result.total} 个结果',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid.builder(
                  itemCount: result.items.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.52,
                  ),
                  itemBuilder: (context, index) => _SearchMovieCard(
                    item: result.items[index],
                    onTap: () => Get.to(
                      () => WebviewPage(
                        url: result.items[index].detailUrl.toString(),
                        title: result.items[index].title,
                        movieShell: true,
                        moviePosterUrl: result.items[index].posterUrl,
                      ),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          );
        },
      ),
    ),
  );
}

class _HotMovieCard extends StatelessWidget {
  const _HotMovieCard({required this.item, required this.onTap});

  final MovieHotItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 136,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox.expand(child: _MoviePoster(url: item.posterUrl)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    ),
  );
}

class _SearchMovieCard extends StatelessWidget {
  const _SearchMovieCard({required this.item, required this.onTap});

  final MovieSearchItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox.expand(child: _MoviePoster(url: item.posterUrl)),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (item.year.isNotEmpty || item.category.isNotEmpty)
          Text(
            [
              item.year,
              item.category,
            ].where((value) => value.isNotEmpty).join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    ),
  );
}

class _MoviePoster extends StatelessWidget {
  const _MoviePoster({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceContainerHigh, colors.surfaceContainerLowest],
        ),
      ),
      child: url.isEmpty
          ? Center(
              child: Icon(Icons.movie_outlined, color: colors.onSurfaceVariant),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              // Poster sources often return large originals. Decode close to
              // the largest rendered card size instead of keeping full-size
              // images in Flutter's image cache while scrolling the rails.
              cacheWidth: 420,
              // Avoid a separate animated progress indicator for every
              // poster; the decorated gradient remains visible until frame 1.
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) return child;
                return const SizedBox.expand();
              },
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.movie_outlined,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '热播内容加载失败',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    ),
  );
}
