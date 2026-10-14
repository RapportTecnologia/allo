# Trabalho 1 - Refatoração com Padrões de Projeto em Sistema Legado (GoF)

**Disciplina:** QXD0068 - Reuso de Software (UFC Quixadá)  
**Integrantes:** Francisco Josias da Silva Batista  
**Professor:** Prof. Francisco Victor da Silva Pinheiro  
**Data de Entrega:** 14/10/2026

## Descrição do Projeto
Este repositório é um *fork* do **Allo Protocol V2** (da Gitcoin), um protocolo open-source focado na alocação e distribuição descentralizada de fundos na rede Ethereum. 

O objetivo deste fork é estritamente acadêmico: aplicar padrões de projeto estruturais e comportamentais do **GoF (Gang of Four)** em contratos inteligentes escritos em Solidity. As refatorações visam reduzir o acoplamento, melhorar a coesão das estruturas de dados e facilitar a manutenção do protocolo original, validando os conceitos ensinados na disciplina.

Os padrões aplicados foram:
- **Facade:** Simplificação da interação do usuário com `Registry` e `Allo` através do `AlloStarterFacade.sol`.
- **Strategy:** Desacoplamento da lógica de taxas (fees) do contrato principal.
- **Factory Method:** Delegação da instanciação de novas estratégias (`StrategyFactory.sol`).
- **State:** Gerenciamento dos estados das pools e alocações (`BaseStrategy.sol`).

## Instruções de Execução

O projeto utiliza **Foundry** para compilação/testes e **Hardhat** para deploy/scripts de upgrade.

1. **Pré-requisitos**
   * Instale o Foundry: https://getfoundry.sh/
   * Use Node.js 22 (definido em `.nvmrc`):
     ```bash
     nvm use 22
     ```
2. **Instalar dependências:**
   ```bash
   forge install
   npm install
   ```
3. **Configurar variáveis de ambiente:** copie `.env.sample` para `.env` e preencha RPCs, chaves e configuração de governança (`GOV_SIGNERS`, `GOV_THRESHOLD`).
4. **Compilar os contratos:**
   ```bash
   forge build
   npx hardhat compile
   ```
5. **Executar a suíte de testes:**
   ```bash
   forge test --no-match-contract '(Lockup|SQF)'
   ```
6. **Executar testes de governança:**
   ```bash
   forge test --match-path "test/foundry/governance/*.t.sol"
   ```

## Materiais Complementares

Para uma visão detalhada das mudanças, diagramas e defesa arquitetural deste projeto, consulte os arquivos disponíveis na raiz deste repositório:

- **[Relatório Técnico Completo](./Relatorio_Refatoracao_Allo.pdf):** Diagnóstico do sistema legado, análises aprofundadas de "Antes vs. Depois", diagramas de classe e fluxo.
- **[Slides da Apresentação](./Apresentacao_Allo_Protocol.pdf):** Resumo executivo dos problemas identificados e padrões aplicados (material utilizado na apresentação em sala de aula).

## Estrutura das Refatorações

Os principais arquivos modificados e criados durante o trabalho encontram-se em `contracts/core/` e `contracts/governance/`:

**Core e GoF:**
* `AlloStarterFacade.sol` (Novo — SEC-002 corrigido)
* `interfaces/IFeeStrategy.sol` e `fees/FlatFeeStrategy.sol` (Novo)
* `interfaces/IStrategyFactory.sol` e `StrategyFactory.sol` (Novo)
* `Allo.sol` (Refatorado)
* `Registry.sol` (Refatorado para transferência de `ALLO_OWNER` ao timelock)
* `BaseStrategy.sol` / `strategies/direct-grants-lite/DirectGrantsLite.sol` (Refatorado com padrões de Estado)

**Governança (SEC-005 / SEC-009):**
* `contracts/governance/AlloTimelockController.sol`
* `contracts/governance/AlloMultisigWallet.sol`
* `contracts/governance/interfaces/IAlloTimelockController.sol`

**Scripts e testes:**
* `scripts/governance/*` — deploy, transferência de ownership, proposta/confirmação/execução e upgrade via governança.
* `test/foundry/governance/*` — testes de multisig, timelock e integração.

## Validação, segurança e upgrade

A revisão de segurança está documentada em [`docs/audit-report.md`](./docs/audit-report.md), [`docs/security-checklist.md`](./docs/security-checklist.md), [`REQUIREMENTS.md`](./REQUIREMENTS.md) e [`docs/deployment-security.md`](./docs/deployment-security.md).

### Branches de revisão

| Branch | Foco |
|---|---|
| `refatoracao-gof-revisao` | Auditoria e correções GoF: reinitializer, validação de dependências, limite de taxa, scripts de deploy/upgrade. |
| `refatoracao-gof-revisao-facade` | Correção do SEC-002: `AlloStarterFacade` redesenhada como operador policy-bound em fluxo de duas fases, com testes dedicados. |
| `refatoracao-gof-revisao-vulnerabilidades-npm` | Eliminação de vulnerabilidades críticas/alta do `npm audit` (0 críticas/altas residuais). |
| `refatoracao-gof-revisao-multisig-dao` | Governança on-chain SEC-005/SEC-009: timelock de 48h + multisig M-of-N para `Allo`, `Registry` e `ProxyAdmin`. |

### Pontos críticos corrigidos

* **Upgrade seguro:** `initializeGoFPatterns()` é executado atomicamente por `ProxyAdmin.upgradeAndCall` durante o upgrade de um proxy existente.
* **Dependências:** Fee Strategy e Strategy Factory rejeitam EOAs.
* **Taxa:** `INVALID_FEE()` é revertido quando a taxa calculada supera o valor financiado.
* **Facade (SEC-002):** fluxo em duas fases preserva o usuário como owner do perfil e pagador dos ativos; a Facade imutável só exerce `POOL_ADMIN_ROLE` via funções restritas ao owner do perfil.
* **Governança (SEC-005 / SEC-009):** `AlloTimelockController` impõe delay mínimo de 48h e `AlloMultisigWallet` exige M-of-N confirmações; scripts transferem `Allo.owner()`, `Registry.ALLO_OWNER` e `ProxyAdmin.owner()` para o timelock.

> **Atenção:** `AlloStarterFacade` continua sendo um artefato experimental. Embora tenha sido redesenhada e 14 testes de identidade/authorization/pagamento passem, ela retém `POOL_ADMIN_ROLE` e só deve ser publicada em produção depois de auditoria externa independente e de aprovação explícita do trust residual documentado.

### Execução e resultados atuais

O toolchain foi normalizado (Foundry via `~/.foundry/bin` e Node.js 22 via `.nvmrc`). A suíte Foundry deve ser executada com:

```bash
forge test --no-match-contract '(Lockup|SQF)'
```

Resultados consolidados na última execução (2026-10-14):

* `forge build`: sucesso.
* `npx hardhat compile`: 185 arquivos Solidity compilados.
* `forge test --no-match-contract '(Lockup|SQF)'`: **1188 testes passando, 0 falhas**.
* Governança: **23 testes passando** (`AlloMultisigWallet`: 13, `AlloTimelockController`: 6, `GovernanceIntegration`: 4).
* Facade + GoF core: **50 testes passando** (14 Facade + 22 Fee/Factory + 14 adjacentes).
* `npm audit`: **0 críticas / 0 altas**; 62 residuais low/moderate em dependências de dev sem correção upstream.

> A certificação de cobertura mínima de 90% nos contratos core e os scans Slither/Mythril/Echidna ainda são obrigatórios antes de qualquer deploy em mainnet.


# Allo Protocol

The Allo Protocol introduces a sophisticated ecosystem on the Ethereum blockchain, enabling automated and decentralized fund allocation and distribution. The protocol comprises a set of smart contracts that collectively offer an advanced framework for fund management, fee handling, and governance. The technical architecture and interactions within the protocol are explained below.

## Table of Contents

- [Trabalho 1 - Refatoração com Padrões de Projeto em Sistema Legado (GoF)](#trabalho-1---refatoração-com-padrões-de-projeto-em-sistema-legado-gof)
  - [Descrição do Projeto](#descrição-do-projeto)
  - [Instruções de Execução](#instruções-de-execução)
  - [Materiais Complementares](#materiais-complementares)
  - [Estrutura das Refatorações](#estrutura-das-refatorações)
  - [Validação, Segurança e Upgrade](#validação-segurança-e-upgrade)
- [Allo Protocol](#allo-protocol)
  - [Table of Contents](#table-of-contents)
  - [Diagram](#diagram)
  - [Contract Overview](#contract-overview)
    - [Registry Contract (`Registry.sol`)](#registry-contract-registrysol)
    - [Anchor Contract (`Anchor.sol`)](#anchor-contract-anchorsol)
    - [Allo Contract (`Allo.sol`)](#allo-contract-allosol)
  - [Key Functionality and Interactions](#key-functionality-and-interactions)
    - [Profile Creation and Management:](#profile-creation-and-management)
    - [Secure External Interactions:](#secure-external-interactions)
    - [Advanced Fund Allocation and Distribution:](#advanced-fund-allocation-and-distribution)
    - [Fee Handling and Treasury Management:](#fee-handling-and-treasury-management)
  - [Roles and Actors](#roles-and-actors)
  - [Conclusion](#conclusion)
  - [User Flows](#user-flows)
    - [Allo Contract](#allo-contract)
    - [Registry Contract](#registry-contract)
    - [Anchor Contract](#anchor-contract)
    - [Overall Interaction](#overall-interaction)

## Diagram

```mermaid
flowchart
    Actor --> |profile management| Registry.sol --> |deploys|Anchor.sol
    PoolManager --> |createPool for profile| Allo.sol --> |validate profile| Registry.sol

    PoolManager --> |pool manager actions| Allo.sol --> |invoke pool function| BaseStrategy.sol

    PoolManager/Recipient/Allocator --> |invoke function unique to strategy implmentation|BaseStrategy.sol
```

## Contract Overview

<table>
<thead>
  <tr>
    <th>Contract</th>
    <th>Purpose</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td>Registry.sol</td>
    <td>Registry of profiles which offers profile management</td>
  </tr>
  <tr>
    <td>Anchor.sol</td>
    <td>- Contract which can receive funds / execute transaction.<br>- Generated using identityId and name of the profile<br>- Is linked to a profile in Registry.sol</td>
  </tr>
  <tr>
    <td>Allo.sol</td>
    <td>- Management of a pool<br>- Requires a profile from registry to create a pool<br>- Expects a strategy which implements BaseStrategy.sol<br>- Expects all interactions with the functions on BaseStrategys.sol to happen via Allo.sol</td>
  </tr>
  <tr>
    <td>BaseStrategy.sol</td>
    <td>- Abstract contract which implements IStrategy.sol<br>- Every strategy should override the internal functions to be deemed as a valid strategy <br>- Can have other functions unique to the strategy which can be invoked directly on the strategy</td>
  </tr>
</tbody>
</table>

### Registry Contract (`Registry.sol`)

The `Registry` contract serves as the foundational building block of the Allo Protocol. It facilitates the creation, attestation, and management of profiles. A profile is a unique entity representing a user's identity within the protocol. This contract offers functions to query profiles by ID and anchor, as well as to create new profiles with personalized metadata, attestation addresses, and members.

Each time a profile generates a new anchor (during profile creation or when profile name is updated), it triggers the deployment of an Anchor Contract. These Anchor Contracts serve as versatile tools that can receive funds or fulfill other designated purposes. This dynamic mechanism enables profiles to engage in a wide array of activities within the protocol, enhancing flexibility and functionality across the Allo ecosystem.


### Anchor Contract (`Anchor.sol`)

The `Anchor` contract is a vital component that enhances the capabilities of profiles. It acts as an isolated enclave, allowing profile owners to securely interact with external addresses. Profile owners can execute calls to target addresses while maintaining control over the amount of native tokens sent and the data transmitted. This contract leverages the `Registry` contract for verifying ownership, ensuring that only authorized users can utilize its functionality.

### Allo Contract (`Allo.sol`)

At the heart of the Allo Protocol lies the `Allo` contract, a versatile and feature-rich smart contract that enables efficient and decentralized fund allocation and distribution. The contract encompasses mechanisms for handling fees, managing treasury, and defining access controls. Its comprehensive design is composed of distinct functions, variables, modifiers, and events that collaboratively enable a robust fund management framework.

## Key Functionality and Interactions

### Profile Creation and Management:

The Allo Protocol commences with the creation and management of profiles through the `Registry` contract. Users can create profiles, each uniquely identified by a profile ID. Profile metadata, attestation addresses, and members can be customized during creation. The `Registry` contract ensures that only authorized users can manipulate profiles by verifying ownership.

### Secure External Interactions:

The `Anchor` contract bridges the gap between profile owners and external addresses. It provides a secure gateway for profile owners to execute calls to external contracts. Profile owners can specify the amount of native tokens and data to be sent along with the call. The `Anchor` contract incorporates the `Registry` contract to validate the ownership of the profile, assuring that only legitimate owners can access its functionalities.

### Advanced Fund Allocation and Distribution:

The crux of the protocol's functionality resides within the `Allo` contract, which enables decentralized and automated fund management. Pools are created and managed within this contract, each with customizable strategies for fund allocation and distribution. Users can create pools, define parameters, and set strategies, while administrators and managers control the actual allocation and distribution of funds.

### Fee Handling and Treasury Management:

The `Allo` contract incorporates a comprehensive fee management system. It allows the contract owner to set and update fee parameters, control treasury addresses, and recover funds. This fee structure ensures the protocol's sustainability and adaptability. The treasury management mechanism enhances the contract's robustness by enabling controlled fund recovery.

## Roles and Actors

The Allo Protocol delegates distinct roles to participants to foster efficient governance:

* **Profile Owners:** Users who create profiles using the `Registry` contract. These profiles are central to protocol interactions, offering a unique identity for users and enabling secure external calls through the `Anchor` contract.
    
* **Protocol Governance (`AlloTimelockController` + `AlloMultisigWallet`):** On the governance branches, the Allo Owner is the timelock, and the only proposer/executor is the M-of-N multisig. Critical actions require multiple signatures plus a 48h on-chain delay.
  
* **Profile Member:** Members of a Registry profile have specific access rights as defined by the profile's owner.
    
* **Pool Creator** A user who can create new pools using custom or cloneable strategies. They can specify metadata, strategy addresses, managers, and other parameters during pool creation.
    
* **Pool Administrator** Users with administrative control over specific pools. They can manage pool managers, enabling effective pool governance.
    
* **Pool Manager** Users who manage funds within specific pools. They can allocate and distribute funds according to the pool's strategy.
    

## Conclusion

The Allo Protocol is a technologically advanced framework for decentralized fund allocation and distribution. By employing the `Registry`, `Anchor`, and `Allo` contracts in tandem, the protocol establishes an ecosystem where users can securely manage their funds, define strategies, and participate in a DeFi ecosystem that embodies transparency and user-centric governance.

## User Flows

### Allo Contract
    
   * **Functionality:** The `Allo` contract is the central component that manages the creation and operation of pools, strategies, and fund allocation within the Allo ecosystem. It provides functions for creating pools, funding them, allocating funds to recipients, and managing strategies.
   * **Interactions:**
        * The `Allo` contract interacts with the `Registry` contract to manage profiles of users and pool managers. It checks whether an address is authorized to create pools or act as a manager.
        * The `Allo` contract interacts with individual pool strategies (such as contracts that inherit from `BaseStrategy`) to perform allocation and distribution of funds based on specific strategies.
        * It interacts with the `Anchor` contract to execute arbitrary calls to target addresses based on certain conditions.
   * **User Flows:**
        * Users create pools using various strategies, either by providing custom strategies or cloning existing ones.
        * Pools are funded, and the allocated funds are distributed among recipients based on strategy-specific logic.
        * Users can perform batch operations to register and allocate funds to multiple recipients simultaneously.
        * The contract manages the ownership and roles of pool managers and administrators.
        * The contract owner can manage parameters like fee percentages, base fees, and approved strategies.
        * Users can recover funds from the contract.
### Registry Contract
    
   * **Functionality:** The `Registry` contract manages user profiles and their associated permissions in the Allo ecosystem. It defines user profiles, pool managers, and administrators.
   * **Interactions:**
        * The `Registry` contract interacts with the `Allo` contract to validate whether a user or address has the required permissions to create pools or manage them.
   * **User Flows:**
        * Users can create profiles and associate them with addresses to establish roles and permissions.
        * Profiles can define permissions for creating pools, managing pools, and other related tasks.
        * Profiles can have multiple addresses associated with them, allowing for collaboration among users.
        * The `Allo` contract checks with the `Registry` to verify whether a user has the required permissions to perform specific actions.
### Anchor Contract
   * **Functionality:** The `Anchor` contract allows the execution of arbitrary calls to target addresses based on specific conditions.
   * **Interactions:**
        * The `Anchor` contract interacts with the `Allo` contract, allowing authorized users (like pool managers) to initiate calls to external addresses.
   * **User Flows:**
        * Authorized users, such as pool managers, can initiate calls to external target addresses using the `execute` function.
        * The calls can include sending native tokens along with the data to the target address.
        * These calls can be triggered as part of certain conditions or events within the Allo ecosystem.
        * This contract facilitates integration with external systems and smart contracts by allowing dynamic actions based on predefined conditions.

### Overall Interaction

1. Users create profiles in the `Registry` contract and associate their addresses with specific roles and permissions.
2. Users, identified by their addresses and associated profiles, interact with the `Allo` contract to create pools, allocate funds, and manage pools.
3. The `Allo` contract checks user profiles with the `Registry` to ensure that only authorized users perform certain actions.
4. Strategies (inherited from `BaseStrategy`) within the `Allo` contract handle allocation, distribution, and management of funds based on specific logic.
5. The `Anchor` contract allows for dynamic execution of arbitrary calls based on predefined conditions, often triggered by events in the `Allo` ecosystem.
6. Together, these contracts create an ecosystem where users can manage and allocate funds according to various strategies while adhering to predefined permissions and conditions.
