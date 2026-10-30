# Procedência dos cartões

Fonte: `../../../imagens_projeto_labdig (2).pdf`, fornecido pelo usuário.
SHA-256: `95a42fcb92214390d676580708bfc0e93bc707d5d92f84eab220e7915415b17d`.

Extração: quatro imagens raster originais, 1536 × 1024 pixels, uma por página, extraídas diretamente com Poppler, sem captura de tela ou geração de novas ilustrações. Os originais ficam em `pdf_originais/`. Cada página contém seis ilustrações. Os cartões individuais têm 512 × 512 pixels; a página espacial usa a divisão horizontal em y=532 para preservar o astronauta inteiro. Essa página recebe margem branca para manter o formato quadrado.

Para reproduzir, a partir da pasta da aplicação (requer `pdfimages` do Poppler e Pillow):

```bash
pdfimages -png '../../imagens_projeto_labdig (2).pdf' assets/pdf_originais/pagina
python3 tools/extract_cards.py
```

O script também recria `historias.json` com o mapeamento inicial; salve suas personalizações antes de executá-lo. Não faz parte da execução normal do aplicativo.

Ordem: páginas 1–4 → histórias 0–3; leitura de cada página da esquerda para a direita, primeiro a linha superior e depois a inferior → personagens 0–5. Essa associação é uma convenção da aplicação: o PDF não contém IDs. Os nomes foram atribuídos conforme o conteúdo visual. Confira a ordem com o hardware.
