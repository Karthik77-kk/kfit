import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');

const srcManifestPath = path.join(rootDir, 'src', 'data', 'releases.json');
const publicManifestPath = path.join(rootDir, 'public', 'releases.json');
const redirectsPath = path.join(rootDir, 'public', '_redirects');

console.log('🔍 Validating release manifest at:', srcManifestPath);

if (!fs.existsSync(srcManifestPath)) {
  console.error('❌ Missing release manifest:', srcManifestPath);
  process.exit(1);
}

let manifest;
try {
  const content = fs.readFileSync(srcManifestPath, 'utf8');
  manifest = JSON.parse(content);
} catch (err) {
  console.error('❌ Failed to parse JSON manifest:', err.message);
  process.exit(1);
}

const requiredProducts = ['kfit', 'jarvis'];
const errors = [];

for (const productKey of requiredProducts) {
  const product = manifest[productKey];
  if (!product) {
    errors.push(`Missing product definition for "${productKey}"`);
    continue;
  }

  // 1. Version tag
  if (!product.version || typeof product.version !== 'string') {
    errors.push(`[${productKey}] Invalid or missing version`);
  }

  // 2. SHA-256 validation (must be 64-char lowercase hex)
  if (!product.sha256 || !/^[0-9a-f]{64}$/.test(product.sha256)) {
    errors.push(`[${productKey}] Invalid SHA-256 checksum: "${product.sha256}". Must be 64 hex characters.`);
  }

  // 3. APK URL verification
  if (!product.apkUrl || !product.apkUrl.endsWith('.apk')) {
    errors.push(`[${productKey}] apkUrl must end with .apk: "${product.apkUrl}"`);
  }
  if (!product.apkUrl.includes(product.version)) {
    errors.push(`[${productKey}] apkUrl does not contain tag "${product.version}": "${product.apkUrl}"`);
  }

  // 4. File size check
  if (!product.sizeBytes || typeof product.sizeBytes !== 'number' || product.sizeBytes <= 0) {
    errors.push(`[${productKey}] Invalid sizeBytes: ${product.sizeBytes}`);
  }

  // 5. Published date
  if (!product.publishedAt || !/^\d{4}-\d{2}-\d{2}$/.test(product.publishedAt)) {
    errors.push(`[${productKey}] publishedAt must be in YYYY-MM-DD format: "${product.publishedAt}"`);
  }
}

if (errors.length > 0) {
  console.error('❌ Release manifest validation failed with errors:');
  for (const err of errors) {
    console.error(`  - ${err}`);
  }
  process.exit(1);
}

// Automatically sync public/releases.json from src/data/releases.json
fs.writeFileSync(publicManifestPath, JSON.stringify(manifest, null, 2) + '\n', 'utf8');
console.log('✅ Synchronized public/releases.json with single source of truth.');

// Generate Cloudflare Pages _redirects file
const redirectsContent = `# Cloudflare Pages Redirects
# Generated automatically by scripts/validate-releases.mjs — do not edit manually

/welcome / 301
/downloads/kfit ${manifest.kfit.apkUrl} 302
/downloads/jarvis ${manifest.jarvis.apkUrl} 302
`;

fs.writeFileSync(redirectsPath, redirectsContent, 'utf8');
console.log('✅ Generated public/_redirects with direct 302 download endpoints.');
console.log('🎉 Release manifest validation succeeded.');
