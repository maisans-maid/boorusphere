import 'package:boorusphere/data/repository/download/entity/download_entry.dart';
import 'package:boorusphere/data/repository/download/entity/download_progress.dart';
import 'package:boorusphere/domain/provider.dart';
import 'package:boorusphere/domain/repository/download_repo.dart';
import 'package:boorusphere/presentation/provider/download/entity/downloads.dart';
import 'package:fast_immutable_collections/fast_immutable_collections.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'download_state.g.dart';

@riverpod
class DownloadState extends _$DownloadState {
  late DownloadRepo _repo;

  @override
  Downloads build() {
    _repo = ref.watch(downloadRepoProvider);
    Future(_populate);
    return const Downloads();
  }

  Future<void> _populate() async {
    state = Downloads(
      entries: _repo.getEntries().toIList(),
      progresses: (await _repo.getProgress()).toISet(),
    );
  }

  Future<void> add(DownloadEntry entry) async {
    await _repo.add(entry);
    state = state.copyWith(
      entries: state.entries.removeWhere((it) => it.id == entry.id).add(entry),
    );
  }

  Future<void> remove(String id) async {
    await _repo.remove(id);
    state = state.copyWith(
      entries: state.entries.removeWhere((it) => it.id == id),
      progresses: state.progresses.removeWhere((it) => it.id == id),
    );
  }

  Future<void> update(String id, DownloadEntry entry) async {
    await _repo.remove(id);
    await _repo.add(entry);
    state = state.copyWith(
      entries: state.entries.removeWhere((it) => it.id == entry.id).add(entry),
      progresses: state.progresses
          .removeWhere((it) => it.id == id || it.id == entry.id),
    );
  }

  updateProgress(DownloadProgress progress) {
    state = state.copyWith(
      progresses: state.progresses
          .removeWhere((it) => it.id == progress.id)
          .add(progress),
    );
  }

  Future<void> clear() async {
    await _repo.clear();
    state = const Downloads();
  }
}
