import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider<Object> imageProviderForVaultLease(Uri location) =>
    FileImage(File.fromUri(location));
