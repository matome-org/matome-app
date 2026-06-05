import { tokens, type ThemeMode } from './tokens';

const cssTokenNames: Record<string, string> = {
  background: 'background',
  foreground: 'foreground',
  border: 'border',
  input: 'input',
  primary: 'primary',
  primaryForeground: 'primary-foreground',
  secondary: 'secondary',
  secondaryForeground: 'secondary-foreground',
  muted: 'muted',
  mutedForeground: 'muted-foreground',
  success: 'success',
  successForeground: 'success-foreground',
  accent: 'accent',
  accentForeground: 'accent-foreground',
  destructive: 'destructive',
  destructiveForeground: 'destructive-foreground',
  warning: 'warning',
  warningForeground: 'warning-foreground',
  card: 'card',
  cardForeground: 'card-foreground',
  sidebar: 'sidebar',
  sidebarForeground: 'sidebar-foreground',
  sidebarPrimary: 'sidebar-primary',
  sidebarPrimaryForeground: 'sidebar-primary-foreground',
};

export const createCssVariables = (mode: ThemeMode): string => {
  const colors = tokens.color[mode];
  const colorLines = Object.entries(cssTokenNames).map(
    ([tokenName, cssName]) => `  --${cssName}: ${colors[tokenName as keyof typeof colors]};`,
  );
  const radiusLines = Object.entries(tokens.radius).map(
    ([name, value]) => `  --radius-${name}: ${value}px;`,
  );
  const spacingLines = Object.entries(tokens.spacing).map(
    ([name, value]) => `  --spacing-${name.replace(/[A-Z]/g, (letter) => `-${letter.toLowerCase()}`)}: ${value}px;`,
  );
  const typographyLines = [
    `  --font-family-body: ${tokens.typography.fontFamily.body};`,
    ...Object.entries(tokens.typography.text).map(([name, value]) => `  --font-size-${name}: ${value}px;`),
    ...Object.entries(tokens.typography.weight).map(([name, value]) => `  --font-weight-${name}: ${value};`),
  ];

  return [...colorLines, ...radiusLines, ...spacingLines, ...typographyLines].join('\n');
};

export const cssVariables = `:root {\n${createCssVariables('light')}\n}\n\n[data-theme='dark'] {\n${createCssVariables('dark')}\n}\n`;
