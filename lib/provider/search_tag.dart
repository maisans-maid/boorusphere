import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/server_data.dart';
import 'search_history.dart';

class SearchTagNotifier extends StateNotifier<String> {
  SearchTagNotifier(this.read) : super(ServerData.defaultTag);

  final Reader read;

  Future<void> setTag({required String query}) async {
    final searchHistory = read(searchHistoryProvider);
    if (state != query) {
      state = query;
      searchHistory.push(query);
    }
  }
}

final searchTagProvider = StateNotifierProvider<SearchTagNotifier, String>(
    (ref) => SearchTagNotifier(ref.read));
