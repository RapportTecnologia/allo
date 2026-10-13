# Auditoria comparativa — Allo V2 e refatoração GoF

**Data:** 2026-10-13  
**Analista:** Devin  
**Escopo:** `main`, `origin/refatoracao-gof` e correções em `refatoracao-gof-revisao`

## Resumo executivo

O branch `main` preserva o comportamento original, mas mantém riscos operacionais já existentes, incluindo administração concentrada, ausência de pausa/timelock no contrato core e uso de uma versão antiga do compilador. O branch `refatoracao-gof` melhora separação de responsabilidades com Strategy, Factory, Facade e State, porém introduziu dois bloqueadores de upgrade e integração.

Status da revisão: **em mitigação**. As correções de inicialização pós-upgrade, validação de dependências, limite de taxa e scripts de deploy/upgrade foram aplicadas. A Facade permanece inadequada para produção e foi tornada abstrata para impedir implantação acidental até existir um fluxo autenticado que preserve o usuário como administrador do pool e pagador dos ativos.

## Comparação

| Área | `main` | `refatoracao-gof` | Revisão |
|---|---|---|---|
| Cálculo de taxa | Acoplado e previsível | Strategy intercambiável | Strategy validada; taxa não pode exceder aporte |
| Criação de strategies | Clone interno | Factory intercambiável | Factory exige bytecode |
| Upgrade de proxy | Layout anterior | Novos slots sem migração | `initializeGoFPatterns()` com `reinitializer(2)` |
| Direct Grants Lite | Condicionais locais | State explícito | Mantido; comportamento legado preservado |
| Facade | Inexistente | Fluxo atômico não funcional | Bloqueada para produção; requer redesign autenticado |
| Testes | Suíte ampla existente | Novos testes unitários | Regressões para EOA, taxa excessiva e migração |

## Findings

| ID | Severidade | Localização | Descrição | Situação |
|---|---|---|---|---|
| AUD-001 | Crítica | `contracts/core/Allo.sol` | Proxy existente teria `feeStrategy` e `strategyFactory` zerados; funding e criação de pool falhariam após upgrade. | Mitigado com reinitializer dedicado; upgrade deve chamá-lo atomicamente. |
| AUD-002 | Alta | `contracts/core/AlloStarterFacade.sol` | `Allo` autentica a Facade como caller, que não é membro do perfil; ETH não era encaminhado e tokens não podem ser debitados diretamente do usuário. | Contido: contrato abstrato e não implantável; redesign continua pendente. |
| AUD-003 | Alta | `contracts/core/Allo.sol` | Fee Strategy arbitrária podia retornar valor maior que o aporte, causando underflow/DoS sem erro de domínio claro. | Mitigado com `INVALID_FEE`. |
| AUD-004 | Média | `contracts/core/Allo.sol` | Endereços de Strategy/Factory aceitavam EOAs. | Mitigado com validação de bytecode. |
| AUD-005 | Média | configuração | Foundry não está instalado no ambiente; testes e build não puderam ser executados. | Aberto; instalar Foundry e executar comandos registrados. |
| AUD-006 | Média | governança | Atualizações críticas dependem de owner único, sem multisig/timelock on-chain imposto pelo contrato. | Aberto; requisito de deploy/governança. |
| AUD-007 | Baixa | documentação | `git diff --check` encontrou whitespace e ausência de newline em arquivos do branch GoF. | Aberto, sem impacto de runtime. |
| AUD-008 | Alta | `scripts/core/upgrades/upgradeAllo.ts` | Upgrade não executava a migração GoF, deixando duas transações e uma janela de indisponibilidade. | Mitigado com `validateUpgrade` e `upgradeAndCall` atômico. |
| AUD-009 | Alta | `scripts/core/upgrades/upgradeRegistry.ts` | Script de Registry carregava `deployments.getAllo()`, podendo atualizar o proxy errado. | Mitigado com `getRegistry()` e validação de storage. |
| AUD-010 | Média | DAO | Não há DAO customizada no escopo; contratos “governor” são strategies de integração e não governança administrativa do protocolo. | Documentado; multisig/timelock continuam obrigatórios. |

## Melhorias aplicadas

1. Reinitializer V2 sem parâmetros externos, single-use e compatível com `ProxyAdmin.upgradeAndCall`.
2. Validação de que Fee Strategy e Strategy Factory possuem bytecode.
3. Rejeição explícita de taxas maiores que o valor financiado.
4. Testes de regressão para migração via Proxy Admin, EOA e taxa excessiva.
5. Upgrade atômico do Allo com validação prévia de storage layout.
6. Correção do endereço-alvo e validação de storage no upgrade do Registry.
7. Validação de saldo, endereços e bytecode nos deploys core.
8. Facade acadêmica tornada abstrata e não implantável.
9. Checklist, requisitos e runbook de deploy adicionados.

## Invariantes revisadas

- A taxa cobrada nunca excede o valor financiado.
- A soma de taxa e valor líquido corresponde ao aporte, ressalvados tokens fee-on-transfer já medidos por saldo.
- Apenas o owner altera dependências de cálculo/criação.
- Uma migração GoF só pode ser inicializada uma vez.
- Uma strategy criada deve continuar passando as verificações de `poolId` e `Allo` existentes.

## Plano obrigatório antes de deploy

- Executar o upgrade com chamada atômica a `initializeGoFPatterns()`.
- Remover a Facade do artefato de deploy ou redesenhá-la com autorização assinada/forwarder confiável e testes E2E.
- Executar `forge build --sizes`, `forge test`, cobertura, Slither, Mythril e Echidna.
- Validar storage layout contra a implementação implantada.
- Transferir owner para multisig com timelock mínimo de 48 horas.
- Obter auditoria externa independente antes de mainnet.

## Evidência de comandos

- `git diff --check main...origin/refatoracao-gof`: falhou por whitespace documental.
- `forge test --no-match-contract '(Lockup|SQF)'`: não executado; `forge` ausente.
- `forge build --sizes`: não executado; `forge` ausente.
- `npx hardhat compile`: bloqueado porque o ambiente usa Node.js 18.19.1 e esta configuração exige Node.js 22.13.0 ou superior.
- Slither: bloqueado porque não havia artefatos Foundry em `out/build-info`; Mythril e Echidna também dependem de build/compilador funcional para análise conclusiva.
- `npx tsc --noEmit`: bloqueado porque as dependências locais não estão instaladas; o `npx` recusou executar o TypeScript esperado.
- `npm audit --audit-level=high`: bloqueado porque o branch não possui lockfile; não foi criado lockfile automaticamente para evitar alterar dependências sem validação.
