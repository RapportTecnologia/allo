---
layout: page
title: "História do ALLO"
subtitle: "Da Gitcoin à disciplina de Reuso de Software na UFC Quixadá"
---

## Origem: Allo Protocol V2

O [Allo Protocol V2](https://github.com/allo-protocol/allo-v2) é um protocolo open-source desenvolvido pela **Gitcoin** para alocação e distribuição descentralizada de capital na rede Ethereum. Ele foi projetado para dar suporte a mecanismos como *quadratic funding*, *direct grants* e outras estratégias de financiamento coletivo, sendo a base do [Grants Stack](https://www.gitcoin.co/grants-stack).

A arquitetura original é composta por três contratos principais:

| Contrato | Função |
|---|---|
| `Registry.sol` | Registro de perfis e identidade on-chain |
| `Anchor.sol` | Enclave isolado para execução segura de chamadas externas |
| `Allo.sol` | Criação e gestão de pools, alocação e distribuição de fundos |
| `BaseStrategy.sol` | Contrato abstrato que define estratégias de distribuição |

> **Fonte original:** [github.com/allo-protocol/allo-v2](https://github.com/allo-protocol/allo-v2) — licenciado sob AGPL-3.0-only.

## O trabalho acadêmico

Este repositório (`ALLO-v2`) é um **fork acadêmico** produzido como o **Trabalho 1** da disciplina **QXD0068 — Reuso de Software**, do curso de Engenharia de Software da **Universidade Federal do Ceará — Campus Quixadá (UFC Quixadá)**.

- **Disciplina:** QXD0068 — Reuso de Software
- **Integrante:** Francisco Josias da Silva Batista
- **Professor:** Prof. Francisco Victor da Silva Pinheiro
- **Data de entrega:** 14/10/2026

O objetivo foi aplicar **padrões de projeto estruturais e comportamentais do GoF (Gang of Four)** em contratos inteligentes escritos em Solidity, refatorando o sistema legado do Allo Protocol para reduzir acoplamento, melhorar a coesão das estruturas de dados e facilitar a manutenção.

## Padrões aplicados

Os padrões de projeto foram introduzidos na camada core do protocolo:

1. **Facade** — `AlloStarterFacade.sol`  
   Simplifica a interação do usuário com `Registry` e `Allo`, criando uma campanha em poucas chamadas sem transferir a propriedade do perfil para a fachada.

2. **Strategy** — `IFeeStrategy.sol` / `FlatFeeStrategy.sol`  
   Desacopla o cálculo de taxas do contrato `Allo`, permitindo trocar o algoritmo de fee sem alterar o core.

3. **Factory Method** — `StrategyFactory.sol` / `IStrategyFactory.sol`  
   Delega a instanciação de novas estratégias para uma fábrica dedicada, isolando a lógica de clonagem.

4. **State** — `BaseStrategy.sol` / `DirectGrantsLite.sol`  
   Gerencia os estados das pools e alocações (registro, alocação, distribuição) de forma explícita e testável.

## Evolução para governança segura

A camada de governança on-chain foi incorporada **após a análise do trabalho realizado pelo Engenheiro de Software Francisco Josias da Silva Batista**. A proposta surgiu da **análise de auditoria conduzida por Carlos Delfino** através do seu *harness* de agentes de auditoria em smart contracts na IDE **Devin**, com o objetivo de aumentar a segurança operacional do protocolo e garantir que decisões críticas fossem tomadas por múltiplas carteiras, em vez de um único controlador.

Essa evolução introduziu:

- `AlloTimelockController` — timelock com delay mínimo de 48 horas.
- `AlloMultisigWallet` — carteira M-of-N que atua como única propositora/executora do timelock.
- Scripts de governança para upgrade atômico (`upgradeAlloViaGovernance.ts`) e operações administrativas.

Essa camada garante que mudanças críticas no protocolo exijam múltiplas assinaturas e um período de espera on-chain, reduzindo riscos de ações unilaterais.

## Revisão e auditoria independente

O trabalho foi revisado de forma independente por **Carlos Delfino**, aplicando critérios de auditoria desenvolvidos em seus estudos sobre **Smart Contracts com Inteligência Artificial Generativa** e o uso de **agentes de codificação com a ferramenta Devin**.

Durante a revisão, todo o código foi analisado e auditado, resultando em ajustes que aumentaram a segurança e a usabilidade dos contratos. Os pontos tratados incluíram:

- Correção do modelo de permissões da `AlloStarterFacade`, garantindo que o usuário final permaneça como owner do perfil e pagador dos ativos.
- Adição de validações defensivas em estratégias de fee e factory.
- Garantia de upgrade atômico com `initializeGoFPatterns()` via `upgradeAndCall`.
- Estruturação de scripts de governança com timelock de 48 horas e multisig M-of-N.
- Documentação de papéis, checklists de deploy e runbook de resposta a incidentes.

A revisão respeitou o modelo proposto pelo Engenheiro **Francisco Josias da Silva Batista**, preservando a identidade acadêmica do trabalho enquanto elevava o rigor de segurança e operação.

## Materiais complementares

No repositório você encontra:

- [`Relatorio_Refatoracao_Allo.pdf`](/Relatorio_Refatoracao_Allo.pdf) — diagnóstico do sistema legado, análises "Antes vs. Depois", diagramas de classe e fluxo.
- [`Apresentacao_Allo_Protocol.pdf`](/Apresentacao_Allo_Protocol.pdf) — resumo executivo dos problemas e padrões aplicados.
- [`README.md`](/README.md) — instruções técnicas e visão geral dos contratos.

## Reconhecimentos

- [Gitcoin](https://www.gitcoin.co/) pela criação e manutenção do Allo Protocol.
- [Allo Protocol Docs](https://docs.allo.gitcoin.co/) pela documentação de referência.
- Prof. Francisco Victor da Silva Pinheiro pela orientação na disciplina.
- Eng. **Francisco Josias da Silva Batista** pela análise, refatoração e documentação deste fork acadêmico.
- **Carlos Delfino**, de forma independente, pela análise dos contratos com auxílio de agentes de IA para auditoria de smart contracts, identificando melhorias que foram implementadas neste fork.
