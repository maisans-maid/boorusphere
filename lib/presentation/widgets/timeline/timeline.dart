import 'dart:ui';

import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/routes/app_router.dart';
import 'package:boorusphere/presentation/screens/post/hooks/post_headers.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/utils/extensions/post.dart';
import 'package:boorusphere/presentation/widgets/timeline/timeline_controller.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tinycolor2/tinycolor2.dart';

class Timeline extends ConsumerWidget {
  const Timeline({
    super.key,
    required this.controller,
    required this.posts,
  });

  final TimelineController controller;
  final Iterable<Post> posts;

  String buildHeroTag(Post post) {
    return '${controller.hashCode}-${post.serverId}@${post.id}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(uiSettingStateProvider.select((ui) => ui.grid));
    final screenWidth = context.mediaQuery.size.width;
    final flexibleGrid = (screenWidth / 200).round() + grid;
    final scrollController = controller.scrollController;

    return SliverMasonryGrid.count(
      crossAxisCount: flexibleGrid,
      key: ObjectKey(flexibleGrid),
      mainAxisSpacing: 5,
      crossAxisSpacing: 5,
      childCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts.elementAt(index);
        return AutoScrollTag(
          key: ValueKey(index),
          controller: scrollController,
          index: index,
          highlightColor: context.theme.colorScheme.surfaceTint,
          child: Card(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            // saveLayer() is used here to avoid artifacts that frequently
            // happened while scrolling
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: GestureDetector(
              child: Hero(
                tag: buildHeroTag(post),
                child: _Thumbnail(post: post),
                flightShuttleBuilder: (flightContext, animation,
                    flightDirection, fromHeroContext, toHeroContext) {
                  final Hero toHero = toHeroContext.widget as Hero;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: post.aspectRatio,
                        // clip incoming child to avoid overflow that might be
                        // caused by blurExplicit enabled
                        child: flightDirection == HeroFlightDirection.pop
                            ? ClipRect(child: toHero.child)
                            : toHero.child,
                      ),
                    ],
                  );
                },
              ),
              onTap: () {
                context.scaffoldMessenger.removeCurrentSnackBar();
                context.router.push(
                  PostRoute(
                    beginPage: index,
                    posts: posts,
                    heroTagBuilder: buildHeroTag,
                    onPop: controller.revealAt,
                    onLoadMore: controller.onLoadMore,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _Thumbnail extends HookConsumerWidget {
  const _Thumbnail({required this.post});
  final Post post;

  FilterQuality _thumbnailQuality(int gridExtra) {
    switch (gridExtra) {
      case 0:
        return FilterQuality.medium;
      case 1:
        return FilterQuality.low;
      default:
        return FilterQuality.none;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = ref.watch(uiSettingStateProvider.select((ui) => ui.grid));
    final blurExplicitPost =
        ref.watch(contentSettingStateProvider.select((it) => it.blurExplicit));
    final headers = usePostHeaders(ref, post);

    return AspectRatio(
      aspectRatio: post.aspectRatio,
      child: ExtendedImage.network(
        post.previewFile,
        headers: headers.data,
        filterQuality: _thumbnailQuality(grid),
        fit: BoxFit.cover,
        beforePaintImage: (canvas, rect, image, paint) {
          if (blurExplicitPost && post.rating == PostRating.explicit) {
            paint.imageFilter = ImageFilter.blur(
              sigmaX: 8,
              sigmaY: 8,
              tileMode: TileMode.decal,
            );
          }
          return false;
        },
        enableLoadState: false,
        loadStateChanged: (state) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: state.extendedImageLoadState == LoadState.completed
                ? state.completedWidget
                : _Placeholder(
                    key: ValueKey(post.id),
                    isFailed: state.extendedImageLoadState == LoadState.failed,
                  ),
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.center,
                fit: StackFit.passthrough,
                children: [
                  ...previousChildren,
                  if (currentChild != null) currentChild,
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    super.key,
    this.isFailed = false,
  });

  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    if (isFailed) {
      return const Material(child: Icon(Icons.broken_image_outlined));
    }

    final baseColor = context.isLightThemed
        ? context.colorScheme.background.desaturate(50).darken(2)
        : context.colorScheme.surface;
    final highlightColor = context.isLightThemed
        ? context.colorScheme.background.desaturate(50).lighten(2)
        : context.colorScheme.surface.lighten(5);

    return Shimmer(
      gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            baseColor,
            baseColor,
            highlightColor,
            baseColor,
            baseColor
          ],
          stops: const <double>[
            0.0,
            0.35,
            0.5,
            0.65,
            1.0
          ]),
      period: const Duration(milliseconds: 700),
      child: Container(
        color: Colors.black,
        child: const SizedBox.expand(),
      ),
    );
  }
}
