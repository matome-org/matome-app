import 'package:matome_vault/matome_vault.dart';

import 'account_store_opener_native.dart'
    if (dart.library.js_interop) 'account_store_opener_web.dart'
    as platform;
import 'vault_boot_coordinator.dart' show VaultOpenedStores;

Future<VaultOpenedStores> openAccountStores(VaultKeyMaterial material) =>
    platform.openAccountStores(material);
