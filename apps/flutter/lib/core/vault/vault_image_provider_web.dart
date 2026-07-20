import 'package:flutter/widgets.dart';

ImageProvider<Object> imageProviderForVaultLease(Uri location) =>
    NetworkImage(location.toString());
