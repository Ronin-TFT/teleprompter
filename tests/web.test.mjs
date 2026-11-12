// 网页界面的自动测试：在无头 Chromium 中分别打开编辑模式和提词模式。
// 运行：node tests/web.test.mjs
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import path from 'node:path';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const page = pathToFileURL(path.join(root, 'web', 'app.html')).href;

const SCRIPT = '# 开场\n大家好，欢迎来到我的频道。今天介绍一个小工具！\n[停顿]\n' +
  Array.from({ length: 30 }, (_, i) => `这是第${i + 1}句话，用来测试滚动和高亮是否正常。`).join('') + '\nThe end. Thanks for watching!';

const results = [];
async function test(name, fn) {
  try { await fn(); results.push(['✅', name]); }
  catch (e) { results.push(['❌', name, e]); }
}

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 900, height: 500 } });

async function openPrompter(settings = {}) {
  const p = await ctx.newPage();
  await p.goto(page + '#prompter');
  await p.evaluate(([script, settings]) => window.tp.receive({ type: 'update', script, settings, hash: 'h1', position: 0 }),
    [SCRIPT, { countdown: 0, speed: 600, fontSize: 32, ...settings }]);
  return p;
}
const outbox = p => p.evaluate(() => (window.__tpOutbox || []).splice(0));
const st = p => p.evaluate(() => {
  const s = window.__tpPrompter;
  return { offset: s.offset, max: s.max, playing: s.playing, current: s.current, pxPerSec: s.pxPerSec,
           countdownLeft: s.countdownLeft, speed: s.settings.speed, fontSize: s.settings.fontSize, spans: s.spans.length };
});

await test('提词：渲染段落、标题、停顿与句子', async () => {
  const p = await openPrompter();
  const info = await p.evaluate(() => ({
    headings: document.querySelectorAll('p.heading').length,
    pauses: document.querySelectorAll('p.pause').length,
    sentences: document.querySelectorAll('.s').length,
    empty: document.getElementById('empty').hidden,
  }));
  assert.equal(info.headings, 1);
  assert.equal(info.pauses, 1);
  assert.equal(info.sentences, 2 + 30 + 2);
  assert.equal(info.empty, true);
  const out = await outbox(p);
  assert.ok(out.some(m => m.type === 'ready'));
  await p.close();
});

await test('提词：开始后滚动，暂停后停止，并报告播放状态与位置', async () => {
  const p = await openPrompter();
  await outbox(p);
  let s = await st(p);
  assert.equal(s.offset, 0);
  assert.ok(s.pxPerSec > 0, 'pxPerSec');
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'toggle' }));
  await p.waitForTimeout(600);
  s = await st(p);
  assert.ok(s.playing && s.offset > 10, `offset ${s.offset}`);
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'toggle' }));
  const paused = (await st(p)).offset;
  await p.waitForTimeout(400);
  s = await st(p);
  assert.ok(!s.playing && s.offset === paused, 'stays paused');
  const out = await outbox(p);
  assert.ok(out.some(m => m.type === 'playback' && m.playing === true));
  assert.ok(out.some(m => m.type === 'playback' && m.playing === false));
  const pos = out.filter(m => m.type === 'position').pop();
  assert.ok(pos && pos.hash === 'h1' && pos.ratio > 0 && pos.ratio < 1, JSON.stringify(pos));
  await p.close();
});

await test('提词：语速决定滚动速度（字/分钟）', async () => {
  const p = await openPrompter({ speed: 300 });
  const a = (await st(p)).pxPerSec;
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'faster' }));
  const s = await st(p);
  assert.equal(s.speed, 310);
  assert.ok(Math.abs(s.pxPerSec / a - 310 / 300) < 0.01, `${s.pxPerSec} vs ${a}`);
  const out = await outbox(p);
  assert.ok(out.some(m => m.type === 'settings' && m.patch.speed === 310));
  await p.close();
});

await test('提词：高亮阅读线所在的句子，前面的句子标为已读', async () => {
  const p = await openPrompter();
  assert.equal((await st(p)).current, 0);
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'forward' }));
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'forward' }));
  const s = await st(p);
  assert.ok(s.current > 1, `current ${s.current}`);
  const cls = await p.evaluate(() => [...document.querySelectorAll('.s')].map(e => e.className));
  assert.ok(cls[s.current].includes('current'));
  assert.ok(cls[0].includes('read'));
  assert.ok(!cls[s.current + 1].includes('read'));
  await p.close();
});

await test('提词：倒计时结束后才开始滚动，倒计时中可取消', async () => {
  const p = await openPrompter({ countdown: 1 });
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'play' }));
  let s = await st(p);
  assert.ok(!s.playing && s.countdownLeft === 1);
  assert.equal(await p.evaluate(() => document.getElementById('countdown').hidden), false);
  await p.waitForTimeout(1400);
  s = await st(p);
  assert.ok(s.playing && s.offset > 0, 'playing after countdown');
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'restart' }));
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'toggle' }));
  s = await st(p);
  assert.ok(!s.playing && s.countdownLeft === 0 && s.offset === 0, JSON.stringify(s));
  assert.equal(await p.evaluate(() => document.getElementById('countdown').hidden), true);
  await p.close();
});

await test('提词：读到结尾自动停止并报告已读完', async () => {
  const p = await openPrompter();
  await p.evaluate(() => { const s = window.__tpPrompter; s.offset = s.max - 5; });
  await outbox(p);
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'play' }));
  await p.waitForTimeout(500);
  const s = await st(p);
  assert.ok(!s.playing && s.offset === s.max);
  const out = await outbox(p);
  assert.ok(out.some(m => m.type === 'playback' && m.finished));
  await p.close();
});

await test('提词：恢复上次位置、镜像、键盘与滚轮', async () => {
  const p = await ctx.newPage();
  await p.goto(page + '#prompter');
  await p.evaluate(s => window.tp.receive({ type: 'update', script: s, settings: { countdown: 0, mirrorX: true, mirrorY: true }, hash: 'h2', position: 0.5 }), SCRIPT);
  let s = await st(p);
  assert.ok(Math.abs(s.offset / s.max - 0.5) < 0.01, 'restored');
  assert.equal(await p.evaluate(() => document.getElementById('stage').className), 'mirror-x mirror-y');
  const before = s.offset;
  await p.mouse.move(400, 200);
  await p.mouse.wheel(0, 100);
  await p.waitForTimeout(100);
  s = await st(p);
  assert.ok(s.offset < before, 'wheel reversed when flipped vertically');
  await p.keyboard.press('ArrowLeft');
  assert.ok((await st(p)).offset < s.offset);
  await p.keyboard.press('Equal');
  assert.equal((await st(p)).fontSize, 52);
  await p.keyboard.press('Space');
  assert.ok((await st(p)).playing);
  await p.keyboard.press('Escape');
  assert.ok(!(await st(p)).playing);
  await p.close();
});

await test('提词：修改设置不丢失位置，修改稿子时重新开始', async () => {
  const p = await openPrompter();
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'forward' }));
  const s1 = await st(p);
  await p.evaluate(s => window.tp.receive({ type: 'update', script: s, settings: { countdown: 0, speed: 600, fontSize: 32, align: 'center' }, hash: 'h1', position: 0 }), SCRIPT);
  const s2 = await st(p);
  assert.equal(s2.offset, s1.offset);
  await p.evaluate(() => window.tp.receive({ type: 'update', script: '新的稿子。第二句。', settings: {}, hash: 'h3', position: 0 }));
  const s3 = await st(p);
  assert.equal(s3.offset, 0);
  assert.equal(s3.spans, 2);
  await p.close();
});

await test('提词：空稿子显示提示且不能开始', async () => {
  const p = await ctx.newPage();
  await p.goto(page + '#prompter');
  assert.equal(await p.evaluate(() => document.getElementById('empty').hidden), false);
  await p.evaluate(() => window.tp.receive({ type: 'command', command: 'play' }));
  assert.equal((await st(p)).playing, false);
  await p.close();
});

await test('编辑：加载初始状态、修改后发送 update 与 store', async () => {
  const p = await ctx.newPage();
  await p.addInitScript(() => { window.tpInitialState = { script: '你好世界。', settings: { speed: 300 }, positions: {} }; });
  await p.goto(page + '#editor');
  assert.equal(await p.inputValue('#script'), '你好世界。');
  assert.equal(await p.inputValue('#speed'), '300');
  let out = await outbox(p);
  assert.ok(out.some(m => m.type === 'update' && m.script === '你好世界。' && m.settings.speed === 300));
  await p.fill('#script', '新的口播稿。第二句！');
  await p.waitForTimeout(300);
  out = await outbox(p);
  const update = out.filter(m => m.type === 'update').pop();
  assert.equal(update.script, '新的口播稿。第二句！');
  assert.ok(out.some(m => m.type === 'store' && m.state.script === '新的口播稿。第二句！'));
  await p.check('#mirrorX');
  await p.waitForTimeout(300);
  out = await outbox(p);
  assert.ok(out.filter(m => m.type === 'update').pop().settings.mirrorX === true);
  await p.close();
});

await test('编辑：按钮、导入、位置与提词窗口回传的设置', async () => {
  const p = await ctx.newPage();
  await p.goto(page + '#editor');
  await outbox(p);
  await p.click('#playBtn');
  await p.click('#showBtn');
  await p.click('#restartBtn');
  await p.click('#importBtn');
  let out = await outbox(p);
  assert.deepEqual(out.map(m => m.command || m.type), ['toggle', 'show', 'restart', 'import']);
  await p.evaluate(() => window.tp.receive({ type: 'imported', text: '导入的稿子。', name: 'a.txt' }));
  assert.equal(await p.inputValue('#script'), '导入的稿子。');
  assert.match(await p.textContent('#status'), /a\.txt/);
  const hash = await p.evaluate(() => hashText('导入的稿子。'));
  await p.evaluate(h => window.tp.receive({ type: 'position', hash: h, ratio: 0.42 }), hash);
  assert.match(await p.textContent('#progressText'), /42%/);
  await p.evaluate(() => window.tp.receive({ type: 'playback', playing: true }));
  assert.equal(await p.textContent('#playBtn'), '暂停');
  await p.evaluate(() => window.tp.receive({ type: 'settings', patch: { fontSize: 60 } }));
  assert.equal(await p.inputValue('#fontSize'), '60');
  out = await outbox(p);
  assert.ok(out.some(m => m.type === 'update' && m.settings.fontSize === 60));
  await p.close();
});

await test('工具函数：字数统计与句子拆分', async () => {
  const p = await ctx.newPage();
  await p.goto(page + '#editor');
  const r = await p.evaluate(() => ({
    cjk: countChars('你好，世界'),
    en: countChars('hello world'),
    parsed: parseScript('# 标题\n第一句。第二句！Third one. 最后\n[pause]'),
  }));
  assert.equal(r.cjk, 4);
  assert.equal(r.en, 2);
  assert.deepEqual(r.parsed.map(b => b.kind), ['heading', 'para', 'pause']);
  assert.deepEqual(r.parsed[1].sentences, ['第一句。', '第二句！', 'Third one.', '最后']);
  await p.close();
});

await browser.close();
for (const [mark, name, err] of results) {
  console.log(mark, name);
  if (err) console.log('   ', err.message.split('\n').slice(0, 4).join('\n    '));
}
const failed = results.filter(r => r[0] === '❌').length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
