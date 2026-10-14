# AlloStarterFacade.sol

The `AlloStarterFacade` contract is a simplified entry point to the Allo Protocol. It creates and funds an Allo pool for an existing Registry profile while preserving the end user's on-chain identity and privileges (SEC-002 fix).

## Table of Contents

- [AlloStarterFacade.sol](#allostarterfacadesol)
- [Security Model](#security-model)
- [Sequence Diagram](#sequence-diagram)
- [Smart Contract Overview](#smart-contract-overview)
  - [Storage Variables](#storage-variables)
  - [Functions](#functions)
- [User Flows](#user-flows)

## Security Model

`Registry.createProfile` only accepts an initial member list when `msg.sender == _owner`. A facade contract therefore **cannot** create a profile on behalf of a user and add itself as member in a single call — that was the root cause of SEC-002. The corrected flow is two-phase:

1. The **user** calls `Registry.createProfile(nonce, name, metadata, user, [facade, ...])` directly, listing the facade as a member.
2. The **user** calls `AlloStarterFacade.initializeCampaign(...)`, which creates and optionally funds the pool.

Resulting privileges:

- The user remains the **profile owner** and receives the **pool manager** role.
- The **pool admin** role stays on the facade — an immutable, non-upgradeable contract — and is only exercised through `addPoolManager` / `removePoolManager`, which revert unless `msg.sender` owns the profile that owns the pool.
- ETH is forwarded 1:1 via `msg.value`. ERC-20 funding pulls exactly `_amount` from the caller and resets the Allo allowance to zero after each call.
- The profile owner can remove the facade from profile members at any time via `Registry.removeMembers`, blocking future pool creation through the facade.

## Sequence Diagram

```text
sequenceDiagram
    participant User
    participant Registry
    participant Facade as AlloStarterFacade
    participant Allo

    User->>Registry: createProfile(owner=User, members=[Facade])
    Registry-->>User: profileId
    User->>Facade: initializeCampaign(profileId, ...)
    Facade->>Allo: createPool(profileId, ...)
    Allo-->>Facade: poolId
    Facade->>Allo: grantRole(POOL_MANAGER_ROLE, User)
    Facade-->>User: poolId
```

## Smart Contract Overview

- **Purpose:** Reduce coupling between clients and the Allo subsystems without breaking the authorization model.
- **Solidity Version:** 0.8.19
- **Pattern:** Facade (GoF Structural) as a policy-bound operator contract.

### Storage Variables

1. `registry` (IRegistry, immutable): Registry contract used for profile membership and ownership checks.
2. `allo` (IAllo, immutable): Allo core contract used to create, fund and administer pools.

### Functions

1. **initializeCampaign**: Creates a pool for a profile that already lists the facade as member. Pulls ERC-20 from the caller or forwards ETH; grants the caller the pool manager role.
2. **addPoolManager / removePoolManager**: Admin operations proxied to Allo, gated by profile ownership.
3. **fundPool**: Convenience funding wrapper with the same ETH/ERC-20 handling.

## User Flows

### Campaign Initialization

1. The user creates a Registry profile directly, including `AlloStarterFacade` in the members array.
2. For ERC-20 pools, the user approves the facade for the funding amount.
3. The user calls `initializeCampaign`, receiving a `poolId` and the pool manager role in a single transaction.
4. Later, the user manages managers through `addPoolManager` / `removePoolManager`, funds via `fundPool`, or interacts with `Allo` directly for manager-level operations.
