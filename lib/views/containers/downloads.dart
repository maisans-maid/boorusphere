import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../model/booru_post.dart';
import '../../provider/downloader.dart';
import 'post_detail.dart';

class DownloadsPage extends HookConsumerWidget {
  const DownloadsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloader = ref.watch(downloadProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          PopupMenuButton(
            onSelected: (value) {
              switch (value) {
                case 'clear-all':
                  downloader.clearAllTask();
                  break;
                default:
                  break;
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem(
                  value: 'clear-all',
                  child: Text('Clear all'),
                )
              ];
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            ...downloader.entries.map((it) {
              final fileName = downloader.getFileNameFromUrl(it.booru.src);
              final status = downloader.getStatusFromId(it.id);

              return ListTile(
                title: Text(fileName),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${status.describe()} • ${it.booru.serverName}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                leading: Card(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(it.booru.displayType == PostType.video
                        ? Icons.video_library
                        : Icons.photo),
                  ),
                ),
                trailing: PopupMenuButton(
                  onSelected: (value) {
                    switch (value) {
                      case 'retry':
                        downloader.retryTask(id: it.id);
                        break;
                      case 'cancel':
                        downloader.cancelTask(id: it.id);
                        break;
                      case 'clear':
                        downloader.clearTask(id: it.id);
                        break;
                      case 'show-detail':
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  PostDetails(booru: it.booru)),
                        );
                        break;
                      default:
                        break;
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      if (status == DownloadTaskStatus.canceled ||
                          status == DownloadTaskStatus.failed)
                        const PopupMenuItem(
                          value: 'retry',
                          child: Text('Retry'),
                        ),
                      if (status == DownloadTaskStatus.running)
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('Cancel'),
                        ),
                      const PopupMenuItem(
                        value: 'show-detail',
                        child: Text('Show detail'),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear'),
                      ),
                    ];
                  },
                ),
                dense: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                onTap: null,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
