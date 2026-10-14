---
layout: home
show_title: false
hero:
  title: "ALLO Protocol"
  subtitle: "Resumo do fork acadêmico com padrões de projeto GoF, multisig e timelock on-chain."
  buttons:
    - label: "Documentação completa"
      url: "https://rapport.tec.br/allo-docs/"
      primary: true
    - label: "Conheça a história"
      url: "/historia/"
      primary: false
---

<section class="section">
  <p class="eyebrow">CONHEÇA, EXPLORE, APROFUNDE</p>
  <h2 class="section-title">O que é o ALLO?</h2>
  <p class="section-lead">
    O <strong>Allo Protocol</strong> é um conjunto de smart contracts da <a href="https://www.gitcoin.co/" target="_blank" rel="noopener">Gitcoin</a> para alocação e distribuição descentralizada de fundos na Ethereum. Ele oferece registro de perfis (Registry), execução segura de chamadas externas (Anchor) e gestão de pools com estratégias customizáveis (Allo).
  </p>
  <p>
    Esta página é o <strong>ponto de entrada</strong> do fork acadêmico <strong>ALLO-v2</strong>, produzido como trabalho da disciplina <em>QXD0068 — Reuso de Software</em> (UFC Quixadá). Aqui você encontra um resumo da história, da arquitetura, da governança DAO e dos principais recursos de segurança.
  </p>
  <p>
    <strong>Quer se aprofundar no protocolo?</strong> A documentação técnica completa — com referências detalhadas de contratos, fluxos e guias — está disponível em <a href="https://rapport.tec.br/allo-docs/" target="_blank" rel="noopener">rapport.tec.br/allo-docs</a>.
  </p>
</section>

<section class="section">
  <p class="eyebrow">RESUMO DOS TEMAS</p>
  <h2 class="section-title">Por onde você quer começar?</h2>
  <p class="section-lead">Navegue pelos resumos ou vá direto para a documentação completa.</p>
  <div class="card-grid">
    <div class="card">
      <h3 class="text-brand">📜 História</h3>
      <p>Origem no Allo Protocol V2, motivação acadêmica, revisão independente e evolução para uma arquitetura com padrões de projeto.</p>
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
  <p class="eyebrow">DOCUMENTAÇÃO COMPLETA</p>
  <h2 class="section-title">Aprofunde-se no Allo Protocol</h2>
  <p>
    Esta página oferece uma visão geral. Para a documentação técnica completa — incluindo referências de API dos contratos, fluxos detalhados, guias de deploy e upgrade — acesse:
  </p>
  <p class="text-center">
    <a class="btn-primary" href="https://rapport.tec.br/allo-docs/" target="_blank" rel="noopener">Abrir documentação completa ↗</a>
  </p>
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
  <p>O repositório do fork acadêmico está no GitHub da Rapport Tecnologia.</p>
  <a class="btn-primary" href="https://github.com/RapportTecnologia/allo" target="_blank" rel="noopener">Abrir repositório no GitHub ↗</a>
</div>
