const fs = require('node:fs');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const html = fs.readFileSync(process.argv[2], 'utf8');
const code = html.match(/<script>([\s\S]*)<\/script>/)[1];
const messages = [], markers = [];
let bounds, center;
class Map {
  constructor() { this.geoObjects = { removeAll() { markers.length = 0; }, add(m) { markers.push(m); } }; this.container = { fitToViewport() {} }; }
  setCenter(...args) { center = args; }
  setBounds(...args) { bounds = args; return Promise.resolve(); }
  destroy() {}
}
class Placemark {
  constructor(coords, properties) { this.coords = coords; this.properties = properties; this.events = { add: (_, callback) => this.click = callback }; }
}
const window = { JosparMap: { postMessage: s => messages.push(JSON.parse(s)) }, josparYmaps: { Map, Placemark, ready: f => f() }, addEventListener() {} };
const context = { window, document: { createElement() { return {}; }, head: { appendChild: s => s.onload() }, getElementById() { return {}; } }, ResizeObserver: class { observe() {} } };
vm.runInNewContext(code, context);
assert.equal(messages.at(-1).type, 'ready');
assert.equal(markers.length, 2);
assert(bounds);
assert.equal(bounds[1].checkZoomRange, true);
assert(!markers[0].properties.hintContent.includes('<img'));
markers[0].click();
assert.deepEqual(messages.at(-1), { type: 'select', id: 'one' });
window.josparUpdateTasks([{ id:'two', title:'Одна точка', lat:43, lng:76 }]);
assert.equal(markers.length, 1);
assert.equal(center[1], 14);
console.log('Yandex map JavaScript: ready, bounds, escaped labels, task selection, marker refresh passed.');
