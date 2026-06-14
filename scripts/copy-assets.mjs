import fs from 'node:fs/promises';

await fs.rm('dist/src/views', { recursive: true, force: true });
await fs.rm('dist/src/public', { recursive: true, force: true });
await fs.cp('src/views', 'dist/src/views', { recursive: true });
await fs.cp('src/public', 'dist/src/public', { recursive: true });
console.log('Copied view and public assets into dist/src');
