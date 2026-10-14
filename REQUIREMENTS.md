# Requisitos de segurança e operação dos smart contracts

## Arquitetura e runtime

- **SC-ARCH-001:** Allo deve calcular taxas por `IFeeStrategy` e criar clones por `IStrategyFactory`, validando que dependências configuradas possuem bytecode.
- **SC-ARCH-002:** Uma taxa calculada nunca pode exceder o valor financiado.
- **SC-ARCH-003:** O State pattern de Direct Grants Lite deve preservar as fronteiras temporais e o comportamento legado de registro, alocação e distribuição.
- **SC-ARCH-004:** `AlloStarterFacade` deve preservar a identidade do usuário: o usuário permanece owner do perfil, recebe a role de manager do pool e paga os ativos; a Facade só exerce a role de admin do pool via funções restritas ao owner do perfil.

## Upgrade

- **SC-UPG-001:** Upgrade de proxy legado para a versão GoF deve executar `initializeGoFPatterns()` atomicamente por `upgradeAndCall`.
- **SC-UPG-002:** A migração GoF deve ser single-use, não aceitar configuração externa e preservar percentual, pools, roles, Registry e treasury existentes.
- **SC-UPG-003:** Todo upgrade deve passar por validação de storage layout e teste em fork antes de testnet/mainnet.
- **SC-UPG-004:** Implementações, Proxy Admin e owners devem ser verificados após o upgrade; rollback só pode usar bytecode auditado e storage-compatible.

## Governança e deploy

- **SC-GOV-001:** Owner, Proxy Admin e treasury de produção devem ser multisig; operações críticas devem passar por timelock on-chain mínimo de 48 horas.
- **SC-GOV-002:** Deployer, relayer e administrador devem ser papéis separados e seguir menor privilégio.
- **SC-GOV-003:** Scripts devem validar chainId, endereços, bytecode, saldo para gas e storage layout antes de operações on-chain.
- **SC-GOV-004:** Scripts nunca devem imprimir ou receber chaves privadas como argumento de linha de comando.
- **SC-GOV-005:** Não existe DAO customizada no escopo atual. Uma futura DAO deve implementar proposta, voto, quorum, cooldown, limite de propostas, whitelist de executores, Pausable e timelock.

## Validação

- **SC-TEST-001:** Funções novas ou modificadas devem ter casos felizes, acesso não autorizado e falhas esperadas.
- **SC-TEST-002:** Contratos core devem alcançar cobertura mínima de 90%, incluindo branches.
- **SC-TEST-003:** Build deve verificar limite EIP-170; Slither, Mythril e Echidna devem ser executados antes de mainnet.
- **SC-TEST-004:** O fluxo de upgrade deve ser testado por proxy real, comprovando manutenção do estado e migração executada uma única vez.

## Critérios de aceite desta revisão

- **AC-GOF-001:** Configurar EOA como Fee Strategy ou Factory reverte.
- **AC-GOF-002:** Fee Strategy que retorna taxa maior que o aporte reverte com erro de domínio.
- **AC-GOF-003:** Migração GoF executada pelo caminho de Proxy Admin configura dependências e segunda execução reverte.
- **AC-GOF-004:** `upgradeAllo.ts` valida storage e executa migração na mesma transação.
- **AC-GOF-005:** `upgradeRegistry.ts` usa o endereço do Registry, não o endereço do Allo.
- **AC-GOF-006:** Facade redesenhada como operador policy-bound: deployável, porém sem privilégio discricionário.
- **AC-FACADE-001:** `initializeCampaign` preserva identidade: usuário é owner do perfil, recebe `POOL_MANAGER_ROLE`; admin do pool fica na Facade imutável.
- **AC-FACADE-002:** Financiamento ERC-20 puxa exatamente `_amount` do usuário e zera a allowance do Allo ao final.
- **AC-FACADE-003:** ETH é encaminhado 1:1 via `msg.value` (baseFee e/ou funding nativo).
- **AC-FACADE-004:** `initializeCampaign` reverte se o caller não for owner/member do perfil ou se a Facade não for membro do perfil.
- **AC-FACADE-005:** `addPoolManager`/`removePoolManager` revertem para quem não é owner do perfil dono do pool.
- **AC-FACADE-006:** `fundPool` via Facade puxa ERC-20 do caller e zera allowance.

## Governança multisig/timelock (SEC-005 / SEC-009)

- **AC-GOV-001:** `AlloTimelockController` impõe delay mínimo de 48 horas (17.280 blocos ou `2 days`); proposer, executor e canceller únicos são o `AlloMultisigWallet`.
- **AC-GOV-002:** `AlloMultisigWallet` exige `threshold` confirmações entre `signers` para submeter, confirmar e executar transações; signers/threshold só podem ser alterados por transação aprovada pelo próprio wallet.
- **AC-GOV-003:** Após o deploy, o deployer inicial renuncia `TIMELOCK_ADMIN_ROLE`, tornando o timelock auto-administrado.
- **AC-GOV-004:** `transferOwnershipToGovernance.ts` transfere `Allo.owner()`, `Registry.ALLO_OWNER` e a propriedade do `ProxyAdmin` para o timelock em uma única execução verificável.
- **AC-GOV-005:** `upgradeAlloViaGovernance.ts` prepara a nova implementação, valida storage layout e agenda uma única operação `ProxyAdmin.upgradeAndCall(..., initializeGoFPatterns)` no timelock.
- **AC-GOV-006:** Scripts de governança leem a chave do signatário da variável de ambiente (`GOV_SIGNER_PRIVATE_KEY` ou `DEPLOYER_PRIVATE_KEY`), nunca de argumento de linha de comando, e imprimem `transactionId` e `operationId` para rastreabilidade.
- **AC-GOV-007:** Operações agendadas podem ser canceladas pelo multisig antes da execução, e a execução só é possível após `getMinDelay()`.
