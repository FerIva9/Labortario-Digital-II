import json
from pathlib import Path
from PIL import Image, ImageOps
# Primeiro extraia as páginas com pdfimages -png, conforme assets/ORIGEM.md.
base=Path(__file__).resolve().parents[1]
sets=[('Aventura pirata','#dff2f0',['Navio pirata','Mapa do tesouro','Ilha','Tesouro','Pirata','Tempestade']),('Reino encantado','#f6ead7',['Cavaleiro','Dragão','Castelo','Floresta','Tesouro','Princesa']),('Viagem espacial','#eae5fa',['Foguete','Astronauta','Planeta','Alienígena','Base espacial','Pistola espacial']),('Minha rotina','#e3effa',['Acordar','Tomar café','Tomar banho','Escovar os dentes','Vestir-se','Ir à escola'])]
catalog={}
for h,(title,color,names) in enumerate(sets):
 im=Image.open(base/f'assets/pdf_originais/pagina-{h:03}.png').convert('RGB')
 chars=[]
 for p,name in enumerate(names):
  x=p%3*512
  # O astronauta atravessa y=512; a separação real nessa página fica em y=532.
  split=532 if h == 2 else 512
  top,bottom=(0,split) if p < 3 else (split,1024)
  file=f'assets/h{h}_p{p}.png'
  tile=im.crop((x,top,x+512,bottom))
  tile=ImageOps.pad(tile,(512,512),color='white')
  tile.save(base/file)
  chars.append(dict(nome=name,simbolo=str(p),imagem=file))
 catalog[str(h)]=dict(nome=title,cor=color,personagens=chars)
(base/'historias.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2)+'\n')
