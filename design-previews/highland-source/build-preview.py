import json,math,pathlib,cairosvg
out=pathlib.Path(__file__).resolve().parent
paths=[]
for l in open(out/'projected-strokes.jsonl'):
 p=json.loads(l); length=sum(math.dist(a,b) for a,b in zip(p,p[1:]))
 if length<85 or min(y for x,y in p)>1220 or max(y for x,y in p)<0:continue
 d='M'+' L'.join(f'{x/2:.2f},{(1220-y)/2:.2f}' for x,y in p)
 paths.append(f'<path d="{d}"/>')
art='<g fill="none" stroke="currentColor" stroke-width="0.8" stroke-linejoin="round" stroke-linecap="round">'+''.join(paths)+'</g>'
art=(out/'clean-art.txt').read_text()
(out/'highland-projected.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 430 610">'+art+'</svg>')
for dark in [False,True]:
 name='dark' if dark else 'light';bg='#101114' if dark else '#f2f2f7';fg='#f5f5f7' if dark else '#17181c';muted='#8e929a' if dark else '#85868b';line='#838791' if dark else '#74777d';pill='#f5f5f7' if dark else '#30333d';inv='#151619' if dark else '#ffffff'
 def text(y,value,size,color=fg,weight=400):return f'<text x="215" y="{y}" text-anchor="middle" font-family="Noto Sans CJK SC" font-size="{size}" font-weight="{weight}" fill="{color}">{value}</text>'
 svg=f'<svg xmlns="http://www.w3.org/2000/svg" width="430" height="932" viewBox="0 0 430 932"><defs><clipPath id="crop"><rect width="430" height="610"/></clipPath></defs><rect width="430" height="932" fill="{bg}"/><g color="{line}" clip-path="url(#crop)">{art}</g>'
 svg+=f'<text x="28" y="35" font-family="sans-serif" font-size="16" font-weight="bold" fill="{fg}">9:41</text><rect x="373" y="23" width="23" height="11" rx="3" fill="none" stroke="{fg}"/><rect x="375" y="25" width="17" height="7" rx="1" fill="{fg}"/>'
 svg+=text(650,'小特钥匙',25.5,weight=700)+text(679,'靠近车辆自动连接以解锁爱车和使用车控',11.5,muted)
 svg+=f'<rect x="144" y="714" width="142" height="46" rx="23" fill="{pill}"/>'+text(743,'配对车辆',15,inv,600)
 svg+=f'<rect x="144" y="774" width="142" height="44" rx="22" fill="none" stroke="{fg}" stroke-width="1.5"/>'+text(802,'登录 Tesla 账号',14,fg,500)
 svg+=f'<rect x="139" y="916" width="152" height="5" rx="2.5" fill="{fg}"/></svg>'
 (out/f'{name}.svg').write_text(svg);cairosvg.svg2png(bytestring=svg.encode(),write_to=str(out/f'{name}.png'),scale=2)
