// Jest harness shim for the Expo SDK 55 "winter" runtime.
//
// The jest-expo preset's setup (node_modules/jest-expo/src/preset/setup.js)
// loads `expo/src/winter` -> `expo/src/winter/runtime.native.ts`, which installs
// LAZY getters on the global object for a handful of WinterCG polyfills:
//   TextDecoder, TextDecoderStream, TextEncoderStream, URL, URLSearchParams,
//   __ExpoImportMetaRegistry, structuredClone
// (see runtime.native.ts + installGlobal.ts).
//
// Each getter, the first time it is read, fires a relative/bare `require(...)`.
// Under Jest 30 those DEFERRED requires (executed from inside a global getter
// rather than from a module's own evaluation frame) are rejected with:
//   "You are trying to `import` a file outside of the scope of the test code."
// That ReferenceError crashes every suite at import time, before any assertion
// runs, so the whole jest run reports 0 tests / 7 suites failed.
//
// jest-expo's preset setupFiles run BEFORE this config setupFiles entry, so by
// the time we get here the lazy getters are already installed. We eagerly
// re-define the globals as plain eager values, resolved from THIS setup file's
// own (test-scope-valid) require frame. The lazy getters are thereby replaced
// before they are ever read, so their deferred requires never fire.
//
// IMPORTANT: never READ globalThis.<name> for these props before overwriting --
// reading triggers the very lazy getter we are trying to defuse. We reference
// the Node-provided bindings (URL, structuredClone, TextDecoder, ...) by their
// lexical names, which resolve to the test environment's natives without
// touching the booby-trapped global accessors.

'use strict';

function defineEager(name, value) {
  Object.defineProperty(globalThis, name, {
    value,
    configurable: true,
    writable: true,
    enumerable: false,
  });
}

// `import.meta` is rewritten by babel-preset-expo to read this registry.
defineEager('__ExpoImportMetaRegistry', {
  get url() {
    return 'file:///jest-expo-bundle';
  },
});

// structuredClone: Node 17+ provides a built-in; reference it lexically.
const nodeStructuredClone =
  typeof structuredClone === 'function'
    ? structuredClone
    : // eslint-disable-next-line @typescript-eslint/no-var-requires
      require('@ungap/structured-clone').default;
defineEager('structuredClone', nodeStructuredClone);

// WHATWG URL / URLSearchParams: Node provides these natively (lexical refs).
defineEager('URL', URL);
defineEager('URLSearchParams', URLSearchParams);

// Text encoding/decoding: Node provides these natively (lexical refs).
defineEager('TextDecoder', TextDecoder);
defineEager('TextEncoder', TextEncoder);
