---
layout: page
title: "Contribuir"
subtitle: "Fork, melhorias e integração de código no ALLO-v2"
---

## Por que fazer um fork?

O Allo Protocol V2 é open-source e licenciado sob AGPL-3.0-only. Fazer um fork permite:

- Testar novas estratégias de alocação.
- Adicionar padrões de projeto ou refatorar módulos específicos.
- Integrar uma camada de governança DAO customizada.
- Adaptar o protocolo para outras redes EVM.
- Contribuir com correções de segurança ou melhorias de documentação.

## Como fazer o fork

### 1. Fork no GitHub

Acesse o repositório do fork acadêmico:

👉 [github.com/RapportTecnologia/allo](https://github.com/RapportTecnologia/allo)

Clique em **Fork** e escolha sua conta ou organização.

### 2. Clone o seu fork

```bash
git clone https://github.com/<seu-usuario>/allo.git
cd allo
```

### 3. Adicione o upstream

```bash
git remote add upstream https://github.com/allo-protocol/allo-v2.git
```

Isso permite sincronizar atualizações do repositório original.

### 4. Crie uma branch para sua contribuição

```bash
git checkout -b feat/minha-melhoria
```

Use prefixos claros:

- `feat/` — nova funcionalidade.
- `fix/` — correção de bug.
- `refactor/` — refatoração sem mudança de comportamento.
- `docs/` — documentação.
- `security/` — ajuste de segurança.

## Padrões de código

- Siga o estilo do projeto: `forge fmt` para Solidity e ESLint/Prettier para TypeScript.
- Mantenha contratos abaixo do limite EIP-170 (~24 KB).
- Prefira composição e interfaces a herança profunda.
- Documente funções públicas com NatSpec.
- Adicione testes para funções novas ou modificadas.

## Testes obrigatórios

Antes de abrir um pull request, execute:

```bash
forge build --sizes
forge test --no-match-contract '(Lockup|SQF)'
bun run typecheck
```

Para mudanças em contratos upgradeáveis, execute também:

```bash
npx @openzeppelin/upgrades-core validate
```

## Checklist de segurança

- [ ] Nenhuma chave privada, senha ou API key foi commitada.
- [ ] `.env` e arquivos `*.key` estão no `.gitignore`.
- [ ] Novas funções possuem validação de acesso.
- [ ] Entradas externas são validadas antes de uso.
- [ ] Operações de transferência de tokens usam reentrancy guard quando necessário.
- [ ] Mudanças em storage layout de contratos upgradeáveis foram validadas.
- [ ] Scripts não imprimem segredos em logs.

## Como abrir um Pull Request

1. Sincronize com o upstream:

   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. Faça push da sua branch:

   ```bash
   git push origin feat/minha-melhoria
   ```

3. Abra o PR no GitHub descrevendo:
   - O problema que resolve.
   - A abordagem adotada.
   - Testes executados e resultados.
   - Mudanças na interface ou no storage layout.

## Áreas que precisam de contribuição

- Estratégias de alocação inovadoras.
- Melhorias na documentação e tutoriais.
- Ferramentas de análise de segurança (Slither, Mythril, Echidna).
- Scripts de deploy para novas redes.
- Integração de DAO tokenizada com proposta/voto/quorum.
- Testes de integração para a camada de governança.

## Comunidade

- Documentação oficial: [docs.allo.gitcoin.co](https://docs.allo.gitcoin.co/)
- GitHub original: [allo-protocol/allo-v2](https://github.com/allo-protocol/allo-v2)
- Fork acadêmico: [RapportTecnologia/allo](https://github.com/RapportTecnologia/allo)
- Site do mantenedor acadêmico: [rapport.tec.br/allo](https://rapport.tec.br/allo)
