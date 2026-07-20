import 'package:flutter/widgets.dart';

import 'vault_image_provider_io.dart'
    if (dart.library.js_interop) 'vault_image_provider_web.dart'
    as platform;

ImageProvider<Object> imageProviderForVaultLease(Uri location) =>
    platform.imageProviderForVaultLease(location);
