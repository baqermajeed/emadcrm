class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.page,
    required this.limit,
    required this.hasMore,
    this.total,
  });

  final List<T> items;
  final int page;
  final int limit;
  final bool hasMore;
  final int? total;
}
