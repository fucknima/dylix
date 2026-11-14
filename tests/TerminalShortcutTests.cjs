// Exercise the shipped WebView script without a browser or PTY side effects.
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync('Resources/Terminal/index.html','utf8').match(/<script>\s*('use strict';[\s\S]*?)<\/script>/)[1];
const events=[];let term;
class Terminal {
 constructor(){term=this;this.modes={applicationCursorKeysMode:false};this.cols=80;this.rows=24;}
 loadAddon(){} open(){} onData(fn){this.data=fn;} onResize(){} clearSelection(){} focus(){} clear(){}
 paste(text){this.data(text);} write(){}
}
const context={Terminal,FitAddon:{FitAddon:class{fit(){}}},document:{getElementById:()=>({})},ResizeObserver:class{observe(){}},requestAnimationFrame:()=>{},window:{webkit:{messageHandlers:{dylixTerminal:{postMessage:event=>events.push(event)}}}}};
vm.createContext(context);vm.runInContext(source,context);
const key=context.window.dylixKey;
function expect(run,text){events.length=0;run();assert.equal(events.filter(e=>e.type==='input').map(e=>e.value).join(''),text);}
expect(()=>key('enter'),'\r');expect(()=>key('backspace'),'\x7f');
for(const [name,code] of Object.entries({up:'A',down:'B',right:'C',left:'D',home:'H',end:'F'})){
 term.modes.applicationCursorKeysMode=false;expect(()=>key(name),'\x1b['+code);
 term.modes.applicationCursorKeysMode=true;expect(()=>key(name),'\x1bO'+code);
 expect(()=>{key('ctrl');key(name);},'\x1b[1;5'+code);
}
expect(()=>{key('ctrl');term.data('c');term.data('c');},'\x03c');
expect(()=>{key('ctrl');term.data(' ');},'\x00');
expect(()=>{key('alt');term.data('中');},'\x1b中');
expect(()=>{key('ctrl');key('alt');term.data('c');},'\x1b\x03');
expect(()=>{key('ctrl');key('alt');key('delete');},'\x1b[3;7~');
expect(()=>{key('ctrl');context.window.dylixPaste('echo 中文\n');term.data('c');},'echo 中文\nc');
expect(()=>{key('ctrl');key('ctrl');term.data('x');},'x');
console.log('PASS: production shortcut mapping, application cursor mode, one-shot Ctrl/Alt, Unicode and paste');
