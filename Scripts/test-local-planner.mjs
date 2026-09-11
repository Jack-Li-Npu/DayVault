// Opt-in live smoke test. Sends only this synthetic goal to the local proxy.
// No Keychain access, personal records, or automatic writes to the app.
import { writeFile } from 'node:fs/promises';
const endpoint = 'http://127.0.0.1:8000';
const health = await fetch(`${endpoint}/health`).then((response) => response.json());
if (health.skillVersion !== '1.1.1') {
  throw new Error('Unexpected local proxy model/skill version; restart the current proxy.');
}
const request = {
  goalText: '6天完成英语演讲准备',
  currentDate: new Date().toISOString(),
  timeZoneID: 'Asia/Shanghai', locale: 'zh-Hans',
  busyWindows: [], existingDailyLoads: [], activeChallengeIDs: [],
};
const started = Date.now();
const response = await fetch(endpoint, {
  method: 'POST', signal: AbortSignal.timeout(150_000),
  headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(request),
});
const result = await response.json();
console.log(JSON.stringify({
  http: response.status, seconds: (Date.now() - started) / 1000,
  modelMetadataPresent: Boolean(response.headers.get('X-DayVault-Model')),
  skillVersion: response.headers.get('X-DayVault-Skill-Version'),
  kind: result.kind, question: result.question, error: result.error,
  upstreamStatus: result.upstreamStatus,
  title: result.plan?.title,
  phases: result.plan?.phases?.map((phase) => phase.title),
  firstSteps: result.plan?.initialBlocks?.slice(0, 3).map((block) => ({ title: block.title, notes: block.notes })),
}, null, 2));
if (!response.ok) process.exitCode = 1;
else {
  await writeFile('/private/tmp/dayvault-live-planner-fixture.json', JSON.stringify({ request, result }, null, 2));
  console.log('Synthetic response saved to /private/tmp/dayvault-live-planner-fixture.json');
}
