import 'package:auto_route/auto_route.dart';
import 'package:boorusphere/presentation/i18n/strings.g.dart';
import 'package:boorusphere/presentation/provider/settings/content_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/server_setting_state.dart';
import 'package:boorusphere/presentation/provider/settings/ui_setting_state.dart';
import 'package:boorusphere/presentation/routes/app_router.dart';
import 'package:boorusphere/presentation/utils/extensions/buildcontext.dart';
import 'package:boorusphere/presentation/utils/hooks/markmayneedrebuild.dart';
import 'package:boorusphere/utils/download.dart';
import 'package:extended_image/extended_image.dart' as extended_image;
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.t.settings.title)),
      body: SafeArea(
        child: ListView(
          children: [
            _Section(
              title: Text(context.t.downloads.title),
              children: const [
                _HideMedia(),
              ],
            ),
            _Section(
              title: Text(context.t.settings.interface),
              children: const [
                _Language(),
                _MidnightMode(),
                _UiBlur(),
              ],
            ),
            _Section(
              title: Text(context.t.settings.safeMode),
              children: const [
                _BlurContent(),
                _StrictSafeMode(),
                _ImeIncognito(),
              ],
            ),
            _Section(
              title: Text(context.t.servers.title),
              children: const [
                _LoadOriginal(),
                _PostLimit(),
              ],
            ),
            _Section(
              title: Text(context.t.settings.misc),
              children: const [
                _BackupRestore(),
                _ClearCache(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, this.children = const []});

  final Widget title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const sectionPadding = EdgeInsets.fromLTRB(22, 12, 22, 12);
    final sectionStyle = context.theme.textTheme.subtitle2!
        .copyWith(color: context.colorScheme.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: sectionPadding,
          child: DefaultTextStyle(
            style: sectionStyle,
            child: title,
          ),
        ),
        ...children,
      ],
    );
  }
}

class _HideMedia extends HookWidget {
  const _HideMedia();

  @override
  Widget build(BuildContext context) {
    final markMayNeedRebuild = useMarkMayNeedRebuild();

    return FutureBuilder(
      future: DownloadUtils.hasDotnomedia,
      initialData: false,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final value = data is bool ? data : false;
        return SwitchListTile(
          title: Text(context.t.settings.hideMedia.title),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(context.t.settings.hideMedia.desc),
          ),
          value: value,
          onChanged: (isEnabled) async {
            isEnabled
                ? await DownloadUtils.createDotnomedia()
                : await DownloadUtils.removeDotnomedia();
            markMayNeedRebuild();
          },
        );
      },
    );
  }
}

class _CurrentLanguage extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(uiSettingStateProvider.select((ui) => ui.locale));

    return Text(
      locale == null
          ? context.t.settings.lang.auto.title
          : context.t.languageName,
    );
  }
}

class _MidnightMode extends ConsumerWidget {
  const _MidnightMode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(context.t.settings.midnightTheme.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.midnightTheme.desc),
      ),
      value: ref.watch(uiSettingStateProvider.select((ui) => ui.midnightMode)),
      onChanged: (value) {
        ref.read(uiSettingStateProvider.notifier).setMidnightMode(value);
      },
    );
  }
}

class _UiBlur extends ConsumerWidget {
  const _UiBlur();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(context.t.settings.uiBlur.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.uiBlur.desc),
      ),
      value: ref.watch(uiSettingStateProvider.select((ui) => ui.blur)),
      onChanged: (value) {
        ref.read(uiSettingStateProvider.notifier).showBlur(value);
      },
    );
  }
}

class _BlurContent extends ConsumerWidget {
  const _BlurContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(context.t.settings.blurContent.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.blurContent.desc),
      ),
      value: ref
          .watch(contentSettingStateProvider.select((it) => it.blurExplicit)),
      onChanged: (value) {
        ref
            .read(contentSettingStateProvider.notifier)
            .setBlurExplicitPost(value);
      },
    );
  }
}

class _StrictSafeMode extends ConsumerWidget {
  const _StrictSafeMode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(context.t.settings.strictSafeMode.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.strictSafeMode.desc),
      ),
      value: ref.watch(serverSettingStateProvider.select((it) => it.safeMode)),
      onChanged: (value) {
        ref.read(serverSettingStateProvider.notifier).setSafeMode(value);
      },
    );
  }
}

class _ImeIncognito extends ConsumerWidget {
  const _ImeIncognito();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(context.t.settings.imeIncognito.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.imeIncognito.desc),
      ),
      value: ref.watch(uiSettingStateProvider.select((ui) => ui.imeIncognito)),
      onChanged: (value) {
        ref.read(uiSettingStateProvider.notifier).setImeIncognito(value);
      },
    );
  }
}

class _Language extends StatelessWidget {
  const _Language();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(context.t.settings.lang.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _CurrentLanguage(),
      ),
      onTap: () {
        context.router.push(const LanguageSettingsRoute());
      },
    );
  }
}

class _LoadOriginal extends ConsumerWidget {
  const _LoadOriginal();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SwitchListTile(
      title: Text(context.t.settings.loadOg.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.loadOg.desc),
      ),
      value: ref
          .watch(contentSettingStateProvider.select((it) => it.loadOriginal)),
      onChanged: (value) {
        ref
            .read(contentSettingStateProvider.notifier)
            .setLoadOriginalPost(value);
      },
    );
  }
}

class _PostLimit extends ConsumerWidget {
  const _PostLimit();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(context.t.settings.postLimit.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.postLimit.desc),
      ),
      trailing: DropdownButton(
        menuMaxHeight: 178,
        value:
            ref.watch(serverSettingStateProvider.select((it) => it.postLimit)),
        elevation: 1,
        underline: const SizedBox.shrink(),
        borderRadius: const BorderRadius.all(Radius.circular(5)),
        items: List<DropdownMenuItem<int>>.generate(
          10,
          (i) {
            final x = i * 10 + 10;
            return DropdownMenuItem(
              value: x,
              child: Text('$x'),
            );
          },
        ),
        onChanged: (value) {
          ref
              .read(serverSettingStateProvider.notifier)
              .setPostLimit(value as int);
        },
      ),
    );
  }
}

class _BackupRestore extends StatelessWidget {
  const _BackupRestore();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(context.t.dataBackup.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.dataBackup.desc),
      ),
      onTap: () {
        context.router.push(const DataBackupRoute());
      },
    );
  }
}

class _ClearCache extends ConsumerWidget {
  const _ClearCache();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      title: Text(context.t.settings.clearCache.title),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(context.t.settings.clearCache.desc),
      ),
      onTap: () async {
        context.scaffoldMessenger.showSnackBar(SnackBar(
          content: Text(context.t.clearing),
          duration: const Duration(milliseconds: 500),
        ));

        await DefaultCacheManager().emptyCache();
        await extended_image.clearDiskCachedImages();
        extended_image.clearMemoryImageCache();

        context.scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(context.t.settings.clearCache.done),
            duration: const Duration(milliseconds: 500),
          ),
        );
      },
    );
  }
}
