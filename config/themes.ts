import * as eva from '@eva-design/eva';
import { ThemeType } from '@ui-kitten/components';

// Light theme colors from template_home_light.html
const lightThemeColors = {
  'color-primary-100': '#fef9e7',
  'color-primary-200': '#fef3cf',
  'color-primary-300': '#fdedb7',
  'color-primary-400': '#fce79f',
  'color-primary-500': '#e1b346', // Main accent color
  'color-primary-600': '#b89038',
  'color-primary-700': '#8f6d2a',
  'color-primary-800': '#664a1c',
  'color-primary-900': '#3d270e',
  'color-primary-transparent-100': 'rgba(225, 179, 70, 0.08)',
  'color-primary-transparent-200': 'rgba(225, 179, 70, 0.16)',
  'color-primary-transparent-300': 'rgba(225, 179, 70, 0.24)',
  'color-primary-transparent-400': 'rgba(225, 179, 70, 0.32)',
  'color-primary-transparent-500': 'rgba(225, 179, 70, 0.40)',
  'color-primary-transparent-600': 'rgba(225, 179, 70, 0.48)',

  'color-basic-100': '#ffffff', // Card
  'color-basic-200': '#fdfdfd', // Background
  'color-basic-300': '#f5f5f5', // Secondary
  'color-basic-400': '#f0f0f0', // Muted
  'color-basic-500': '#e0e0e0', // Border
  'color-basic-600': '#666666', // Muted foreground
  'color-basic-700': '#333333', // Foreground
  'color-basic-800': '#1a1a1a',
  'color-basic-900': '#000000',
  'color-basic-transparent-100': 'rgba(51, 51, 51, 0.08)',
  'color-basic-transparent-200': 'rgba(51, 51, 51, 0.16)',
  'color-basic-transparent-300': 'rgba(51, 51, 51, 0.24)',
  'color-basic-transparent-400': 'rgba(51, 51, 51, 0.32)',
  'color-basic-transparent-500': 'rgba(51, 51, 51, 0.40)',
  'color-basic-transparent-600': 'rgba(51, 51, 51, 0.48)',

  'color-success-100': '#dff2e1',
  'color-success-500': '#1b7a3a',
  'color-success-600': '#1b7a3a',
  'color-success-700': '#1b7a3a',

  'color-warning-100': '#fff4e5',
  'color-warning-500': '#e1b346',
  'color-warning-600': '#664400',
  'color-warning-700': '#664400',

  'color-danger-100': '#ffe5e5',
  'color-danger-500': '#e63946',
  'color-danger-600': '#e63946',
  'color-danger-700': '#e63946',

  'color-info-100': '#e5f4ff',
  'color-info-500': '#0066cc',
  'color-info-600': '#0066cc',
  'color-info-700': '#0066cc',
};

// Dark theme colors from template_home_dark.html
const darkThemeColors = {
  'color-primary-100': '#3d270e',
  'color-primary-200': '#664a1c',
  'color-primary-300': '#8f6d2a',
  'color-primary-400': '#b89038',
  'color-primary-500': '#e1b346', // Main accent color
  'color-primary-600': '#fce79f',
  'color-primary-700': '#fdedb7',
  'color-primary-800': '#fef3cf',
  'color-primary-900': '#fef9e7',
  'color-primary-transparent-100': 'rgba(225, 179, 70, 0.08)',
  'color-primary-transparent-200': 'rgba(225, 179, 70, 0.16)',
  'color-primary-transparent-300': 'rgba(225, 179, 70, 0.24)',
  'color-primary-transparent-400': 'rgba(225, 179, 70, 0.32)',
  'color-primary-transparent-500': 'rgba(225, 179, 70, 0.40)',
  'color-primary-transparent-600': 'rgba(225, 179, 70, 0.48)',

  'color-basic-100': '#2a2a2a', // Muted
  'color-basic-200': '#333333', // Background
  'color-basic-300': '#363636', // Card
  'color-basic-400': '#3a3a3a', // Secondary
  'color-basic-500': '#444444', // Border
  'color-basic-600': '#c0c0c0', // Muted foreground
  'color-basic-700': '#fdfdfd', // Foreground
  'color-basic-800': '#ffffff',
  'color-basic-900': '#ffffff',
  'color-basic-transparent-100': 'rgba(253, 253, 253, 0.08)',
  'color-basic-transparent-200': 'rgba(253, 253, 253, 0.16)',
  'color-basic-transparent-300': 'rgba(253, 253, 253, 0.24)',
  'color-basic-transparent-400': 'rgba(253, 253, 253, 0.32)',
  'color-basic-transparent-500': 'rgba(253, 253, 253, 0.40)',
  'color-basic-transparent-600': 'rgba(253, 253, 253, 0.48)',

  'color-success-100': '#1b3a1f',
  'color-success-500': '#4caf50',
  'color-success-600': '#4caf50',
  'color-success-700': '#4caf50',

  'color-warning-100': '#332a00',
  'color-warning-500': '#ffb020',
  'color-warning-600': '#ffb020',
  'color-warning-700': '#ffb020',

  'color-danger-100': '#331a1c',
  'color-danger-500': '#e63946',
  'color-danger-600': '#e63946',
  'color-danger-700': '#e63946',

  'color-info-100': '#1a2a33',
  'color-info-500': '#4da6ff',
  'color-info-600': '#4da6ff',
  'color-info-700': '#4da6ff',
};

// Create custom light theme
export const lightTheme: ThemeType = {
  ...eva.light,
  ...lightThemeColors,
};

// Create custom dark theme
export const darkTheme: ThemeType = {
  ...eva.dark,
  ...darkThemeColors,
};
