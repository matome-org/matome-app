'use client';

import { useState, useTransition } from 'react';

import { setThemeAction } from './actions';
import { normalizeTheme, type Theme } from './config';

/**
 * Theme switch hook for Client Components. Applies the theme to the document
 * root immediately (so the change is instant), then persists it via the server
 * action so SSR matches on the next request.
 */
export function useTheme(initial: Theme): {
  theme: Theme;
  setTheme: (theme: Theme) => void;
  pending: boolean;
} {
  const [theme, setThemeState] = useState<Theme>(initial);
  const [pending, startTransition] = useTransition();

  const setTheme = (next: Theme) => {
    const value = normalizeTheme(next);
    setThemeState(value);
    if (typeof document !== 'undefined') {
      document.documentElement.dataset.theme = value;
    }
    startTransition(() => {
      void setThemeAction(value);
    });
  };

  return { theme, setTheme, pending };
}
