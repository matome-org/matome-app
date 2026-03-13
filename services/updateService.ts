import * as Updates from 'expo-updates';
import { Alert } from 'react-native';

export type UpdateStatus =
  | 'UP_TO_DATE'
  | 'UPDATE_AVAILABLE'
  | 'UPDATE_DOWNLOADED'
  | 'ERROR'
  | 'UNSUPPORTED';

export interface UpdateCheckResult {
  status: UpdateStatus;
  manifest?: Updates.UpdateManifest;
  error?: Error;
}

/**
 * Returns true when expo-updates is operational.
 * It is NOT available in Expo Go (development) or when updates.enabled is false.
 */
export const isUpdatesAvailable = (): boolean => Updates.isEnabled && !__DEV__;

/**
 * Checks for a new update from EAS Update.
 * Returns a structured result — never throws.
 */
export const checkForUpdate = async (): Promise<UpdateCheckResult> => {
  if (!isUpdatesAvailable()) return { status: 'UNSUPPORTED' };

  try {
    const result = await Updates.checkForUpdateAsync();
    return result.isAvailable
      ? { status: 'UPDATE_AVAILABLE', manifest: result.manifest }
      : { status: 'UP_TO_DATE' };
  } catch (error) {
    console.error('[updateService] checkForUpdate failed:', error);
    return { status: 'ERROR', error: error instanceof Error ? error : new Error(String(error)) };
  }
};

/**
 * Downloads the available update.
 * Call this only after checkForUpdate returns UPDATE_AVAILABLE.
 * Returns a structured result — never throws.
 */
export const downloadUpdate = async (): Promise<UpdateCheckResult> => {
  if (!isUpdatesAvailable()) return { status: 'UNSUPPORTED' };

  try {
    const result = await Updates.fetchUpdateAsync();
    return result.isNew
      ? { status: 'UPDATE_DOWNLOADED', manifest: result.manifest }
      : { status: 'UP_TO_DATE' };
  } catch (error) {
    console.error('[updateService] downloadUpdate failed:', error);
    return { status: 'ERROR', error: error instanceof Error ? error : new Error(String(error)) };
  }
};

/**
 * Triggers an immediate app reload to apply the downloaded update.
 * Only call after downloadUpdate returns UPDATE_DOWNLOADED.
 */
export const applyUpdate = async (): Promise<void> => {
  await Updates.reloadAsync();
};

/**
 * Full update flow: check → download → prompt user.
 * Designed to be called once at app launch (fire-and-forget).
 * Does not block the main launch flow.
 *
 * Strategy: silent download, then prompt the user with an Alert.
 * The user can choose "Restart Now" or "Later" (applied on next cold start).
 */
export const runUpdateFlow = async (): Promise<void> => {
  const checkResult = await checkForUpdate();
  if (checkResult.status !== 'UPDATE_AVAILABLE') return;

  const downloadResult = await downloadUpdate();
  if (downloadResult.status !== 'UPDATE_DOWNLOADED') return;

  Alert.alert(
    'Update Available',
    'A new version has been downloaded. Restart now to apply it.',
    [
      { text: 'Later', style: 'cancel' },
      {
        text: 'Restart Now',
        style: 'default',
        onPress: () => applyUpdate().catch(console.error),
      },
    ],
    { cancelable: false },
  );
};
