import 'package:shonenx/core/models/anime/episode_model.dart';
import 'package:shonenx/core/models/anime/page_model.dart';
import 'package:shonenx/core/models/anime/source_model.dart';

abstract class AnimeProvider {
  final String providerName;
  final String baseUrl;
  final String apiUrl;

  AnimeProvider({required this.baseUrl, required this.providerName, required this.apiUrl});

  Future<HomePage> getHome();
  Future<DetailPage> getDetails(String animeId);
  Future<BaseEpisodeModel> getEpisodes(String animeId);
  Future<BaseSourcesModel> getSources(
      String animeId, String episodeId, String? serverName, String? category);
  Future<SearchPage> getSearch(String keyword, String? type, int page);
  Future<SearchPage> getPage(String route, int page);
  Future<WatchPage> getWatch(String animeId);
  Future<List<String>> getSupportedServers();
  bool getDubSubParamSupport();
}
