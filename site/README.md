# Site do ALLO Protocol

Site estático em Jekyll hospedado em `https://rapport.tec.br/allo`.

## Estrutura

- `_config.yml` — configuração do Jekyll (URL base `/allo`).
- `_layouts/` — templates `default`, `home` e `page`.
- `_includes/` — componentes reutilizáveis (head, header, footer).
- `_sass/` — estilos em Sass com a identidade visual Rapport.
- `assets/css/` — ponto de entrada do CSS.
- `*.md` — páginas de conteúdo.

## Executar localmente

```bash
cd site
bundle install
bundle exec jekyll serve
```

Acesse `http://localhost:4000/allo`.

## Deploy

O deploy é feito automaticamente pela GitHub Actions (`.github/workflows/jekyll-gh-pages.yml`)
para a branch `gh-pages` sempre que houver push na branch principal.

## Licença

O conteúdo textual segue a mesma licença do projeto ALLO-v2.
