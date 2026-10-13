# Segurança de deploy e upgrade

## Papéis obrigatórios

| Papel | Responsabilidade | Restrição |
|---|---|---|
| Deployer | Publicar implementação/proxy | Temporário; remover privilégios após deploy |
| Proxy Admin | Executar upgrades | Multisig controlada por timelock >= 48h |
| Allo owner | Parâmetros, plugins e recuperação | Multisig controlada por timelock >= 48h |
| Registry owner | Recuperação autorizada | Multisig; separada do relayer |
| Relayer | Operações rotineiras | Sem privilégios administrativos |
| Treasury | Receber taxas | Multisig ou contrato de tesouraria auditado |

Chaves administrativas devem permanecer em hardware wallet/HSM/cofre; nunca em argumentos de linha de comando, logs ou repositório.

## Upgrade seguro do Allo GoF

O upgrade de uma instância anterior deve executar `initializeGoFPatterns()` na mesma transação do upgrade. O script `scripts/core/upgrades/upgradeAllo.ts` usa `validateUpgrade` e `upgradeProxy(..., { call: "initializeGoFPatterns" })`.

A migração não recebe parâmetros controláveis, deriva a Fee Strategy do percentual já armazenado e é protegida por `reinitializer(2)`. Isso permite a execução por `ProxyAdmin` durante `upgradeAndCall` sem abrir configuração arbitrária.

Nunca faça o upgrade em duas transações. Se a chamada atômica falhar, toda a transação deve reverter.

## Pré-deploy obrigatório

- [ ] Código congelado e commit/tag auditado registrados.
- [ ] Node.js e Foundry nas versões documentadas.
- [ ] `forge build --sizes` sem contrato core acima de 24KB.
- [ ] Testes unitários, integração, upgrade e invariantes aprovados.
- [ ] Cobertura core >= 90%.
- [ ] Slither sem high/medium não justificado.
- [ ] Mythril sem finding crítico.
- [ ] Echidna sem falha de invariante.
- [ ] `validateUpgrade` e storage layout aprovados.
- [ ] Fork de mainnet e testnet aprovados.
- [ ] Owner, Proxy Admin e treasury são endereços não zero conferidos independentemente.
- [ ] Owner e Proxy Admin pertencem a multisigs distintas ou têm separação formal aprovada.
- [ ] Timelock on-chain >= 48h configurado para upgrades e mudanças críticas.
- [ ] Saldo de gas verificado sem registrar chaves ou payloads sensíveis.
- [ ] Bytecode reproduzível e implementação conferida.
- [ ] Auditoria externa independente aprovada.
- [ ] `AlloStarterFacade` ausente dos artefatos de produção.

## Sequência de upgrade

1. Gerar e revisar storage layout.
2. Simular `validateUpgrade` e upgrade atômico em fork.
3. Propor operação no timelock pela multisig.
4. Aguardar no mínimo 48 horas.
5. Conferir chainId, proxy, implementação, bytecode e calldata da migração.
6. Simular a transação imediatamente antes da execução.
7. Executar pela multisig/Proxy Admin.
8. Verificar implementação, owner, Registry, treasury, Fee Strategy e Factory.
9. Criar e financiar um pool de teste controlado em testnet/fork.
10. Publicar endereços e hashes em canal confiável e iniciar monitoramento.

## Rollback e incidente

Um rollback só pode apontar para bytecode previamente auditado e storage-compatible. Não execute downgrade que remova ou reinterprete os slots GoF. Em incidente:

1. interromper operações off-chain e alertar signatários;
2. preservar hashes de transação, blocos e logs sanitizados;
3. avaliar retirada segura e impacto sobre pools;
4. propor correção/rollback via multisig e timelock, salvo procedimento emergencial aprovado;
5. rotacionar chaves comprometidas e remover privilégios temporários;
6. publicar post-mortem sem segredos ou PII.

## DAO e governança

Este repositório não contém uma DAO customizada que implemente propostas, votação e execução genérica. Estratégias com “governor” no nome integram governança externa, mas não substituem multisig/timelock administrativo do protocolo. Se uma DAO customizada for adicionada, ela deve implementar estados de proposta, quorum, votos finais, whitelist de executores, cooldown, limite de propostas, Pausable, Factory/Registry e timelock conforme a regra do projeto.
