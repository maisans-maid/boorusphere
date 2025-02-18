import 'package:boorusphere/data/repository/booru/entity/post.dart';
import 'package:boorusphere/presentation/provider/booru/entity/fetch_result.dart';
import 'package:boorusphere/presentation/provider/booru/page_state.dart';
import 'package:boorusphere/presentation/provider/fullscreen_state.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/screens/post/hooks/precache_posts.dart';
import 'package:boorusphere/presentation/screens/post/post_image.dart';
import 'package:boorusphere/presentation/screens/post/post_toolbox.dart';
import 'package:boorusphere/presentation/screens/post/post_unknown.dart';
import 'package:boorusphere/presentation/screens/post/post_video.dart';
import 'package:boorusphere/presentation/utils/entity/content.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/utils/extensions/post.dart';
import 'package:boorusphere/presentation/utils/hooks/extended_page_controller.dart';
import 'package:boorusphere/presentation/widgets/slidefade_visibility.dart';
import 'package:boorusphere/presentation/widgets/styled_overlay_region.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:wakelock/wakelock.dart';

class PostPage extends HookConsumerWidget {
  const PostPage({
    super.key,
    required this.beginPage,
    required this.posts,
    this.heroTagBuilder,
    this.onPop,
    this.onLoadMore,
  });

  final int beginPage;
  final Iterable<Post> posts;
  final Object Function(Post)? heroTagBuilder;
  final void Function(int)? onPop;
  final void Function()? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const loadMoreThreshold = 90;
    final currentPage = useState(beginPage);
    final pageController =
        useExtendedPageController(initialPage: currentPage.value);
    final loadOriginal =
        ref.watch(contentSettingStateProvider.select((it) => it.loadOriginal));
    final pageState = ref.watch(pageStateProvider);
    final fullscreen = ref.watch(fullscreenStateProvider);

    final post =
        posts.isEmpty ? Post.empty : posts.elementAt(currentPage.value);
    final precachePosts = usePrecachePosts(ref, posts);
    final showAppbar = useState(true);

    useEffect(() {
      showAppbar.value = !fullscreen;
    }, [fullscreen]);

    useEffect(() {
      Wakelock.enable();
      return Wakelock.disable;
    }, []);

    return WillPopScope(
      onWillPop: () async {
        ref.watch(fullscreenStateProvider.notifier).reset();
        context.scaffoldMessenger.removeCurrentSnackBar();
        onPop?.call(currentPage.value);
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: StyledOverlayRegion(
          nightMode: true,
          child: Stack(
            children: [
              Padding(
                // android back gesture is not ignored by PageView
                // add tiny padding to avoid it
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: ExtendedImageGesturePageView.builder(
                  controller: pageController,
                  onPageChanged: (index) {
                    context.scaffoldMessenger.hideCurrentSnackBar();
                    currentPage.value = index;
                    final offset = index + 1;
                    final threshold =
                        posts.length / 100 * (100 - loadMoreThreshold);
                    if (offset + threshold > posts.length) {
                      onLoadMore?.call();
                    }
                  },
                  itemCount: posts.length,
                  itemBuilder: (_, index) {
                    precachePosts(index, loadOriginal);
                    final post = posts.elementAt(index);
                    final heroTag = heroTagBuilder?.call(post);
                    final Widget widget;
                    switch (post.content.type) {
                      case PostType.photo:
                        widget = PostImage(post: post, heroTag: heroTag);
                        break;
                      case PostType.video:
                        widget = PostVideo(
                          post: post,
                          heroTag: heroTag,
                          onToolboxVisibilityChange: (visible) {
                            showAppbar.value = visible;
                          },
                        );
                        break;
                      default:
                        widget = PostUnknown(post: post, heroTag: heroTag);
                        break;
                    }
                    return HeroMode(
                      enabled: index == currentPage.value,
                      child: widget,
                    );
                  },
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SlideFadeVisibility(
                  direction: HidingDirection.toTop,
                  visible: showAppbar.value,
                  child: _PostAppBar(
                    subtitle: post.describeTags,
                    title: pageState is LoadingFetchResult
                        ? '#${currentPage.value + 1} of (loading...)'
                        : '#${currentPage.value + 1} of ${posts.length}',
                  ),
                ),
              ),
              if (!post.content.isVideo)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SlideFadeVisibility(
                    direction: HidingDirection.toBottom,
                    visible: !fullscreen,
                    child: PostToolbox(post),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _PostAppBar({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomLeft,
          colors: [Colors.black54, Colors.transparent],
        ),
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w300),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 64);
}
