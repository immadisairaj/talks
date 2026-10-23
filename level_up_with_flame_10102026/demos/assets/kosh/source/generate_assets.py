import cairosvg, math, random, os
os.makedirs('svg', exist_ok=True); os.makedirs('png', exist_ok=True)
FONT = "Inter"
GOLD_STOPS = '<stop offset="0" stop-color="#FFF1C1"/><stop offset="0.35" stop-color="#F2C766"/><stop offset="0.7" stop-color="#C8902E"/><stop offset="1" stop-color="#8A5A12"/>'

def out(name, svg, w, h, scale=1):
    open(f'svg/{name}.svg', 'w').write(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=f'png/{name}.png', output_width=int(w*scale), output_height=int(h*scale))

# --- Brand mark -----------------------------------------------------------
logo = f'''<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">{GOLD_STOPS}</linearGradient>
<linearGradient id="sheen" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/></linearGradient></defs>
<rect x="16" y="16" width="480" height="480" rx="120" fill="url(#g)"/>
<rect x="16" y="16" width="480" height="240" rx="120" fill="url(#sheen)"/>
<g fill="#111114">
<rect x="150" y="120" width="62" height="272" rx="14"/>
<path d="M224 256 L330 120 L404 120 L296 256 L404 392 L330 392 Z"/>
<circle cx="372" cy="256" r="22" fill="#111114"/>
</g></svg>'''
out('kosh_logo', logo, 512, 512)

# --- Coin -----------------------------------------------------------------
coin = f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<defs>
<radialGradient id="face" cx="0.38" cy="0.32" r="0.8"><stop offset="0" stop-color="#FFF4CC"/><stop offset="0.35" stop-color="#F6CF6E"/><stop offset="0.75" stop-color="#D49A34"/><stop offset="1" stop-color="#9A6516"/></radialGradient>
<linearGradient id="rim" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFE9A8"/><stop offset=".5" stop-color="#B67B1F"/><stop offset="1" stop-color="#6E440C"/></linearGradient>
<radialGradient id="inner" cx="0.6" cy="0.65" r="0.75"><stop offset="0" stop-color="#FBD978"/><stop offset="1" stop-color="#C98E2B"/></radialGradient>
</defs>
<circle cx="128" cy="128" r="124" fill="url(#rim)"/>
<circle cx="128" cy="128" r="110" fill="url(#face)"/>
<circle cx="128" cy="128" r="92" fill="url(#inner)"/>
<circle cx="128" cy="128" r="92" fill="none" stroke="#8A5A12" stroke-opacity=".55" stroke-width="3"/>
<g stroke="#8A5A12" stroke-opacity=".35" stroke-width="2">''' + ''.join(
    f'<line x1="{128+math.cos(a)*112:.1f}" y1="{128+math.sin(a)*112:.1f}" x2="{128+math.cos(a)*121:.1f}" y2="{128+math.sin(a)*121:.1f}"/>'
    for a in [i*2*math.pi/60 for i in range(60)]) + f'''</g>
<text x="125" y="165" font-family="{FONT}" font-weight="900" font-size="124" text-anchor="middle" fill="#FFF4CF">₹</text>
<text x="131" y="171" font-family="{FONT}" font-weight="900" font-size="124" text-anchor="middle" fill="#6E430B" fill-opacity=".7">₹</text>
<text x="128" y="168" font-family="{FONT}" font-weight="900" font-size="124" text-anchor="middle" fill="#B98128">₹</text>
<ellipse cx="96" cy="78" rx="44" ry="20" transform="rotate(-30 96 78)" fill="#fff" fill-opacity=".35"/>
</svg>'''
out('coin', coin, 256, 256)

# --- Scratch card cover (brushed gunmetal + monogram pattern) ---------------
random.seed(3)
lines = ''.join(f'<line x1="0" y1="{y}" x2="1200" y2="{y+random.uniform(-6,6):.1f}" stroke="#fff" stroke-opacity="{random.uniform(.015,.05):.3f}" stroke-width="1"/>' for y in range(0, 800, 3))
pattern = ''.join(f'<text x="{x}" y="{y}" font-family="{FONT}" font-weight="800" font-size="46" fill="#fff" fill-opacity=".045" transform="rotate(-18 {x} {y})">K</text>'
                  for x in range(-40, 1260, 120) for y in range(40, 860, 110))
cover = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">
<defs>
<linearGradient id="m" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3A3E47"/><stop offset=".45" stop-color="#6B707B"/><stop offset=".55" stop-color="#8A8F99"/><stop offset="1" stop-color="#30333A"/></linearGradient>
<linearGradient id="holo" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#7FE0FF" stop-opacity=".0"/><stop offset=".2" stop-color="#7FE0FF" stop-opacity=".35"/><stop offset=".45" stop-color="#C79BFF" stop-opacity=".35"/><stop offset=".7" stop-color="#FFD27F" stop-opacity=".35"/><stop offset="1" stop-color="#FFD27F" stop-opacity="0"/></linearGradient>
<linearGradient id="g" x1="0" y1="0" x2="1" y2="1">{GOLD_STOPS}</linearGradient>
<clipPath id="c"><rect width="1200" height="800" rx="56"/></clipPath>
</defs>
<g clip-path="url(#c)">
<rect width="1200" height="800" fill="url(#m)"/>
{lines}
{pattern}
<rect x="-100" y="300" width="1400" height="90" fill="url(#holo)" transform="rotate(-12 600 345)"/>
<text x="600" y="430" font-family="{FONT}" font-weight="800" font-size="64" letter-spacing="14" text-anchor="middle" fill="#F4F5F7" fill-opacity=".92">SCRATCH TO REVEAL</text>
<text x="600" y="500" font-family="{FONT}" font-weight="500" font-size="34" letter-spacing="4" text-anchor="middle" fill="#E7E9EE" fill-opacity=".7">your savings reward</text>
<rect x="64" y="640" width="96" height="96" rx="24" fill="url(#g)"/>
<g fill="#111114" transform="translate(64 640) scale(0.1875)"><rect x="150" y="120" width="62" height="272" rx="14"/><path d="M224 256 L330 120 L404 120 L296 256 L404 392 L330 392 Z"/></g>
<text x="184" y="705" font-family="{FONT}" font-weight="800" font-size="44" fill="#F4F5F7">kosh</text>
<text x="1136" y="705" font-family="{FONT}" font-weight="600" font-size="28" text-anchor="end" fill="#E7E9EE" fill-opacity=".6">GOAL REACHED · OCT</text>
</g>
<rect x="2" y="2" width="1196" height="796" rx="54" fill="none" stroke="#fff" stroke-opacity=".18" stroke-width="4"/>
</svg>'''
out('scratch_cover', cover, 1200, 800)

# --- Under the scratch layer --------------------------------------------------
glints = ''.join(f'<circle cx="{random.uniform(60,1140):.0f}" cy="{random.uniform(60,740):.0f}" r="{random.uniform(1.5,4):.1f}" fill="#F6CF6E" fill-opacity="{random.uniform(.25,.8):.2f}"/>' for _ in range(90))
reward = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800" viewBox="0 0 1200 800">
<defs><radialGradient id="glow" cx=".5" cy=".55" r=".6"><stop offset="0" stop-color="#5A3B0E"/><stop offset=".55" stop-color="#1B1510"/><stop offset="1" stop-color="#0E0E12"/></radialGradient>
<clipPath id="c"><rect width="1200" height="800" rx="56"/></clipPath></defs>
<g clip-path="url(#c)"><rect width="1200" height="800" fill="url(#glow)"/>{glints}
<text x="600" y="250" font-family="{FONT}" font-weight="600" font-size="36" letter-spacing="8" text-anchor="middle" fill="#F6CF6E">YOU UNLOCKED</text>
<text x="600" y="390" font-family="{FONT}" font-weight="800" font-size="120" text-anchor="middle" fill="#FFF1C1">Kosh Coins</text>
<text x="600" y="470" font-family="{FONT}" font-weight="500" font-size="34" text-anchor="middle" fill="#E7E9EE" fill-opacity=".7">catch them in your vault · 5 coins = ₹1</text>
</g></svg>'''
out('scratch_reward', reward, 1200, 800)

# --- Vault bowl (back + front), drawn for a 5:3 box -------------------------
def bowl_path(w, h, inset=0):
    pts = []
    for i in range(41):
        a = math.pi * i / 40
        pts.append((w/2 + math.cos(a)*(w/2-inset), math.sin(a)*(h-inset)))
    return pts
W, H = 1000, 600
back_pts = bowl_path(W, H)
d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in back_pts) + ' Z'
bowl_back = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs><linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1C1C24"/><stop offset="1" stop-color="#0B0B10"/></linearGradient>
<radialGradient id="in" cx=".5" cy=".1" r=".9"><stop offset="0" stop-color="#3B2A10" stop-opacity=".7"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient></defs>
<path d="{d}" fill="url(#b)"/><path d="{d}" fill="url(#in)"/>
<ellipse cx="{W/2}" cy="10" rx="{W/2-6}" ry="14" fill="#2A2A33"/>
</svg>'''
out('vault_back', bowl_back, W, H)
front_d = 'M' + ' L'.join(f'{x:.1f} {y:.1f}' for x, y in back_pts)
bowl_front = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="0">{GOLD_STOPS}</linearGradient>
<linearGradient id="glass" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity=".0"/><stop offset=".18" stop-color="#fff" stop-opacity=".16"/><stop offset=".3" stop-color="#fff" stop-opacity="0"/></linearGradient></defs>
<path d="{d}" fill="url(#glass)"/>
<path d="{front_d}" fill="none" stroke="url(#g)" stroke-width="16" stroke-linecap="round"/>
<line x1="8" y1="6" x2="{W-8}" y2="6" stroke="url(#g)" stroke-width="10" stroke-linecap="round"/>
<text x="{W/2}" y="{H*0.62:.0f}" font-family="{FONT}" font-weight="800" font-size="64" letter-spacing="18" text-anchor="middle" fill="#F6CF6E" fill-opacity=".22">VAULT</text>
</svg>'''
out('vault_front', bowl_front, W, H)

# --- Stadium field (night match) --------------------------------------------
FW, FH = 800, 580
stripes = ''.join(f'<rect x="{x}" y="0" width="40" height="{FH}" fill="#fff" fill-opacity=".035"/>' for x in range(0, FW, 80))
field = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{FW}" height="{FH}" viewBox="0 0 {FW} {FH}">
<defs><radialGradient id="grass" cx=".5" cy=".5" r=".6"><stop offset="0" stop-color="#2F7A4C"/><stop offset=".7" stop-color="#1E5636"/><stop offset="1" stop-color="#123A24"/></radialGradient>
<clipPath id="oval"><ellipse cx="{FW/2}" cy="{FH/2}" rx="{FW/2-4}" ry="{FH/2-4}"/></clipPath>
<radialGradient id="flood" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fff" stop-opacity=".12"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient></defs>
<g clip-path="url(#oval)"><rect width="{FW}" height="{FH}" fill="url(#grass)"/>{stripes}
<ellipse cx="{FW/2}" cy="{FH/2}" rx="{FW*0.3}" ry="{FH*0.3}" fill="none" stroke="#fff" stroke-opacity=".35" stroke-width="2" stroke-dasharray="8 8"/>
<rect x="{FW/2-14}" y="{FH/2-70}" width="28" height="140" rx="3" fill="#CDB98C"/>
<line x1="{FW/2-18}" y1="{FH/2-56}" x2="{FW/2+18}" y2="{FH/2-56}" stroke="#fff" stroke-width="2"/>
<line x1="{FW/2-18}" y1="{FH/2+56}" x2="{FW/2+18}" y2="{FH/2+56}" stroke="#fff" stroke-width="2"/>
<rect width="{FW}" height="{FH}" fill="url(#flood)"/></g>
<ellipse cx="{FW/2}" cy="{FH/2}" rx="{FW/2-10}" ry="{FH/2-10}" fill="none" stroke="#fff" stroke-opacity=".8" stroke-width="3"/>
<ellipse cx="{FW/2}" cy="{FH/2}" rx="{FW/2-3}" ry="{FH/2-3}" fill="none" stroke="#0B0B10" stroke-width="6"/>
</svg>'''
out('stadium_field', field, FW, FH)

# --- Checkout montage: product + success ------------------------------------
phones = f'''<svg xmlns="http://www.w3.org/2000/svg" width="600" height="600" viewBox="0 0 600 600">
<defs><linearGradient id="bg" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#23232C"/><stop offset="1" stop-color="#121218"/></linearGradient>
<linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3A3A45"/><stop offset="1" stop-color="#16161C"/></linearGradient>
<linearGradient id="cup" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#4A4A57"/><stop offset=".5" stop-color="#1E1E25"/><stop offset="1" stop-color="#0E0E12"/></linearGradient>
<linearGradient id="g" x1="0" y1="0" x2="1" y2="1">{GOLD_STOPS}</linearGradient></defs>
<rect width="600" height="600" rx="64" fill="url(#bg)"/>
<ellipse cx="300" cy="520" rx="190" ry="22" fill="#000" fill-opacity=".45"/>
<path d="M150 330 C150 150 450 150 450 330" fill="none" stroke="url(#band)" stroke-width="44" stroke-linecap="round"/>
<path d="M150 330 C150 150 450 150 450 330" fill="none" stroke="#fff" stroke-opacity=".08" stroke-width="6" transform="translate(0 -14)"/>
<rect x="104" y="290" width="104" height="190" rx="48" fill="url(#cup)"/>
<rect x="392" y="290" width="104" height="190" rx="48" fill="url(#cup)"/>
<rect x="118" y="304" width="20" height="160" rx="10" fill="url(#g)"/>
<rect x="462" y="304" width="20" height="160" rx="10" fill="url(#g)"/>
<ellipse cx="146" cy="330" rx="18" ry="34" fill="#fff" fill-opacity=".08"/>
</svg>'''
out('product_headphones', phones, 600, 600)

success = f'''<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">{GOLD_STOPS}</linearGradient></defs>
<circle cx="128" cy="128" r="118" fill="url(#g)"/><circle cx="128" cy="128" r="118" fill="none" stroke="#fff" stroke-opacity=".4" stroke-width="4"/>
<path d="M78 132 L112 166 L182 92" fill="none" stroke="#111114" stroke-width="22" stroke-linecap="round" stroke-linejoin="round"/>
</svg>'''
out('success_tick', success, 256, 256)
print('done')
