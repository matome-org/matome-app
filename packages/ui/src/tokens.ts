export type ThemeMode = 'light' | 'dark';

type SemanticColorTokens = {
  background: string;
  foreground: string;
  border: string;
  input: string;
  primary: string;
  primaryForeground: string;
  secondary: string;
  secondaryForeground: string;
  muted: string;
  mutedForeground: string;
  success: string;
  successForeground: string;
  accent: string;
  accentForeground: string;
  destructive: string;
  destructiveForeground: string;
  warning: string;
  warningForeground: string;
  card: string;
  cardForeground: string;
  sidebar: string;
  sidebarForeground: string;
  sidebarPrimary: string;
  sidebarPrimaryForeground: string;
};

export type DesignTokens = {
  color: {
    primitive: {
      gold: string;
      paper: string;
      ink: string;
      white: string;
      danger: string;
      successLight: string;
      successDark: string;
      warningDark: string;
      infoLight: string;
      infoDark: string;
    };
    light: SemanticColorTokens;
    dark: SemanticColorTokens;
  };
  spacing: {
    xs: number;
    sm: number;
    md: number;
    lg: number;
    xl: number;
    screenX: number;
    bottomNav: number;
  };
  radius: {
    sm: number;
    md: number;
    lg: number;
    xl: number;
    full: number;
  };
  typography: {
    fontFamily: {
      body: string;
    };
    text: {
      meta: number;
      caption: number;
      body: number;
      title: number;
      display: number;
    };
    weight: {
      regular: string;
      medium: string;
      semibold: string;
      bold: string;
    };
  };
};

export const tokens: DesignTokens = {
  color: {
    primitive: {
      gold: '#e1b346',
      paper: '#FAF8F3',
      ink: '#333333',
      white: '#ffffff',
      danger: '#e63946',
      successLight: '#1b7a3a',
      successDark: '#4caf50',
      warningDark: '#ffb020',
      infoLight: '#0066cc',
      infoDark: '#4da6ff',
    },
    light: {
      background: '#fdfdfd',
      foreground: '#333333',
      border: '#e0e0e0',
      input: '#ffffff',
      primary: '#e1b346',
      primaryForeground: '#333333',
      secondary: '#f5f5f5',
      secondaryForeground: '#333333',
      muted: '#f0f0f0',
      mutedForeground: '#666666',
      success: '#e1b346',
      successForeground: '#333333',
      accent: '#e1b346',
      accentForeground: '#333333',
      destructive: '#e63946',
      destructiveForeground: '#fdfdfd',
      warning: '#e1b346',
      warningForeground: '#333333',
      card: '#ffffff',
      cardForeground: '#333333',
      sidebar: '#ffffff',
      sidebarForeground: '#333333',
      sidebarPrimary: '#e1b346',
      sidebarPrimaryForeground: '#333333',
    },
    dark: {
      background: '#333333',
      foreground: '#fdfdfd',
      border: '#444444',
      input: '#363636',
      primary: '#e1b346',
      primaryForeground: '#333333',
      secondary: '#3a3a3a',
      secondaryForeground: '#fdfdfd',
      muted: '#2a2a2a',
      mutedForeground: '#c0c0c0',
      success: '#4caf50',
      successForeground: '#fdfdfd',
      accent: '#e1b346',
      accentForeground: '#333333',
      destructive: '#e63946',
      destructiveForeground: '#fdfdfd',
      warning: '#ffb020',
      warningForeground: '#333333',
      card: '#363636',
      cardForeground: '#fdfdfd',
      sidebar: '#333333',
      sidebarForeground: '#fdfdfd',
      sidebarPrimary: '#e1b346',
      sidebarPrimaryForeground: '#333333',
    },
  },
  spacing: {
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    screenX: 16,
    bottomNav: 84,
  },
  radius: {
    sm: 4,
    md: 8,
    lg: 12,
    xl: 32,
    full: 9999,
  },
  typography: {
    fontFamily: {
      body: 'Inter',
    },
    text: {
      meta: 11,
      caption: 13,
      body: 15,
      title: 24,
      display: 40,
    },
    weight: {
      regular: '400',
      medium: '500',
      semibold: '600',
      bold: '700',
    },
  },
};
