const colorTokens = [
  'background',
  'foreground',
  'border',
  'input',
  'primary',
  'primary-foreground',
  'secondary',
  'secondary-foreground',
  'muted',
  'muted-foreground',
  'success',
  'success-foreground',
  'accent',
  'accent-foreground',
  'destructive',
  'destructive-foreground',
  'warning',
  'warning-foreground',
  'card',
  'card-foreground',
  'sidebar',
  'sidebar-foreground',
  'sidebar-primary',
  'sidebar-primary-foreground',
];

const variableMap = (names, prefix = '') =>
  Object.fromEntries(names.map((name) => [name, `var(--${prefix}${name})`]));

module.exports = {
  theme: {
    extend: {
      colors: variableMap(colorTokens),
      borderRadius: variableMap(['sm', 'md', 'lg', 'xl', 'full'], 'radius-'),
      spacing: variableMap(['xs', 'sm', 'md', 'lg', 'xl', 'screen-x', 'bottom-nav'], 'spacing-'),
      fontFamily: {
        sans: ['var(--font-family-body)'],
      },
      fontSize: variableMap(['meta', 'caption', 'body', 'title', 'display'], 'font-size-'),
      fontWeight: variableMap(['regular', 'medium', 'semibold', 'bold'], 'font-weight-'),
    },
  },
};
