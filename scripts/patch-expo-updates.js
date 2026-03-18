const fs = require('fs');
const path = require('path');

const filePath = path.join(
  __dirname,
  '..',
  'node_modules',
  'expo-updates',
  'expo-updates-gradle-plugin',
  'build.gradle.kts'
);

if (!fs.existsSync(filePath)) {
  console.log('expo-updates gradle plugin not found, skipping patch.');
  process.exit(0);
}

let content = fs.readFileSync(filePath, 'utf8');
const patched = content.replace(
  /kotlin\("jvm"\) version\("1\.9\.\d+"\)/,
  'kotlin("jvm") version("2.1.0")'
);

if (patched === content) {
  console.log('expo-updates gradle plugin already patched or pattern not found.');
} else {
  fs.writeFileSync(filePath, patched);
  console.log('Patched expo-updates gradle plugin: Kotlin 1.9.x -> 2.1.0');
}
