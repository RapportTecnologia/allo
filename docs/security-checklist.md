# Checklist de segurança dos smart contracts

**Última revisão:** 2026-10-13  
**Responsável:** Devin  
**Escopo:** Allo V2, branch `refatoracao-gof` e revisão `refatoracao-gof-revisao`

## Modelo de ameaça

Os contratos core controlam pools, taxas, tesouraria, perfis e execução de strategies externas. As principais chaves são owner, administradores e gestores de pools. Comprometimento do owner permite trocar dependências e parâmetros; por isso multisig e timelock são obrigatórios antes de produção. Strategies, factories, tokens e destinatários são tratados como externos não confiáveis. Invariantes: taxa não excede aporte; somente perfis autorizados criam pools; dependências críticas não são EOAs; migração executa uma vez; strategy criada pertence ao pool e ao Allo esperado.

## Checklist operacional completo

### 1. Definição do modelo de ameaça
- [x] Contratos financeiros, atores, chamadas externas, impactos de chaves e invariantes identificados — 2026-10-13, Devin.
- [ ] Estados completos de pausa, recuperação e migração operacional documentados.

### 2. Compilador, dependências e construção
- [x] Versão e otimizador registrados em `foundry.toml` — 2026-10-13, Devin.
- [ ] Atualizar Solidity 0.8.19 após estudo de compatibilidade e executar build reproduzível/bytecode verification.

### 3. Controle de acesso
- [x] Setters GoF são `onlyOwner`; a migração não recebe parâmetros e é protegida por `reinitializer(2)` — 2026-10-13, Devin.
- [ ] Adotar multisig, timelock e transferência administrativa em duas etapas.

### 4. Autenticação e assinaturas
- [x] Não foi adicionada autenticação por `tx.origin` — 2026-10-13, Devin.
- [ ] Redesenhar Facade com EIP-712/ERC-1271, nonce, deadline, chainId e endereço do contrato.

### 5. Cadastro e inscrição de usuários
- [x] Registry e autorização de perfil foram revisados no fluxo alterado — 2026-10-13, Devin.
- [ ] Adicionar limites explícitos para strings/arrays e recuperação de controlador.

### 6. Privacidade e dados pessoais
- [x] Nenhum segredo ou PII novo foi armazenado on-chain — 2026-10-13, Devin.
- [ ] Documentar classificação de metadados e política off-chain.

### 7. DIDs
- [ ] Não aplicável ao escopo funcional auditado; reavaliar se DIDs forem integrados.

### 8. Verifiable Credentials
- [ ] Não aplicável ao escopo funcional auditado; reavaliar se VCs forem integradas.

### 9. Reentrância
- [x] Entradas críticas alteradas preservam `nonReentrant`; chamadas externas revisadas — 2026-10-13, Devin.
- [ ] Executar testes específicos cross-function e com token malicioso/ERC-777.

### 10. Chamadas externas e contratos não confiáveis
- [x] Fee Strategy e Factory agora exigem bytecode; retornos críticos continuam validados — 2026-10-13, Devin.
- [ ] Limitar governança das dependências com timelock e validar interfaces por ERC-165 ou probe segura quando aplicável.

### 11. Ether, pagamentos e retiradas
- [x] Fluxos de funding e base fee foram revisados; `tx.origin` não autentica operações — 2026-10-13, Devin.
- [ ] Testar reentrância/destinatário que rejeita ETH e impedir recipient zero em recovery.

### 12. ERC-20 e Token Coin
- [x] Funding mede saldo antes/depois para fee-on-transfer — 2026-10-13, Devin.
- [ ] Cobrir tokens sem retorno, rebasing, blacklist e permit.

### 13. Wrapped Coin
- [ ] Não aplicável ao escopo alterado; nenhuma lógica wrapped foi adicionada.

### 14. Oráculos e preços
- [ ] Não aplicável ao escopo alterado; nenhuma lógica de preço foi adicionada.

### 15. Front-running, MEV e ordenação
- [x] Nenhuma nova fonte de aleatoriedade ou autenticação temporal foi adicionada — 2026-10-13, Devin.
- [ ] Avaliar CREATE2 salts e Facade contra front-running no redesign.

### 16. DoS e consumo de gás
- [x] Taxa acima do aporte agora falha com erro explícito — 2026-10-13, Devin.
- [ ] Limitar arrays de managers/batches e medir custo de deployments de State/Strategy.

### 17. Aritmética e precisão
- [x] Limite da taxa e cálculos percentuais revisados — 2026-10-13, Devin.
- [ ] Executar fuzzing de valores extremos e arredondamento.

### 18. Eventos e auditoria
- [x] Troca de dependências emite eventos existentes — 2026-10-13, Devin.
- [ ] Adicionar evento explícito de migração/upgrade na governança operacional.

### 19. Contratos upgradeable
- [x] Novos slots estão no final; reinitializer V2 é single-use e o script usa validação de layout + upgrade atômico — 2026-10-13, Devin.
- [ ] Testar proxy real, persistência de storage, implementação bloqueada e rollback.

### 20. delegatecall, proxies e módulos
- [x] Nenhum novo `delegatecall` controlado pelo usuário foi introduzido — 2026-10-13, Devin.
- [ ] Validar storage layout automatizado e chamadas através do proxy.

### 21. Pausa e resposta a incidentes
- [ ] Implementar/justificar Pausable, runbook, rotação de chaves e responsabilidades.

### 22. Testes automatizados
- [x] Testes de regressão foram adicionados para EOA, taxa excessiva e migração única — 2026-10-13, Devin.
- [ ] Executar suíte, cobertura >=90% core e cenários de upgrade/reentrância.

### 23. Fuzzing e invariantes
- [x] Invariantes financeiras e de migração foram documentadas — 2026-10-13, Devin.
- [ ] Executar Foundry/Echidna stateful com múltiplos atores e valores extremos.

### 24. Análise estática e formal
- [x] Revisão manual comparativa executada — 2026-10-13, Devin.
- [ ] Executar Slither, Mythril, Echidna e SMTChecker; justificar cada alerta.

## Prioridades do projeto

1. Migração segura de proxy e storage layout.
2. Bloqueio/redesign da Facade.
3. Multisig e timelock para owner.
4. Reentrância e plugins externos.
5. Testes de invariantes, fuzzing e cobertura.

## Histórico

| Data | Responsável | Alteração |
|---|---|---|
| 2026-10-13 | Devin | Auditoria inicial comparativa e registro das mitigações GoF. |
| 2026-10-13 | Devin | Aplicação das regras de DAO/deploy: upgrade atômico, validações de scripts, Facade abstrata e runbook. |
