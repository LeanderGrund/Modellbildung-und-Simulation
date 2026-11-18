"""Lösungstext mit Formeln und MATLAB-Diagrammen als PDF setzen.

Aufruf nach dem MATLAB-Lauf: python3 erstelle_pdf.py
Pakete: pip install -r requirements-pdf.txt
"""
from pathlib import Path
from tempfile import TemporaryDirectory
from html import escape
import re
import matplotlib
matplotlib.use('Agg')
from matplotlib.mathtext import math_to_image
from matplotlib.font_manager import FontProperties, findfont
from markdown_it import MarkdownIt
from PIL import Image as PILImage
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.pagesizes import A4
from reportlab.platypus import (SimpleDocTemplate, Paragraph, Image, Spacer,
                               Table, TableStyle, Preformatted, KeepTogether, CondPageBreak)

ROOT = Path(__file__).resolve().parent
WIDTH = A4[0] - 88
for name, weight in [('Body','normal'),('Bold','bold')]:
    pdfmetrics.registerFont(TTFont(name, findfont(FontProperties(family='DejaVu Sans',weight=weight))))
pdfmetrics.registerFontFamily('Body',normal='Body',bold='Bold',italic='Body',boldItalic='Bold')
BODY = ParagraphStyle('body',fontName='Body',fontSize=10,leading=15,spaceAfter=8,allowWidows=0,allowOrphans=0)
CAPTION = ParagraphStyle('caption',parent=BODY,fontSize=9,leading=12,textColor=colors.HexColor('#475569'))
CELL = ParagraphStyle('cell',parent=BODY,fontSize=8,leading=12,spaceAfter=0)
CODE = ParagraphStyle('code',fontName='Courier',fontSize=8,leading=11,spaceAfter=9,backColor=colors.HexColor('#f1f5f9'),borderPadding=7)
HEADINGS = {n:ParagraphStyle(f'h{n}',parent=BODY,fontName='Bold',fontSize={1:20,2:16,3:12,4:10.5}[n],leading={1:26,2:21,3:17,4:15}[n],spaceBefore=12,spaceAfter=9,keepWithNext=True,textColor=colors.HexColor('#173b57')) for n in range(1,5)}


def normalize(latex):
    latex = ' '.join(latex.split()).replace('&','')
    for old,new in [(r'\begin{aligned}',''),(r'\end{aligned}',''),
                    (r'\mathbf1',r'\mathbf{1}'),(r'\tfrac',r'\frac'),
                    (r'\land',r'\wedge'),(r'\lor',r'\vee')]:
        latex=latex.replace(old,new)
    latex=re.sub(r'\\(mathbb|mathbf|widetilde|sqrt)\s+([A-Za-z])',r'\\\1{\2}',latex)
    latex=re.sub(r'\\frac\s*(\d)(\d)',r'\\frac{\1}{\2}',latex)
    latex=latex.replace(r'\overset{\mathrm{unabh.}}\sim',r'\overset{\mathrm{unabh.}}{\sim}')
    latex=re.sub(r'\\ge(?![A-Za-z])',r'\\geq',latex)
    return re.sub(r'\\le(?![A-Za-z])',r'\\leq',latex)


def build():
    text=(ROOT/'Diffusion1_Loesung.md').read_text()
    output=ROOT/'output/pdf/Diffusion1_Loesung.pdf'
    output.parent.mkdir(parents=True,exist_ok=True)
    with TemporaryDirectory(prefix='diffusion-formeln-') as tmp:
        formulas={}; counter=0
        def formula(latex,display=False):
            nonlocal counter
            counter+=1; file=Path(tmp)/f'{counter}.png'
            math_to_image('$'+normalize(latex)+'$',file,prop=FontProperties(size=12 if display else 10),dpi=220,format='png')
            with PILImage.open(file) as im: w,h=im.size
            return file,w*72/220,h*72/220
        def store(match,display):
            key=f'MATH{len(formulas)}TOKEN'
            content=match.group(1)
            if display:
                content=content.replace(r'\begin{aligned}','').replace(r'\end{aligned}','')
            formulas[key]=[formula(line,display) for line in content.split(r'\\')] if display else [formula(content)]
            return '\n\n'+key+'\n\n' if display else key
        text=re.sub(r'\\\[(.*?)\\\]',lambda m:store(m,True),text,flags=re.S)
        text=re.sub(r'\\\((.*?)\\\)',lambda m:store(m,False),text,flags=re.S)
        def rich(children):
            result=''
            for token in children or []:
                kind=token.type
                if kind=='text':
                    parts=re.split(r'(MATH\d+TOKEN)',token.content)
                    for part in parts:
                        if part in formulas:
                            file,w,h=formulas[part][0]
                            result+=f'<img src="{file}" width="{w}" height="{h}" valign="-3"/>'
                        else: result+=escape(part)
                elif kind=='code_inline': result+='<font name="Courier" size="8">'+escape(token.content)+'</font>'
                elif kind in ('softbreak','hardbreak'): result+=' ' if kind=='softbreak' else '<br/>'
                elif kind=='strong_open': result+='<b>'
                elif kind=='strong_close': result+='</b>'
                elif kind=='em_open': result+='<i>'
                elif kind=='em_close': result+='</i>'
                elif kind=='link_open': result+=f'<a href="{escape(token.attrGet("href"),quote=True)}" color="#1d6088">'
                elif kind=='link_close': result+='</a>'
                else: raise ValueError(f'Unbehandeltes Inline-Element: {kind}')
            return result
        def picture(path):
            with PILImage.open(path) as im: w,h=im.size
            scale=min(WIDTH/w,470/h)
            return Image(str(path),width=w*scale,height=h*scale)
        tokens=MarkdownIt().enable('table').parse(text)
        story=[]; i=0; list_depth=0
        while i<len(tokens):
            token=tokens[i]; kind=token.type
            if kind=='heading_open':
                if i+4<len(tokens) and tokens[i+3].type=='paragraph_open' and tokens[i+4].children and tokens[i+4].children[0].type=='image':
                    story.append(CondPageBreak(540))
                story.append(Paragraph(rich(tokens[i+1].children),HEADINGS[int(token.tag[1])]))
                i+=3; continue
            if kind=='paragraph_open':
                inline=tokens[i+1]
                if inline.content in formulas:
                    for file,w,h in formulas[inline.content]:
                        scale=min(1,WIDTH/w)
                        image=Image(str(file),width=w*scale,height=h*scale); image.hAlign='LEFT'
                        story.extend([image,Spacer(1,8)])
                elif inline.children and inline.children[0].type=='image':
                    img=inline.children[0]
                    story.append(KeepTogether([picture(ROOT/img.attrGet('src')),Spacer(1,4),Paragraph(escape(img.content),CAPTION)]))
                else:
                    prefix='• ' if list_depth else ''
                    story.append(Paragraph(prefix+rich(inline.children),BODY))
                i+=3; continue
            if kind=='fence': story.append(Preformatted(escape(token.content.rstrip()),CODE)); i+=1; continue
            if kind=='table_open':
                rows=[]; row=[]; i+=1
                while tokens[i].type!='table_close':
                    item=tokens[i]
                    if item.type=='tr_open': row=[]
                    elif item.type=='inline': row.append(Paragraph(rich(item.children),CELL))
                    elif item.type=='tr_close': rows.append(row)
                    i+=1
                widths=[WIDTH/len(rows[0])]*len(rows[0])
                table=Table(rows,colWidths=widths,repeatRows=1,hAlign='LEFT')
                table.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#e8eff5')),('LINEBELOW',(0,0),(-1,0),.7,colors.HexColor('#7390a5')),('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#d6dee5')),('VALIGN',(0,0),(-1,-1),'TOP'),('TOPPADDING',(0,0),(-1,-1),6),('BOTTOMPADDING',(0,0),(-1,-1),6)]))
                story.extend([table,Spacer(1,10)]); i+=1; continue
            if kind in ('bullet_list_open','ordered_list_open'): list_depth+=1
            elif kind in ('bullet_list_close','ordered_list_close'): list_depth-=1
            elif kind not in ('list_item_open','list_item_close'): raise ValueError(f'Unbehandelter Block: {kind}')
            i+=1
        def page(canvas,doc):
            canvas.saveState(); canvas.setFont('Body',8); canvas.setFillColor(colors.HexColor('#64748b'))
            canvas.drawString(44,A4[1]-28,'Modellbildung und Simulation | Woche 4 | PR 2.1')
            canvas.drawRightString(A4[0]-44,27,str(doc.page)); canvas.restoreState()
        doc=SimpleDocTemplate(str(output),pagesize=A4,rightMargin=44,leftMargin=44,topMargin=46,bottomMargin=44,title='Woche 4 - Diffusions-Blockautomat',author='')
        doc.build(story,onFirstPage=page,onLaterPages=page)
    print(output)


if __name__=='__main__': build()
