import {readFile} from 'node:fs/promises';
const config = JSON.parse(await readFile(new URL('../config/supabase.dev.json', import.meta.url), 'utf8'));
const checks = ['/auth/v1/health', '/rest/v1/listings?select=id&limit=0', '/rest/v1/universities?select=id&limit=0'];
let failed = false;
for (const endpoint of checks) {
  try {
    const response = await fetch(config.SUPABASE_URL + endpoint, {
      headers: {apikey: config.SUPABASE_PUBLISHABLE_KEY}, signal: AbortSignal.timeout(10000),
    });
    console.log(`${endpoint}: HTTP ${response.status}`);
    if (!response.ok) failed = true;
  } catch (error) {
    console.log(`${endpoint}: ${error.name}`);
    failed = true;
  }
}
console.log(failed ? 'Backend is not ready. Keep the preview in demo mode.' : 'Read-only endpoint checks passed. Authentication, policies, and write flows still require verification.');
process.exitCode = failed ? 1 : 0;
