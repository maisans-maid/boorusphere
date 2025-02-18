import 'dart:async';

import 'package:boorusphere/presentation/utils/entity/pixel_size.dart';
import 'package:flutter/widgets.dart';

extension ImageProviderExt<T> on ImageProvider {
  Future<PixelSize> resolvePixelSize() {
    final completer = Completer<PixelSize>();
    final resolver = resolve(const ImageConfiguration());
    final onComplete = ImageStreamListener((image, synchronousCall) {
      completer.complete(PixelSize(
        width: image.image.width,
        height: image.image.height,
      ));
    });
    resolver.addListener(onComplete);
    completer.future.whenComplete(() => resolver.removeListener(onComplete));
    return completer.future;
  }
}
