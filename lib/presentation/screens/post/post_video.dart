import 'dart:async';

import 'package:async/async.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/provider/booru/post_headers_factory.dart';
import 'package:boorusphere/presentation/provider/cache.dart';
import 'package:boorusphere/presentation/provider/fullscreen_state.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/screens/post/post_explicit_warning.dart';
import 'package:boorusphere/presentation/screens/post/post_placeholder_image.dart';
import 'package:boorusphere/presentation/screens/post/post_toolbox.dart';
import 'package:boorusphere/presentation/utils/extensions/post.dart';
import 'package:boorusphere/presentation/utils/hooks/markmayneedrebuild.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:video_player/video_player.dart';

part 'post_video.g.dart';

Future<FileInfo> _fetchVideo(
  Ref ref,
  Post post,
) async {
  final headers = await ref.read(postHeadersFactoryProvider).build(post);
  return ref
      .read(cacheManagerProvider)
      .downloadFile(post.content.url, authHeaders: headers);
}

@riverpod
CancelableOperation<FileInfo> videoPlayerSource(
  VideoPlayerSourceRef ref,
  Post post,
) {
  final cancelable = CancelableOperation.fromFuture(_fetchVideo(ref, post));

  ref.onDispose(() {
    if (!cancelable.isCompleted) {
      cancelable.cancel();
    }
  });

  return cancelable;
}

@riverpod
Future<VideoPlayerController> videoPlayerController(
  VideoPlayerControllerRef ref,
  Post post,
) async {
  VideoPlayerController controller;

  final cache = ref.watch(cacheManagerProvider);
  final fromCache = await cache.getFileFromCache(post.content.url);
  final option = VideoPlayerOptions(mixWithOthers: true);
  if (fromCache != null) {
    controller = VideoPlayerController.file(
      fromCache.file,
      videoPlayerOptions: option,
    );
  } else {
    final fetcher = ref.watch(videoPlayerSourceProvider(post));
    final fromNet = await fetcher.value;
    controller = VideoPlayerController.file(
      fromNet.file,
      videoPlayerOptions: option,
    );
  }

  ref.onDispose(() {
    controller.pause();
    controller.dispose();
  });

  return controller;
}

class PostVideo extends HookConsumerWidget {
  const PostVideo({
    super.key,
    required this.post,
    this.heroTag,
    required this.onToolboxVisibilityChange,
  });

  final Post post;
  final Object? heroTag;
  final void Function(bool visible) onToolboxVisibilityChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controllerFuture = ref.watch(videoPlayerControllerProvider(post));
    final blurExplicit =
        ref.watch(contentSettingStateProvider.select((it) => it.blurExplicit));

    final isMounted = useIsMounted();
    final shouldBlur = post.rating == PostRating.explicit && blurExplicit;
    final isBlur = useState(shouldBlur);
    final blurNoticeAnimator =
        useAnimationController(duration: const Duration(milliseconds: 200));
    final showToolbox = useState(true);

    useEffect(() {
      Future(() {
        if (isMounted() && shouldBlur) {
          blurNoticeAnimator.forward();
        }
      });
    }, []);

    return Stack(
      alignment: Alignment.center,
      fit: StackFit.passthrough,
      children: [
        Hero(
          key: ValueKey(post),
          tag: heroTag ?? post.id,
          child: Center(
            child: AspectRatio(
              aspectRatio: post.aspectRatio,
              child: isBlur.value
                  ? PostPlaceholderImage(post: post, shouldBlur: true)
                  : controllerFuture.maybeWhen(
                      data: (controller) => Stack(
                        fit: StackFit.passthrough,
                        children: [
                          PostPlaceholderImage(
                            post: post,
                            shouldBlur: false,
                          ),
                          VideoPlayer(controller),
                        ],
                      ),
                      orElse: () => PostPlaceholderImage(
                        post: post,
                        shouldBlur: false,
                      ),
                    ),
            ),
          ),
        ),
        _Toolbox(
          post: post,
          controller: isBlur.value
              ? null
              : controllerFuture.whenOrNull(data: (it) => it),
          disableProgressBar: isBlur.value,
          visible: showToolbox.value,
          onVisibilityChange: (value) {
            showToolbox.value = value;
            onToolboxVisibilityChange.call(value);
          },
        ),
        if (isBlur.value)
          FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(
                parent: blurNoticeAnimator,
                curve: Curves.easeInCubic,
              ),
            ),
            child: Center(
              child: PostExplicitWarningCard(
                onConfirm: () async {
                  await blurNoticeAnimator.reverse();
                  isBlur.value = false;
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _Toolbox extends HookConsumerWidget {
  const _Toolbox({
    required this.post,
    required this.controller,
    this.disableProgressBar = false,
    required this.visible,
    required this.onVisibilityChange,
  });

  final Post post;
  final VideoPlayerController? controller;
  final bool disableProgressBar;
  final bool visible;
  final void Function(bool visible) onVisibilityChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = this.controller;
    final isMuted =
        ref.watch(contentSettingStateProvider.select((it) => it.videoMuted));
    final fullscreen = ref.watch(fullscreenStateProvider);
    final markMayNeedRebuild = useMarkMayNeedRebuild();
    final isPlaying = useState(true);
    final isMounted = useIsMounted();

    autoHideToolbox() {
      Future.delayed(const Duration(seconds: 2), () {
        if (isMounted()) {
          onVisibilityChange.call(false);
        }
      });
    }

    useEffect(() {
      controller?.setLooping(true);
      controller?.initialize().whenComplete(() {
        onFirstFrame() {
          markMayNeedRebuild();
          controller.removeListener(onFirstFrame);
        }

        controller.addListener(onFirstFrame);
        controller.setVolume(isMuted ? 0 : 1);
        if (isPlaying.value) {
          controller.play();
          autoHideToolbox();
        }
      });
    }, [controller]);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        onVisibilityChange.call(!visible);
      },
      child: Container(
        color: visible ? Colors.black38 : Colors.transparent,
        child: !visible
            ? const SizedBox.expand()
            : Stack(
                alignment: Alignment.center,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.black38,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: const EdgeInsets.all(8.0),
                      color: Colors.white,
                      iconSize: 72,
                      icon: Icon(
                        isPlaying.value
                            ? Icons.pause_outlined
                            : Icons.play_arrow,
                      ),
                      onPressed: () {
                        if (controller != null) {
                          isPlaying.value = !controller.value.isPlaying;
                          controller.value.isPlaying
                              ? controller.pause()
                              : controller.play();
                        } else {
                          isPlaying.value = !isPlaying.value;
                        }
                      },
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            PostFavoriteButton(post: post),
                            PostDownloadButton(post: post),
                            IconButton(
                              padding: const EdgeInsets.all(16),
                              color: Colors.white,
                              onPressed: () async {
                                final mute = await ref
                                    .read(contentSettingStateProvider.notifier)
                                    .toggleVideoPlayerMute();
                                await controller?.setVolume(mute ? 0 : 1);
                              },
                              icon: Icon(
                                isMuted ? Icons.volume_mute : Icons.volume_up,
                              ),
                            ),
                            PostDetailsButton(post: post),
                            IconButton(
                              color: Colors.white,
                              icon: Icon(
                                fullscreen
                                    ? Icons.fullscreen_exit
                                    : Icons.fullscreen_outlined,
                              ),
                              padding: const EdgeInsets.all(16),
                              onPressed: () {
                                ref
                                    .read(fullscreenStateProvider.notifier)
                                    .toggle(
                                        shouldLandscape:
                                            post.width > post.height);
                                autoHideToolbox();
                              },
                            ),
                          ],
                        ),
                        _Progress(
                          controller: controller,
                          enabled: !disableProgressBar,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({this.controller, this.enabled = true});

  final VideoPlayerController? controller;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final player = controller;

    if (!enabled) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: LinearProgressIndicator(
          value: 0,
          backgroundColor: Colors.white.withAlpha(20),
        ),
      );
    }

    if (player == null || !player.value.isInitialized) {
      return Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 16),
        child: LinearProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.redAccent.shade700,
          ),
          backgroundColor: Colors.white.withAlpha(20),
        ),
      );
    }

    return VideoProgressIndicator(
      player,
      colors: VideoProgressColors(
        playedColor: Colors.redAccent.shade700,
        backgroundColor: Colors.white.withAlpha(20),
      ),
      allowScrubbing: true,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
    );
  }
}
