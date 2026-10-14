---
layout: home
show_title: false
hero:
  title: "ALLO Protocol"
  subtitle: "Documentação da versão acadêmica refatorada com padrões de projeto GoF, multisig e timelock on-chain."
  buttons:
    - label: "Conheça a história"
      url: "/historia/"
      primary: true
    - label: "Como usar"
      url: "/uso/"
      primary: false
---

<section class="section">
  <p class="eyebrow">CONHEÇA, EXPLORE, CONSTRUA</p>
  <h2 class="section-title">O que é o ALLO?</h2>
  <p class="section-lead">
    O <strong>Allo Protocol</strong> é um conjunto de smart contracts da <a href="https://www.gitcoin.co/" target="_blank" rel="noopener">Gitcoin</a> para alocação e distribuição descentralizada de fundos na Ethereum. Ele oferece registro de perfis (Registry), execução segura de chamadas externas (Anchor) e gestão de pools com estratégias customizáveis (Allo).
  </p>
  <p>
    Esta documentação descreve o <strong>fork acadêmico ALLO-v2</strong> produzido como trabalho da disciplina <em>QXD0068 — Reuso de Software</em> (UFC Quixadá), que aplica padrões GoF para reduzir acoplamento, aumentar a coesão e introduzir uma camada de governança segura. O trabalho foi revisado de forma independente por <strong>Carlos Delfino</strong>, aplicando critérios de auditoria desenvolvidos em seus estudos sobre <em>Smart Contracts com Inteligência Artificial Generativa</em> usando agentes de codificação com a ferramenta <strong>Devin</strong>. Todo o código foi revisado e auditado, produzindo ajustes que aumentaram a segurança e a usabilidade dos contratos conforme o modelo proposto pelo Engenheiro <strong>Francisco Josias da Silva Batista</strong>.
  </p>
</section>

<section class="section">
  <p class="eyebrow">SEU PRÓXIMO PASSO</p>
  <h2 class="section-title">Por onde você quer começar?</h2>
  <p class="section-lead">Do primeiro contato ao código: encontre seu caminho no ALLO.</p>
  <div class="card-grid">
    <div class="card">
      <h3 class="text-brand">📜 História</h3>
      <p>Origem no Allo Protocol V2, motivação acadêmica e evolução para uma arquitetura com padrões de projeto.</p>
      <a href="{{ "/historia/" | relative_url }}" class="btn-secondary">Ler história</a>
    </div>
    <div class="card">
      <h3 class="text-brand">🏛️ Governança DAO</h3>
      <p>Entenda o funcionamento do timelock de 48 horas, da multisig M-of-N e do ciclo de propostas.</p>
      <a href="{{ "/dao/" | relative_url }}" class="btn-secondary">Ver DAO</a>
    </div>
    <div class="card">
      <h3 class="text-brand">🛠️ Como Usar</h3>
      <p>Instalação, compilação, testes, deploy dos contratos core e criação de pools.</p>
      <a href="{{ "/uso/" | relative_url }}" class="btn-secondary">Ver instruções</a>
    </div>
    <div class="card">
      <h3 class="text-brand">🤝 Contribuir</h3>
      <p>Guia de fork, fluxo de trabalho, padrões de código e checklist de segurança para pull requests.</p>
      <a href="{{ "/contribuir/" | relative_url }}" class="btn-secondary">Quero contribuir</a>
    </div>
    <div class="card">
      <h3 class="text-brand">◈ Arquitetura</h3>
      <p>Conheça os contratos, suas conexões e os padrões de projeto que organizam o protocolo.</p>
      <a href="{{ "/arquitetura/" | relative_url }}" class="btn-secondary">Explorar arquitetura</a>
    </div>
    <div class="card">
      <h3 class="text-brand">◎ Segurança</h3>
      <p>Explore as proteções, os controles de acesso e as práticas de segurança do projeto.</p>
      <a href="{{ "/seguranca/" | relative_url }}" class="btn-secondary">Entender as proteções</a>
    </div>
  </div>
</section>

<section class="section">
  <p class="eyebrow">POR DENTRO DO PROTOCOLO</p>
  <h2 class="section-title">Uma base para construir juntos</h2>
  <ul class="technical-list">
    <li><strong>Facade:</strong> <code>AlloStarterFacade.sol</code> simplifica a criação de campanhas sem quebrar o modelo de permissões do Registry.</li>
    <li><strong>Strategy:</strong> cálculo de taxas extraído para a interface <code>IFeeStrategy</code>, permitindo trocar algoritmos sem alterar o Allo.</li>
    <li><strong>Factory Method:</strong> <code>StrategyFactory.sol</code> centraliza a clonagem de estratégias.</li>
    <li><strong>State:</strong> estados de pool e alocação modelados em <code>BaseStrategy.sol</code> e estratégias derivadas.</li>
    <li><strong>Governança:</strong> <code>AlloTimelockController</code> com delay mínimo de 48 horas e <code>AlloMultisigWallet</code> M-of-N.</li>
  </ul>
</section>

<div class="cta-strip">
  <h2>Pronto para mergulhar no código?</h2>
  <p>O repositório original está no GitHub da Gitcoin; o fork acadêmico mantém a mesma base com as refatorações documentadas aqui.</p>
  <a class="btn-primary" href="https://github.com/RapportTecnologia/allo" target="_blank" rel="noopener">Abrir repositório no GitHub ↗</a>
</div>
