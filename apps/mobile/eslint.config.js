// https://docs.expo.dev/guides/using-eslint/
const { defineConfig } = require('eslint/config');
const expoConfig = require('@matome/config/eslint/expo');

module.exports = defineConfig([
  ...expoConfig,
]);
