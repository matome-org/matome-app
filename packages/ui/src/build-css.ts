import { mkdir, writeFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { cssVariables } from './css';

const packageRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const outputPath = resolve(packageRoot, 'dist/tokens.css');

await mkdir(dirname(outputPath), { recursive: true });
await writeFile(outputPath, `${cssVariables}\n`);
