#!/usr/bin/env python3
"""Render authored mock lessons into local diagrams, handouts and six-second videos.
Development tool only: pip install -r scripts/requirements-mock-media.txt.
No remote service or model participates. Pillow draws editable-by-code diagrams;
FFmpeg encodes three illustrated teaching stages with a visible time indicator.
"""
import argparse, concurrent.futures, functools, hashlib, json, math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg
ROOT = Path(__file__).resolve().parent.parent
FONT = ROOT / 'Resources/Fonts/BookCourseNotoSansSC-Regular.ttf'
BOLD = ROOT / 'Resources/Fonts/BookCourseNotoSansSC-Bold.ttf'
OUT = ROOT / 'Resources/Content/assets/mock-books'
PALETTES = {
 'math': ('#7154cf','#f2edff'), 'physics': ('#267eae','#e9f5fc'),
 'chemistry': ('#16856b','#e6f7f0'), 'english': ('#b16628','#fff3e3'),
 'calculus': ('#4662bb','#edf0ff'), 'mechanics': ('#38758d','#edf7fb'), 'psychology': ('#9b5da3','#f8ecfa'), 'ecology': ('#348052','#edf9ee'),
}
@functools.lru_cache(maxsize=30)
def font(n, bold=False): return ImageFont.truetype(str(BOLD if bold else FONT), n)
@functools.lru_cache(maxsize=30)
def symbol_font(n):
    return ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial Unicode.ttf', n)
@functools.lru_cache(maxsize=30000)
def glyph_font(f, character):
    mask=f.getmask(character);unknown=f.getmask('\uffff')
    return symbol_font(f.size) if mask.size==unknown.size and bytes(mask)==bytes(unknown) else f
@functools.lru_cache(maxsize=30000)
def glyph_width(f, character): return glyph_font(f,character).getlength(character)
def draw_line(draw,xy,value,f,color):
    x,y=xy;run='';current=None
    for character in value:
        selected=glyph_font(f,character)
        if current is not None and selected is not current:
            draw.text((x,y),run,font=current,fill=color);x+=draw.textlength(run,font=current);run=''
        current=selected;run+=character
    if run:draw.text((x,y),run,font=current,fill=color)

def wrap(draw, text, f, width):
    lines=[]
    for para in str(text).split('\n'):
        line='';used=0
        for c in para:
            advance=glyph_width(f,c)
            if line and used+advance>width:
                lines.append(line);line=c;used=advance
            else:line+=c;used+=advance
        lines.append(line)
    return lines

def text(draw, xy, value, size, color='#243047', width=1300, bold=False, spacing=10):
    x,y=xy;f=font(size,bold)
    for line in wrap(draw,value,f,width):
        draw_line(draw,(x,y),line,f,color);y+=size+spacing
    return y

def subject(book):
    if 'advanced' in book or 'functions' in book:return 'calculus'
    if 'psychology' in book:return 'psychology'
    if 'ecology' in book:return 'ecology'
    if 'mechanics' in book or 'motion' in book:return 'mechanics'
    return next(s for s in ['physics','chemistry','english','math'] if s in book)

def arrow(d,a,b,color,width=5):
    d.line([a,b],fill=color,width=width)
    angle=math.atan2(b[1]-a[1],b[0]-a[0]);r=15
    d.polygon([b,(b[0]-r*math.cos(angle-.45),b[1]-r*math.sin(angle-.45)),
        (b[0]-r*math.cos(angle+.45),b[1]-r*math.sin(angle+.45))],fill=color)

def sketch(d, box, key, chapter, accent):
    x,y,w,h=box
    def p(a,b):return (x+a*w,y+b*h)
    def label(a,b,s):draw_line(d,p(a,b),s,font(24),accent)
    if key=='mechanics':
        d.rounded_rectangle((*p(.33,.3),*p(.63,.65)),radius=10,fill='white',outline=accent,width=4)
        d.line([p(.05,.67),p(.95,.67)],fill=accent,width=4)
        arrow(d,p(.48,.5),p(.48,.03),accent,5);label(.51,.02,'N')
        arrow(d,p(.48,.5),p(.48,.95),'#ca7448',5);label(.51,.85,'mg')
        arrow(d,p(.48,.5),p(.92,.5),accent,5);label(.84,.27,'F')
    elif key in ['english','psychology','ecology']:
        for a,b,c,t in [(0.02,.15,.27,'Subject' if key=='english' else '生产者' if key=='ecology' else '观察'),(.36,.15,.28,'Verb' if key=='english' else '消费者' if key=='ecology' else '情境'),(.72,.15,.26,'Object' if key=='english' else '分解者' if key=='ecology' else '核对')]:
            l,top=p(a,b);r,bottom=p(a+c,.65)
            d.rounded_rectangle((l,top,r,bottom),radius=18,fill='white',outline=accent,width=3);label(a+.02,.31,t)
        arrow(d,p(.29,.4),p(.34,.4),accent);arrow(d,p(.66,.4),p(.70,.4),accent)
    elif key=='chemistry':
        # Six particles on each side: a rearrangement schematic preserves atom count.
        for b in [.25,.60]:
            d.line([p(.06,b),p(.16,b),p(.26,b)],fill=accent,width=4)
            for a in [.06,.16,.26]:
                cx,cy=p(a,b);d.ellipse((cx-12,cy-12,cx+12,cy+12),fill=accent)
        for b in [.18,.42,.66]:
            d.line([p(.68,b),p(.84,b)],fill=accent,width=4)
            for a in [.68,.84]:
                cx,cy=p(a,b);d.ellipse((cx-12,cy-12,cx+12,cy+12),fill=accent)
        arrow(d,p(.35,.4),p(.55,.4),accent);label(.03,.82,'反应前');label(.65,.82,'重排后')
    elif key=='physics' and ('c11' in chapter or 'c12' in chapter):
        d.rectangle((*p(.1,.15),*p(.88,.75)),outline=accent,width=5)
        d.rectangle((*p(.35,.09),*p(.63,.23)),fill='white',outline=accent,width=4)
        d.line([p(.32,.66),p(.32,.86)],fill=accent,width=7)
        d.line([p(.38,.70),p(.38,.82)],fill=accent,width=4)
        arrow(d,p(.67,.75),p(.83,.75),accent);label(.73,.48,'I');label(.42,.29,'R')
    elif key=='physics' and 'c13-s5' in chapter:
        for b in [.18,.72]:d.line([p(.1,b),p(.9,b)],fill=accent,width=5)
        arrow(d,p(.45,.69),p(.45,.23),accent,5);label(.5,.35,'hν');label(.02,.75,'E₁');label(.02,.03,'E₂')
    elif key=='physics' and 'c13-s4' in chapter:
        for offset in [0,.18]:
            pts=[p(i/99,.42+offset+.18*math.sin(i/99*4*math.pi)) for i in range(100)]
            d.line(pts,fill=accent if offset==0 else '#ca7448',width=4)
        arrow(d,p(.15,.9),p(.9,.9),accent,3);label(.35,.02,'电磁波传播')
    elif key=='physics' and 'c13' in chapter:
        d.rounded_rectangle((*p(.2,.3),*p(.8,.65)),radius=12,outline=accent,width=4)
        d.line([p(.5,.3),p(.5,.65)],fill=accent,width=4);label(.27,.35,'N');label(.64,.35,'S')
        for b in [.05,.82]:arrow(d,p(.2,b),p(.8,b),accent,3)
    elif key=='physics':
        for z,c in [(.15,'+'),(.82,'−')]:
            cx,cy=p(z,.45);d.ellipse((cx-31,cy-31,cx+31,cy+31),fill='white',outline=accent,width=4)
            draw_line(d,(cx-14,cy-22),c,font(32),accent)
        for b in [.18,.45,.72]:arrow(d,p(.27,b),p(.69,b),accent,3)
        label(.43,.84,'场的方向')
    elif key=='math' and 'c8' in chapter:
        pts=[p(.18,.38),p(.62,.38),p(.62,.86),p(.18,.86)]
        shift=(w*.18,-h*.25)
        back=[(a+shift[0],b+shift[1]) for a,b in pts]
        d.line(pts+[pts[0]],fill=accent,width=4);d.line(back+[back[0]],fill=accent,width=4)
        for a,b in zip(pts,back):d.line([a,b],fill=accent,width=3)
    elif key=='math' and 'c9' in chapter:
        for i,v in enumerate([.3,.58,.76,.48,.22]):
            a=.1+i*.17;d.rectangle((*p(a,.9-v),*p(a+.1,.9)),fill=accent)
        d.line([p(.05,.9),p(.98,.9)],fill=accent,width=3);label(.2,.02,'样本分布示意')
    else:
        origin=p(.12,.82);arrow(d,origin,p(.98,.82),accent,3);arrow(d,origin,p(.12,.04),accent,3)
        if key=='calculus':
            points=[p(.15+i*.008,.78-(i/95)**2*.65) for i in range(96)]
            if 'c4' in chapter or 'c5' in chapter or 'c6' in chapter:
                d.polygon([p(.15,.82)]+points+[p(.91,.82)],fill='#d7e1fc')
            d.line(points,fill=accent,width=5);label(.55,.06,'y = f(x)')
        else:
            arrow(d,origin,p(.60,.25),accent,7);arrow(d,origin,p(.90,.57),'#e29b48',7)
            label(.50,.12,'a');label(.87,.42,'b')

def diagram(book,topic,title,booktitle):
    key=subject(book);accent,pale=PALETTES[key]
    im=Image.new('RGB',(1440,900),'#f6f8fc');d=ImageDraw.Draw(im)
    d.rounded_rectangle((24,24,1416,876),radius=30,fill='white')
    text(d,(64,44),booktitle+' · 章节图解',24,accent,width=1300,bold=True)
    y=text(d,(64,92),title,38,width=1300,bold=True)
    d.rounded_rectangle((64,y+25,1376,y+340),radius=22,fill=pale)
    sketch(d,(95,y+50,580,240),key,topic['chapter_id'],accent)
    text(d,(750,y+60),'关键关系',25,accent,bold=True,width=580)
    text(d,(750,y+108),topic['diagram_focus'],30,width=580,bold=True)
    sy=max(525,y+365)
    for i,step in enumerate(topic['diagram_steps'][:3]):
        left=64+i*446
        d.rounded_rectangle((left,sy,left+420,sy+174),radius=20,fill=pale)
        text(d,(left+20,sy+14),f'0{i+1}',22,accent,bold=True,width=380)
        text(d,(left+20,sy+58),step,28,width=380,bold=True)
    text(d,(64,804),'原创预置内容 · 结合本节讲解与练习理解图中关系',23,'#65728a',width=1300)
    return im

def handout(book,topic,title,booktitle):
    accent,pale=PALETTES[subject(book)]
    width=1440;f=font(29);scratch=ImageDraw.Draw(Image.new('RGB',(1,1)))
    content=[('本节导读',topic['summary'])]+[(b['title'],b['content']) for b in topic['blocks']]
    height=310+sum(100+len(wrap(scratch,c,f,1260))*43 for _,c in content)
    im=Image.new('RGB',(width,height),'white');d=ImageDraw.Draw(im)
    d.rectangle((0,0,width,18),fill=accent)
    y=text(d,(80,48),booktitle+' · 本地示例讲义',26,accent,width=1280,bold=True)
    y=text(d,(80,y+22),title,38,width=1280,bold=True)
    y=text(d,(80,y+18),'原创预置讲解，非教材扫描页；目录页码仅用于章节定位。',23,'#65728a',width=1280)+35
    for heading,body in content:
        d.rounded_rectangle((65,y-5,1375,y+52),radius=10,fill=pale)
        y=text(d,(82,y),heading,29,accent,width=1260,bold=True)+28
        y=text(d,(82,y),body,29,width=1260,spacing=14)+40
    return im

def video_frames(topic,title,booktitle,key):
    accent,pale=PALETTES[key];frames=[]
    stages=[('01 先看概念',topic['summary']),('02 梳理关系',topic['diagram_focus']+'\n\n'+' → '.join(topic['diagram_steps'])),
        ('03 应用与检查',next(b['content'] for b in topic['blocks'] if b['block_type']=='application'))]
    for label,body in stages:
        im=Image.new('RGB',(960,600),pale);d=ImageDraw.Draw(im)
        text(d,(38,20),booktitle+' · 讲解短片',19,accent,width=880,bold=True)
        y=text(d,(38,63),title,29,width=880,bold=True)
        y=text(d,(38,y+22),label,24,accent,width=880,bold=True)
        lines=wrap(d,body,font(25),860)
        for line in lines[:9]:
            draw_line(d,(42,y+20),line,font(25),'#243047');y+=35
        text(d,(42,550),'本地预置短片 · 可暂停回看，配合章节图解和练习',18,'#65728a',width=860)
        frames.append(im)
    return frames

def render(item,force=False):
    book,topic,title,booktitle=item;folder=OUT/book;folder.mkdir(parents=True,exist_ok=True)
    base=folder/topic['chapter_id'];stamp=Path(str(base)+'.json')
    digest=hashlib.sha256(('renderer-v3'+json.dumps(topic,sort_keys=True,ensure_ascii=False)).encode()).hexdigest()
    diagram_path=Path(str(base)+'-diagram.png');handout_path=Path(str(base)+'-handout.png');video=Path(str(base)+'.mp4')
    if not force and stamp.exists() and json.loads(stamp.read_text()).get('content_hash')==digest and all(p.exists() for p in [diagram_path,handout_path,video]):return book
    diagram(book,topic,title,booktitle).save(diagram_path,optimize=True)
    handout(book,topic,title,booktitle).save(handout_path,optimize=True)
    frames=video_frames(topic,title,booktitle,subject(book));accent=PALETTES[subject(book)][0]
    writer=imageio_ffmpeg.write_frames(str(video),(960,600),fps=6,codec='libx264',quality=7,
        macro_block_size=2,output_params=['-movflags','+faststart','-threads','1','-preset','veryfast'])
    writer.send(None)
    try:
        for n in range(36):
            im=frames[n//12].copy();d=ImageDraw.Draw(im)
            d.rectangle((0,588,int(960*(n+1)/36),599),fill=accent)
            writer.send(im.tobytes())
    finally:writer.close()
    stamp.write_text(json.dumps({'content_hash':digest,'duration':6,'kind':'authored-mock'},indent=2)+'\n')
    return book

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--book');parser.add_argument('--workers',type=int,default=4);parser.add_argument('--force',action='store_true');args=parser.parse_args()
    sources=json.loads((ROOT/'Resources/Data/sources.json').read_text())+json.loads((ROOT/'Resources/Data/MockBooks/extra-sources.json').read_text());by_id={s['summary']['book_id']:s for s in sources}
    items=[]
    for path in sorted((ROOT/'Resources/Data/MockBooks').glob('*.json')):
        book=json.loads(path.read_text())
        if not isinstance(book,dict) or 'book_id' not in book:continue
        id=book['book_id']
        if args.book and args.book!=id:continue
        source=by_id[id];chapters={c['chapter_id']:c for c in source['chapters']}
        items.extend((id,t,chapters[t['chapter_id']]['ai_title'] or chapters[t['chapter_id']]['source_title'],source['summary']['title']) for t in book['topics'])
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.workers) as pool:
        for i,_ in enumerate(pool.map(lambda item:render(item,args.force),items),1):
            if i%20==0 or i==len(items):print(f'Rendered {i}/{len(items)} topic media sets',flush=True)
if __name__=='__main__':main()
