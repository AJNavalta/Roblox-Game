const fs = require('fs');
const dir = __dirname;
const f64 = n => fs.readFileSync(dir + '/' + n).toString('base64');
exports.fontCSS = `
@font-face{font-family:LG;src:url(data:font/woff2;base64,${f64('LuckiestGuy.woff2')}) format('woff2');}
@font-face{font-family:LO;src:url(data:font/woff2;base64,${f64('LilitaOne.woff2')}) format('woff2');}
html,body{margin:0;padding:0;background:transparent}
svg{display:block}
`;
// sunburst rays centered at 0,0
exports.rays = (n, r, color, opacity=1) => {
  let s = '';
  for (let i = 0; i < n; i++) {
    const a1 = (i * 2 * Math.PI) / n, a2 = a1 + Math.PI / n;
    s += `<path d="M0 0 L${(r*Math.cos(a1)).toFixed(1)} ${(r*Math.sin(a1)).toFixed(1)} L${(r*Math.cos(a2)).toFixed(1)} ${(r*Math.sin(a2)).toFixed(1)} Z"/>`;
  }
  return `<g fill="${color}" opacity="${opacity}">${s}</g>`;
};
exports.defs = `
<linearGradient id="lemonG" x1="0" y1="0" x2="0.3" y2="1"><stop offset="0" stop-color="#FFF27A"/><stop offset="0.55" stop-color="#FFD524"/><stop offset="1" stop-color="#F2A900"/></linearGradient>
<linearGradient id="goldG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFF3A0"/><stop offset="0.5" stop-color="#FFC81E"/><stop offset="1" stop-color="#D98A00"/></linearGradient>
<linearGradient id="cashG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7EE07A"/><stop offset="1" stop-color="#2E9B3C"/></linearGradient>
<linearGradient id="carG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FF5A4E"/><stop offset="0.6" stop-color="#E0201B"/><stop offset="1" stop-color="#9E0E0E"/></linearGradient>
<linearGradient id="glassG" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3A3F5C"/><stop offset="1" stop-color="#0E1020"/></linearGradient>
<linearGradient id="winG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#BFF1FF"/><stop offset="1" stop-color="#4BB8E8"/></linearGradient>
<linearGradient id="woodG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#D98A4A"/><stop offset="1" stop-color="#9C5424"/></linearGradient>
<linearGradient id="arrowG" x1="0" y1="1" x2="0" y2="0"><stop offset="0" stop-color="#1FBF4A"/><stop offset="1" stop-color="#8CFF6A"/></linearGradient>

<symbol id="bill" viewBox="-95 -50 190 100" overflow="visible">
  <rect x="-90" y="-45" width="180" height="90" rx="8" fill="url(#cashG)" stroke="#145A22" stroke-width="6"/>
  <rect x="-76" y="-32" width="152" height="64" rx="5" fill="none" stroke="#D8FFC8" stroke-width="3" opacity="0.8"/>
  <circle r="24" fill="#BDF5A8" stroke="#145A22" stroke-width="4"/>
  <text y="15" text-anchor="middle" font-family="LG" font-size="40" fill="#145A22">$</text>
  <circle cx="-58" cy="0" r="7" fill="#BDF5A8"/><circle cx="58" cy="0" r="7" fill="#BDF5A8"/>
</symbol>

<symbol id="coin" viewBox="-50 -50 100 100" overflow="visible">
  <circle r="44" fill="#B86E00"/>
  <circle r="40" cy="-4" fill="url(#goldG)" stroke="#8A5200" stroke-width="5"/>
  <circle r="28" cy="-4" fill="none" stroke="#FFF3A0" stroke-width="4" opacity="0.8"/>
  <text y="14" text-anchor="middle" font-family="LG" font-size="44" fill="#9A5A00">$</text>
</symbol>

<symbol id="sparkle" viewBox="-50 -50 100 100" overflow="visible">
  <path d="M0 -46 Q6 -6 46 0 Q6 6 0 46 Q-6 6 -46 0 Q-6 -6 0 -46Z" fill="#FFFFFF"/>
</symbol>

<!-- Lemon mascot, ~300 wide, centered -->
<symbol id="lemon" viewBox="-170 -170 340 340" overflow="visible">
  <g transform="rotate(-12)">
    <path d="M-150 0 Q-150 -8 -138 -14 Q-128 -112 0 -116 Q128 -112 138 -14 Q150 -8 150 0 Q150 8 138 14 Q128 112 0 116 Q-128 112 -138 14 Q-150 8 -150 0Z"
      fill="url(#lemonG)" stroke="#6B3F00" stroke-width="10" stroke-linejoin="round"/>
    <ellipse cx="-50" cy="-70" rx="55" ry="20" fill="#FFFBD0" opacity="0.75" transform="rotate(-14 -50 -70)"/>
    <g fill="#E8A800" opacity="0.55"><circle cx="70" cy="60" r="5"/><circle cx="95" cy="35" r="4"/><circle cx="50" cy="85" r="4"/><circle cx="-90" cy="55" r="4"/></g>
  </g>
  <!-- leaf -->
  <path d="M8 -112 Q40 -170 105 -150 Q70 -100 8 -112Z" fill="#3CC94A" stroke="#1B5E20" stroke-width="8" stroke-linejoin="round"/>
  <path d="M18 -116 Q55 -140 92 -146" stroke="#1B5E20" stroke-width="5" fill="none" stroke-linecap="round"/>
  <!-- sunglasses -->
  <g transform="rotate(-8) translate(0 -18)">
    <path d="M-112 -22 L112 -22" stroke="#111" stroke-width="12" stroke-linecap="round"/>
    <path d="M-104 -24 L-14 -24 Q-10 30 -56 32 Q-100 30 -104 -24Z" fill="url(#glassG)" stroke="#111" stroke-width="8" stroke-linejoin="round"/>
    <path d="M14 -24 L104 -24 Q100 30 56 32 Q10 30 14 -24Z" fill="url(#glassG)" stroke="#111" stroke-width="8" stroke-linejoin="round"/>
    <path d="M-88 -14 L-62 -14 L-84 14Z" fill="#fff" opacity="0.55"/>
    <path d="M30 -14 L56 -14 L34 14Z" fill="#fff" opacity="0.55"/>
  </g>
  <!-- grin -->
  <g transform="rotate(-8) translate(0 48)">
    <path d="M-58 -6 Q0 6 58 -6 Q48 52 0 54 Q-48 52 -58 -6Z" fill="#7A1A12" stroke="#4A1200" stroke-width="8" stroke-linejoin="round"/>
    <path d="M-48 -2 Q0 8 48 -2 L46 12 Q0 20 -46 12Z" fill="#fff"/>
    <path d="M-26 38 Q0 24 26 38 Q14 50 0 50 Q-14 50 -26 38Z" fill="#FF6B6B"/>
  </g>
  <!-- cheeks -->
  <ellipse cx="-92" cy="40" rx="16" ry="10" fill="#FF8A5B" opacity="0.6"/>
  <ellipse cx="92" cy="22" rx="16" ry="10" fill="#FF8A5B" opacity="0.6"/>
</symbol>

<symbol id="crown" viewBox="-80 -60 160 120" overflow="visible">
  <path d="M-70 40 L-78 -30 L-38 6 L0 -50 L38 6 L78 -30 L70 40Z" fill="url(#goldG)" stroke="#7A4500" stroke-width="8" stroke-linejoin="round"/>
  <rect x="-72" y="32" width="144" height="22" rx="6" fill="url(#goldG)" stroke="#7A4500" stroke-width="8"/>
  <circle cx="0" cy="12" r="11" fill="#FF3B5C" stroke="#7A0020" stroke-width="4"/>
  <circle cx="-42" cy="20" r="8" fill="#3BB8FF" stroke="#0A4A7A" stroke-width="4"/>
  <circle cx="42" cy="20" r="8" fill="#3BB8FF" stroke="#0A4A7A" stroke-width="4"/>
  <circle cx="-78" cy="-30" r="9" fill="#FFF3A0" stroke="#7A4500" stroke-width="5"/>
  <circle cx="0" cy="-50" r="9" fill="#FFF3A0" stroke="#7A4500" stroke-width="5"/>
  <circle cx="78" cy="-30" r="9" fill="#FFF3A0" stroke="#7A4500" stroke-width="5"/>
</symbol>

<!-- lemonade stand ~ 420 wide, origin at bottom center -->
<symbol id="stand" viewBox="-230 -400 460 410" overflow="visible">
  <!-- posts -->
  <rect x="-190" y="-330" width="22" height="330" fill="url(#woodG)" stroke="#4A2508" stroke-width="7"/>
  <rect x="168" y="-330" width="22" height="330" fill="url(#woodG)" stroke="#4A2508" stroke-width="7"/>
  <!-- awning -->
  <path d="M-215 -330 L215 -330 L195 -390 L-195 -390Z" fill="#fff" stroke="#4A2508" stroke-width="8" stroke-linejoin="round"/>
  <g fill="#FFD21F">
    <path d="M-195 -390 L-140 -390 L-150 -330 L-215 -330Z"/>
    <path d="M-85 -390 L-30 -390 L-33 -330 L-92 -330Z"/>
    <path d="M30 -390 L85 -390 L92 -330 L33 -330Z"/>
    <path d="M140 -390 L195 -390 L215 -330 L150 -330Z"/>
  </g>
  <path d="M-215 -330 L215 -330 L195 -390 L-195 -390Z" fill="none" stroke="#4A2508" stroke-width="8" stroke-linejoin="round"/>
  <path d="M-215 -330 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0 q21.5 30 43 0Z" fill="#FFD21F" stroke="#4A2508" stroke-width="7" stroke-linejoin="round"/>
  <!-- counter -->
  <rect x="-220" y="-175" width="440" height="30" rx="6" fill="#B8692E" stroke="#4A2508" stroke-width="8"/>
  <rect x="-200" y="-145" width="400" height="145" fill="url(#woodG)" stroke="#4A2508" stroke-width="8"/>
  <g stroke="#7A3E14" stroke-width="4" opacity="0.6"><line x1="-200" y1="-97" x2="200" y2="-97"/><line x1="-200" y1="-49" x2="200" y2="-49"/></g>
  <!-- sign -->
  <rect x="-165" y="-132" width="330" height="80" rx="12" fill="#FFF8D6" stroke="#4A2508" stroke-width="7" transform="rotate(-3 0 -92)"/>
  <text x="0" y="-72" text-anchor="middle" font-family="LG" font-size="54" fill="#F2A900" stroke="#6B3F00" stroke-width="7" paint-order="stroke" transform="rotate(-3 0 -92)">LEMONADE</text>
  <!-- pitcher -->
  <g transform="translate(-110 -175)">
    <path d="M-38 0 L-44 -96 Q-30 -110 38 -104 L34 0Z" fill="#FFE45C" fill-opacity="0.9" stroke="#2C5E7A" stroke-width="7" stroke-linejoin="round"/>
    <path d="M-42 -70 L38 -70" stroke="#fff" stroke-width="5" opacity="0.8"/>
    <path d="M36 -86 Q72 -80 62 -40 Q58 -22 34 -22" fill="none" stroke="#2C5E7A" stroke-width="10" stroke-linecap="round"/>
    <circle cx="-8" cy="-40" r="16" fill="#FFF27A" stroke="#C99000" stroke-width="4"/>
    <path d="M-26 -60 L-20 -16" stroke="#fff" stroke-width="6" opacity="0.6" stroke-linecap="round"/>
  </g>
  <!-- cups -->
  <g transform="translate(10 -175)">
    <path d="M-22 0 L-28 -58 L28 -58 L22 0Z" fill="#FFE45C" stroke="#6B3F00" stroke-width="6" stroke-linejoin="round"/>
    <rect x="-30" y="-64" width="60" height="10" rx="4" fill="#fff" stroke="#6B3F00" stroke-width="5"/>
    <path d="M8 -60 L22 -100" stroke="#FF4D6D" stroke-width="7" stroke-linecap="round"/>
    <circle cx="-24" cy="-62" r="14" fill="#FFF27A" stroke="#C99000" stroke-width="4"/>
  </g>
  <g transform="translate(90 -175)">
    <path d="M-22 0 L-28 -58 L28 -58 L22 0Z" fill="#FFE45C" stroke="#6B3F00" stroke-width="6" stroke-linejoin="round"/>
    <rect x="-30" y="-64" width="60" height="10" rx="4" fill="#fff" stroke="#6B3F00" stroke-width="5"/>
    <path d="M-6 -60 L-18 -100" stroke="#3BB8FF" stroke-width="7" stroke-linecap="round"/>
  </g>
  <!-- cash box -->
  <g transform="translate(150 -175)">
    <rect x="-26" y="-30" width="52" height="30" rx="4" fill="#3A7BD5" stroke="#12305C" stroke-width="6"/>
    <rect x="-20" y="-48" width="40" height="20" rx="3" fill="url(#cashG)" stroke="#145A22" stroke-width="5"/>
  </g>
</symbol>

<!-- mansion ~ 700 wide, origin bottom center -->
<symbol id="mansion" viewBox="-360 -420 720 430" overflow="visible">
  <!-- wings -->
  <rect x="-340" y="-210" width="210" height="210" fill="#FFF6E8" stroke="#5A4A3A" stroke-width="8"/>
  <rect x="130" y="-210" width="210" height="210" fill="#FFF6E8" stroke="#5A4A3A" stroke-width="8"/>
  <path d="M-355 -210 L-235 -275 L-115 -210Z" fill="#3B5BA9" stroke="#1E2E5A" stroke-width="8" stroke-linejoin="round"/>
  <path d="M115 -210 L235 -275 L355 -210Z" fill="#3B5BA9" stroke="#1E2E5A" stroke-width="8" stroke-linejoin="round"/>
  <g fill="url(#winG)" stroke="#5A4A3A" stroke-width="6">
    <rect x="-310" y="-180" width="55" height="60" rx="4"/><rect x="-215" y="-180" width="55" height="60" rx="4"/>
    <rect x="-310" y="-95" width="55" height="60" rx="4"/><rect x="-215" y="-95" width="55" height="60" rx="4"/>
    <rect x="160" y="-180" width="55" height="60" rx="4"/><rect x="255" y="-180" width="55" height="60" rx="4"/>
    <rect x="160" y="-95" width="55" height="60" rx="4"/><rect x="255" y="-95" width="55" height="60" rx="4"/>
  </g>
  <!-- center block -->
  <rect x="-150" y="-300" width="300" height="300" fill="#FFFDF6" stroke="#5A4A3A" stroke-width="8"/>
  <path d="M-175 -300 L0 -400 L175 -300Z" fill="#FFFDF6" stroke="#5A4A3A" stroke-width="8" stroke-linejoin="round"/>
  <path d="M-140 -308 L0 -386 L140 -308Z" fill="#FFD21F" stroke="#B07A00" stroke-width="5" stroke-linejoin="round"/>
  <circle cx="0" cy="-334" r="20" fill="#FFF3A0" stroke="#B07A00" stroke-width="5"/>
  <text x="0" y="-322" text-anchor="middle" font-family="LG" font-size="30" fill="#B07A00">$</text>
  <rect x="-160" y="-300" width="320" height="18" fill="#E9DFC8" stroke="#5A4A3A" stroke-width="6"/>
  <g fill="url(#winG)" stroke="#5A4A3A" stroke-width="6">
    <rect x="-110" y="-260" width="55" height="70" rx="4"/><rect x="55" y="-260" width="55" height="70" rx="4"/>
  </g>
  <path d="M-45 0 L-45 -130 Q0 -180 45 -130 L45 0Z" fill="#7A3E14" stroke="#3A1E08" stroke-width="7"/>
  <circle cx="30" cy="-60" r="6" fill="#FFD21F"/>
  <!-- columns -->
  <g fill="#FFFFFF" stroke="#5A4A3A" stroke-width="6">
    <rect x="-140" y="-282" width="26" height="282"/><rect x="-88" y="-282" width="26" height="282"/>
    <rect x="62" y="-282" width="26" height="282"/><rect x="114" y="-282" width="26" height="282"/>
  </g>
  <rect x="-200" y="-14" width="400" height="22" fill="#E9DFC8" stroke="#5A4A3A" stroke-width="6"/>
</symbol>

<!-- sports car ~ 520 wide, origin bottom center (wheel bottoms) -->
<symbol id="car" viewBox="-280 -170 560 180" overflow="visible">
  <ellipse cx="0" cy="4" rx="260" ry="14" fill="#000" opacity="0.25"/>
  <path d="M-250 -40 Q-255 -80 -215 -88 L-120 -100 Q-70 -150 10 -152 Q80 -150 140 -104 L225 -88 Q262 -78 258 -40 L252 -22 Q250 -10 236 -10 L-236 -10 Q-250 -10 -252 -24Z"
    fill="url(#carG)" stroke="#4A0606" stroke-width="9" stroke-linejoin="round"/>
  <path d="M-100 -100 Q-58 -138 8 -140 Q66 -138 112 -104Z" fill="url(#glassG)" stroke="#4A0606" stroke-width="6" stroke-linejoin="round"/>
  <path d="M6 -140 L2 -102" stroke="#4A0606" stroke-width="6"/>
  <path d="M-70 -110 L-30 -130 L-50 -104Z" fill="#fff" opacity="0.45"/>
  <path d="M-230 -62 L230 -62" stroke="#FFB0A8" stroke-width="6" opacity="0.7" stroke-linecap="round"/>
  <path d="M228 -76 L254 -70 L254 -56 L232 -58Z" fill="#FFF6A0" stroke="#4A0606" stroke-width="4"/>
  <path d="M-246 -72 L-226 -74 L-228 -58 L-250 -58Z" fill="#FF3030" stroke="#4A0606" stroke-width="4"/>
  <g>
    <circle cx="-150" cy="-30" r="44" fill="#151515" stroke="#000" stroke-width="5"/>
    <circle cx="-150" cy="-30" r="24" fill="#D8D8E0" stroke="#555" stroke-width="5"/>
    <circle cx="-150" cy="-30" r="7" fill="#555"/>
    <circle cx="160" cy="-30" r="44" fill="#151515" stroke="#000" stroke-width="5"/>
    <circle cx="160" cy="-30" r="24" fill="#D8D8E0" stroke="#555" stroke-width="5"/>
    <circle cx="160" cy="-30" r="7" fill="#555"/>
  </g>
</symbol>

<filter id="shadow" x="-20%" y="-20%" width="140%" height="140%"><feDropShadow dx="0" dy="8" stdDeviation="6" flood-color="#000" flood-opacity="0.35"/></filter>
`;
// big outlined title text with a 3D drop layer
exports.title = (txt, x, y, size, fill, opts={}) => {
  const {stroke='#3A1A00', sw=size*0.16, depth=size*0.08, anchor='middle', font='LG', extra=''} = opts;
  return `<g ${extra}>
   <text x="${x}" y="${y+depth}" text-anchor="${anchor}" font-family="${font}" font-size="${size}" fill="${stroke}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round" paint-order="stroke">${txt}</text>
   <text x="${x}" y="${y}" text-anchor="${anchor}" font-family="${font}" font-size="${size}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}" stroke-linejoin="round" paint-order="stroke">${txt}</text>
  </g>`;
};
