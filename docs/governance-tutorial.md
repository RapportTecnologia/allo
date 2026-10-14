# Tutorial: Governança Multisig + Timelock do Allo Protocol

> **Escopo:** SEC-005 e SEC-009 do relatório de auditoria.  
> **Objetivo:** substituir a administração por EOA única de `Allo`, `Registry` e `ProxyAdmin` por um regime **multisig on-chain + timelock de 48h**, de forma prática, rastreável e sem expor chaves privadas.

---

## 1. Arquitetura da governança

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         Signatários do multisig (M-of-N)            │
│                    Ex: 3 endereços, threshold 2                   │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 AlloMultisigWallet (proposer/executor)                │
│  • Submeter transação          • Confirmar transação                │
│  • Executar transação          • Cancelar transação                 │
│  • Alterar signers/threshold via transação interna                  │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│              AlloTimelockController (delay mínimo 48h)              │
│  • schedule(target, value, data, predecessor, salt, delay)          │
│  • execute(...) após o delay                                         │
│  • cancel(...) enquanto pending                                      │
└───────────────────────────────┬───────────────────────────────────┘
                                │
                ┌───────────────┼───────────────┐
                ▼               ▼               ▼
         Allo.owner()   Registry.ALLO_OWNER   ProxyAdmin.owner()
```

**Por que esse modelo?**

1. **Nenhuma pessoa sozinha** pode alterar parâmetros ou fazer upgrade.
2. **Toda ação administrativa** fica visível por 48h antes de ser executada, dando tempo para usuários reagirem.
3. **ProxyAdmin** é o recurso mais crítico: quem o controla pode fazer upgrade arbitrário. Ele deve ser **sempre** o timelock.
4. **Scripts** automatizam o encaminhamento, mas **cada assinatura** ainda precisa de uma chave privada individual.

---

## 2. Pré-requisitos

### 2.1 Variáveis de ambiente

Crie ou atualize o arquivo `.env` na raiz do projeto (ele já está no `.gitignore`):

```bash
# RPC da rede desejada (ex: Sepolia)
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/<sua-key>

# Chave privada do signatário que executará o script
# Pode ser a mesma DEPLOYER_PRIVATE_KEY se você for o deployer/owner atual.
GOV_SIGNER_PRIVATE_KEY=0x...

# Configuração do multisig
GOV_SIGNERS=0xSigner1,0xSigner2,0xSigner3
GOV_THRESHOLD=2
GOV_MIN_DELAY=172800   # 48 horas em segundos
```

> **Atenção:** nunca passe a chave privada como argumento de linha de comando (`--private-key`). Use sempre variáveis de ambiente. Os scripts deste repositório rejeitam explicitamente leitura de chaves via `argv`.

### 2.2 Redes configuradas no Hardhat

O projeto já tem `sepolia`, `polygon`, `base`, etc. no `hardhat.config.ts`. Use o `--network <nome>` nos comandos.

### 2.3 Contratos base já implantados

Antes de ativar a governança você deve ter implantado:

* `Allo` proxy
* `Registry` proxy
* ambos com o deployer/owner atual

Se ainda não implantou, execute:

```bash
DEPLOYER_PRIVATE_KEY=0x... npx hardhat run scripts/core/deployRegistry.ts --network sepolia
DEPLOYER_PRIVATE_KEY=0x... npx hardhat run scripts/core/deployAllo.ts --network sepolia
```

Os endereços ficam salvos em `scripts/deployments/<contract>.deployment.json`.

---

## 3. Fluxo resumido

```text
1. deployGovernance.ts              -> cria timelock + multisig
2. transferOwnershipToGovernance.ts -> Allo, Registry e ProxyAdmin passam a ser do timelock
3. proposeAdminCall.ts              -> agenda uma ação administrativa
4. confirmProposal.ts               -> outros signers confirmam
5. executeProposal.ts                 -> executa após 48h
```

---

## 4. Passo a passo

### 4.1 Implantar a camada de governança

```bash
GOV_SIGNERS=0xSigner1,0xSigner2,0xSigner3 \
GOV_THRESHOLD=2 \
GOV_MIN_DELAY=172800 \
GOV_SIGNER_PRIVATE_KEY=0x... \
  npx hardhat run scripts/governance/deployGovernance.ts --network sepolia
```

O script:

1. Implanta `AlloTimelockController` com delay mínimo de 48h.
2. Implanta `AlloMultisigWallet` com os signers e threshold informados.
3. Concede ao multisig as roles de **proposer**, **executor** e **canceller** no timelock.
4. Renuncia a role de admin do timelock pelo deployer.

Ao final você terá algo como:

```text
AlloTimelockController deployed to: 0xTimelock...
AlloMultisigWallet deployed to:     0xMultisig...
```

Esses endereços são gravados em `scripts/deployments/governance.deployment.json`.

### 4.2 Transferir a propriedade dos contratos para o timelock

Esse passo **deve** ser feito pelo owner atual de `Allo`, `Registry` e `ProxyAdmin`.

```bash
GOV_SIGNER_PRIVATE_KEY=0x... \
  npx hardhat run scripts/governance/transferOwnershipToGovernance.ts --network sepolia
```

O script transfere:

* `Allo.owner()` → timelock
* `Registry.ALLO_OWNER` → timelock
* `ProxyAdmin.owner()` → timelock

Depois disso, **nenhuma EOA individual** pode alterar parâmetros sozinha.

### 4.3 Executar uma ação administrativa simples (exemplo: mudar `baseFee`)

#### 4.3.1 Codificar a chamada

Queremos chamar `Allo.updateBaseFee(1 ether)`.

O script lê `PROPOSAL_DATA` em hex. Você pode gerar com:

```bash
node -e "console.log(new (require('ethers').Interface)(['function updateBaseFee(uint256)']).encodeFunctionData('updateBaseFee', ['1000000000000000000']))"
```

Saída:

```text
0x6c0c...0000
```

#### 4.3.2 Submeter a proposta

```bash
PROPOSAL_TARGET=0xSeuAlloProxy \
PROPOSAL_DATA=0x6c0c...0000 \
PROPOSAL_DELAY=172800 \
GOV_SIGNER_PRIVATE_KEY=0xSigner1 \
  npx hardhat run scripts/governance/proposeAdminCall.ts --network sepolia
```

O script:

1. Agenda a operação no timelock (`timelock.schedule(...)`).
2. Empacota essa agendação como uma transação do multisig.
3. Imprime:
   * `transactionId` (id da transação no `AlloMultisigWallet`)
   * `operationId` (id da operação no `AlloTimelockController`)

#### 4.3.3 Confirmar a proposta

Outro signatário executa:

```bash
PROPOSAL_TX_ID=0 \
GOV_SIGNER_PRIVATE_KEY=0xSigner2 \
  npx hardhat run scripts/governance/confirmProposal.ts --network sepolia
```

Repita até atingir `GOV_THRESHOLD`.

#### 4.3.4 Esperar o timelock

Após a confirmação no multisig, a operação ainda precisa esperar **48h** no timelock.

Você pode acompanhar no explorador de blocos ou via cast:

```bash
cast call 0xTimelock "isOperationReady(bytes32)" 0xOperationId --rpc-url $SEPOLIA_RPC_URL
```

#### 4.3.5 Executar

```bash
PROPOSAL_TX_ID=0 \
GOV_SIGNER_PRIVATE_KEY=0xSigner1 \
  npx hardhat run scripts/governance/executeProposal.ts --network sepolia
```

Esse comando:

1. Executa a transação do multisig.
2. A transação chama `timelock.execute(...)`, que finalmente chama `Allo.updateBaseFee(1 ether)`.

### 4.4 Fazer upgrade do Allo via governança

Esse é o fluxo mais crítico. Usamos `ProxyAdmin.upgradeAndCall` para que o upgrade e a migração sejam atômicos.

```bash
GOV_SIGNER_PRIVATE_KEY=0xSigner1 \
  npx hardhat run scripts/governance/upgradeAlloViaGovernance.ts --network sepolia
```

O script:

1. Valida o storage layout da nova implementação.
2. Implanta a nova implementação `Allo.sol`.
3. Codifica a migração `initializeGoFPatterns()`.
4. Agenda no timelock a chamada `ProxyAdmin.upgradeAndCall(proxy, impl, migrationData)`.
5. Imprime `transactionId` e `operationId`.

Depois, confirme com os outros signers:

```bash
PROPOSAL_TX_ID=<id> GOV_SIGNER_PRIVATE_KEY=0xSigner2 npx hardhat run scripts/governance/confirmProposal.ts --network sepolia
```

Aguarde 48h e execute:

```bash
PROPOSAL_TX_ID=<id> GOV_SIGNER_PRIVATE_KEY=0xSigner1 npx hardhat run scripts/governance/executeProposal.ts --network sepolia
```

> **Importante:** nunca execute `upgradeProxy` diretamente de uma EOA depois que a governança estiver ativa. A função `ProxyAdmin.upgradeAndCall` só pode ser chamada pelo owner do ProxyAdmin, que deve ser o timelock.

### 4.5 Cancelar uma operação agendada

Se os signataires decidirem abortar uma proposta antes da execução:

1. Submeta uma transação do multisig para `timelock.cancel(operationId)`:

```bash
# Gere o calldata com:
node -e "console.log(new (require('ethers').Interface)(['function cancel(bytes32)']).encodeFunctionData('cancel', ['0xOperationId']))"
```

2. Use `proposeAdminCall.ts` com:
   * `PROPOSAL_TARGET=0xTimelock`
   * `PROPOSAL_DATA=0x...calldata_do_cancel`
3. Confirme e execute normalmente.

---

## 5. Gerenciamento do próprio multisig

Para alterar signers ou threshold, o próprio `AlloMultisigWallet` deve chamar suas funções internas. O processo é o mesmo: proponha uma transação cujo **target** é o próprio `AlloMultisigWallet` e cujo **data** chama `addSigner`, `removeSigner`, `replaceSigner` ou `changeThreshold`.

Exemplo: trocar threshold para 3.

```bash
node -e "console.log(new (require('ethers').Interface)(['function changeThreshold(uint256)']).encodeFunctionData('changeThreshold', ['3']))"
```

Depois use `proposeAdminCall.ts` com `PROPOSAL_TARGET=0xMultisigWallet`.

---

## 6. Checklist de segurança antes de ir para mainnet

- [ ] `AlloTimelockController.MINIMUM_DELAY()` retorna `172800` (48h).
- [ ] `AlloMultisigWallet.threshold()` é maior que 1 e menor ou igual ao número de signers.
- [ ] Nenhum signatário é um endereço de hot wallet compartilhado.
- [ ] O deployer não possui mais `TIMELOCK_ADMIN_ROLE` (`hasRole(TIMELOCK_ADMIN_ROLE, deployer) == false`).
- [ ] `Allo.owner()` == endereço do timelock.
- [ ] `Registry.hasRole(ALLO_OWNER, timelock)` == true.
- [ ] `ProxyAdmin.owner()` == endereço do timelock.
- [ ] Testnet executou o fluxo completo: deploy → transferência → proposta → confirmação → execução após 48h.
- [ ] Fork de mainnet validou o upgrade.

---

## 7. Armazenamento de chaves

* **Nunca** commit `.env`.
* Prefira hardware wallets (Ledger/Trezor) ou HSM para os signatários.
* Para testnet, use wallets descartáveis sem fundos reais.
* Os scripts **não** logam a chave privada, mesmo em modo verboso.

---

## 8. Scripts disponíveis

| Script | Função |
| --- | --- |
| `scripts/governance/deployGovernance.ts` | Cria timelock + multisig e configura roles |
| `scripts/governance/transferOwnershipToGovernance.ts` | Transfere ownership de Allo/Registry/ProxyAdmin |
| `scripts/governance/proposeAdminCall.ts` | Agenda uma chamada administrativa via multisig + timelock |
| `scripts/governance/confirmProposal.ts` | Confirma uma transação do multisig |
| `scripts/governance/executeProposal.ts` | Executa uma transação do multisig após o timelock |
| `scripts/governance/upgradeAlloViaGovernance.ts` | Prepara upgrade de Allo via timelock |

---

## 9. Testes automatizados

A camada de governança possui testes em Foundry:

* `test/foundry/governance/AlloMultisigWallet.t.sol`
* `test/foundry/governance/AlloTimelockController.t.sol`
* `test/foundry/governance/GovernanceIntegration.t.sol`

Execute:

```bash
forge test --match-path "test/foundry/governance/*.t.sol"
```
