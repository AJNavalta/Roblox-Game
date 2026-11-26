const fs = require('fs');
const P = require('./parts.js');
const { chromium } = require('playwright');

const miniLemon = (x,y,s)=>`<use href="#lemon" x="-170" y="-170" width="340" height="340" transform="translate(${x} ${y}) scale(${s})"/>`;
const use = (id,x,y,s=1,rot=0,w=100,h=100)=>`<use href="#${id}" x="${-w/2}" y="${-h/2}" width="${w}" height="${h}" transform="translate(${x} ${y}) rotate(${rot}) scale(${s})"/>`;
const bill=(x,y,s,r)=>use('bill',x,y,s,r,190,100);
const coin=(x,y,s)=>use('coin',x,y,s,0,100,100);
const spark=(x,y,s)=>use('sparkle',x,y,s,0,100,100);

// ---------- ICON 512 ----------
const icon = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<defs>${P.defs}
<radialGradient id="bgI" cx="0.5" cy="0.48" r="0.75"><stop offset="0" stop-color="#3FC2FF"/><stop offset="0.6" stop-color="#1673E0"/><stop offset="1" stop-color="#0B2F8A"/></radialGradient>
</defs>
<rect width="512" height="512" fill="url(#bgI)"/>
<g transform="translate(256 250)">${P.rays(20, 520, '#FFFFFF', 0.12)}</g>
<!-- cash fan behind lemon -->
${bill(120,215,0.95,-38)}${bill(392,205,0.95,36)}${bill(160,170,0.9,-18)}${bill(352,165,0.9,20)}
${coin(70,330,0.55)}${coin(445,318,0.6)}${coin(100,400,0.42)}
${spark(430,120,0.45)}${spark(82,128,0.35)}${spark(458,400,0.3)}
<!-- lemon -->
<g filter="url(#shadow)">${miniLemon(256,272,0.86)}</g>
${use('crown',192,150,0.5,-22,160,120)}
<!-- title -->
${P.title('HUSTLE',256,108,96,'#FFE14D',{stroke:'#2A1200',sw:18,depth:8})}
<g transform="translate(256 446) rotate(-3)">
  <path d="M-236 -40 L236 -40 L222 46 L-222 46Z" fill="#E8261C" stroke="#2A1200" stroke-width="10" stroke-linejoin="round"/>
  <path d="M-226 -30 L226 -30" stroke="#FF7A6E" stroke-width="6" opacity="0.8"/>
  ${P.title('TYCOON',0,34,84,'#FFFFFF',{stroke:'#2A1200',sw:14,depth:6})}
</g>
</svg>`;

// ---------- THUMBNAIL 1920x1080 ----------
const thumb = `<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080">
<defs>${P.defs}
<linearGradient id="sky" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1D7BEA"/><stop offset="0.6" stop-color="#4CC3FF"/><stop offset="1" stop-color="#A8ECFF"/></linearGradient>
<linearGradient id="hill" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6EDB4A"/><stop offset="1" stop-color="#2E9B2A"/></linearGradient>
<linearGradient id="hill2" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4FC23C"/><stop offset="1" stop-color="#1F7A22"/></linearGradient>
<radialGradient id="sun" cx="0.5" cy="0.5" r="0.5"><stop offset="0" stop-color="#FFFBD0"/><stop offset="0.5" stop-color="#FFF27A" stop-opacity="0.6"/><stop offset="1" stop-color="#FFF27A" stop-opacity="0"/></radialGradient>
</defs>
<rect width="1920" height="1080" fill="url(#sky)"/>
<g transform="translate(1480 420)">${P.rays(28, 1700, '#FFFFFF', 0.13)}</g>
<circle cx="1480" cy="420" r="380" fill="url(#sun)"/>
<!-- clouds -->
<g fill="#FFFFFF" opacity="0.9">
  <g transform="translate(1000 140)"><circle r="45"/><circle cx="55" cy="-15" r="55"/><circle cx="115" r="42"/><rect x="0" y="0" width="115" height="42"/></g>
  <g transform="translate(1760 170) scale(0.8)"><circle r="45"/><circle cx="55" cy="-15" r="55"/><circle cx="115" r="42"/><rect x="0" y="0" width="115" height="42"/></g>
</g>
<!-- stock arrow -->
<g stroke-linejoin="round" stroke-linecap="round">
  <path d="M560 1000 L760 760 L880 840 L1100 470 L1180 540 L1300 260" fill="none" stroke="#0C4A1A" stroke-width="86"/>
  <path d="M560 1000 L760 760 L880 840 L1100 470 L1180 540 L1300 260" fill="none" stroke="url(#arrowG)" stroke-width="56"/>
  <path d="M1220 250 L1340 160 L1370 310Z" fill="#8CFF6A" stroke="#0C4A1A" stroke-width="14"/>
</g>
<!-- back hill + mansion -->
<path d="M980 1080 Q1060 640 1520 610 Q1820 600 1920 640 L1920 1080Z" fill="url(#hill)" stroke="#1F6A1C" stroke-width="10"/>
<g filter="url(#shadow)">${use('mansion',1530,628,0.92,0,720,430)}</g>
<!-- palm-ish bushes -->
<g fill="#2FA83A" stroke="#155E1A" stroke-width="7"><circle cx="1130" cy="640" r="40"/><circle cx="1170" cy="625" r="48"/><circle cx="1880" cy="615" r="45"/></g>
<!-- front ground -->
<path d="M0 1080 L0 990 Q500 930 1000 960 Q1500 990 1920 930 L1920 1080Z" fill="url(#hill2)" stroke="#155E1A" stroke-width="10"/>
<!-- car -->
<g filter="url(#shadow)">${use('car',1095,1000,0.95,0,560,180)}</g>
<!-- lemon seller + stand -->
<g filter="url(#shadow)">${miniLemon(1400,870,0.58)}</g>
${use('crown',1352,758,0.4,-20,160,120)}
<g filter="url(#shadow)">${use('stand',1650,1064-195*0.86,0.86,0,460,410)}</g>
<!-- flying cash -->
${bill(1010,380,0.95,-22)}${bill(1820,330,0.8,28)}${bill(920,620,0.75,14)}${bill(1300,120,0.7,-10)}${bill(80,1000,0.8,-18)}
${coin(1390,590,0.6)}${coin(1240,800,0.55)}${coin(1860,780,0.5)}${coin(860,250,0.5)}${coin(240,960,0.55)}
${spark(1720,90,0.5)}${spark(800,120,0.4)}${spark(1290,660,0.35)}${spark(980,850,0.35)}
<!-- title -->
<g transform="rotate(-4 480 400)">
  ${P.title('HUSTLE',490,350,250,'#FFE14D',{stroke:'#2A1200',sw:40,depth:20})}
  ${P.title('TYCOON',490,590,250,'#FFFFFF',{stroke:'#2A1200',sw:40,depth:20})}
  <g transform="translate(490 712)">
    <path d="M-440 -58 L440 -58 L420 62 L-420 62Z" fill="#E8261C" stroke="#2A1200" stroke-width="14" stroke-linejoin="round"/>
    <path d="M-476 -30 L-440 -58 L-420 62 L-470 70 L-450 18Z" fill="#B01510" stroke="#2A1200" stroke-width="12" stroke-linejoin="round"/>
    <path d="M476 -30 L440 -58 L420 62 L470 70 L450 18Z" fill="#B01510" stroke="#2A1200" stroke-width="12" stroke-linejoin="round"/>
    ${P.title('LEMONADE TO BILLIONAIRE',0,26,72,'#FFFFFF',{stroke:'#2A1200',sw:12,depth:5})}
  </g>
</g>
</svg>`;

(async()=>{
  const b = await chromium.launch();
  const out = process.argv[2] || '.';
  for (const [name, svg, w, h] of [['icon', icon, 512, 512], ['thumbnail', thumb, 1920, 1080]]) {
    fs.writeFileSync(`${out}/${name}.svg`, svg);
    const p = await b.newPage({viewport:{width:w,height:h}, deviceScaleFactor:1});
    await p.setContent(`<html><head><style>${P.fontCSS}</style></head><body>${svg}</body></html>`);
    await p.evaluate(()=>document.fonts.ready);
    await p.waitForTimeout(300);
    await p.screenshot({path:`${out}/${name}.png`, clip:{x:0,y:0,width:w,height:h}});
  }
  // small previews
  const p = await b.newPage({viewport:{width:900,height:300}});
  const i64 = fs.readFileSync(`${out}/icon.png`).toString('base64'), t64 = fs.readFileSync(`${out}/thumbnail.png`).toString('base64');
  await p.setContent(`<body style="margin:10px;background:#222;display:flex;gap:16px;align-items:start"><img src="data:image/png;base64,${i64}" width=150 style="border-radius:18px"><img src="data:image/png;base64,${i64}" width=60 style="border-radius:8px"><img src="data:image/png;base64,${t64}" width=384></body>`);
  await p.screenshot({path:`${out}/preview_small.png`});
  await b.close();
})();
