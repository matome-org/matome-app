export const themes = ['light', 'dark'] as const;
export type Theme = (typeof themes)[number];

export const defaultTheme: Theme = 'light';

/** Cookie that persists the user's chosen theme across requests. */
export const THEME_COOKIE = 'matome_theme';

export function isTheme(value: string | undefined | null): value is Theme {
  return value === 'light' || value === 'dark';
}

export function normalizeTheme(value: string | undefined | null): Theme {
  return isTheme(value) ? value : defaultTheme;
}
