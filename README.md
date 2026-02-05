Financial BI — Contabilidade Gerencial (SQL-first)

Projeto de Business Intelligence end-to-end, focado em Contabilidade Gerencial, desenvolvido com ênfase em SQL, modelagem dimensional, métricas financeiras confiáveis e dashboards interativos.  
O objetivo é simular a atuação de um time de dados em ambiente corporativo, fornecendo suporte à tomada de decisão executiva por meio de análises de DRE, custos, margens, fluxo de caixa e orçamento.

---

> Objetivo

Construir um sistema analítico capaz de:

- Consolidar dados financeiros e orçamentários em um modelo analítico confiável
- Padronizar métricas gerenciais (DRE, margem, caixa, desvios)
- Permitir análises de tendência, comparativos e exceções
- Suportar decisões estratégicas, táticas e operacionais

Este projeto tem foco em análise gerencial, não em escrituração contábil legal (ERP).

---

> Perguntas de Negócio

- Qual é o resultado operacional (DRE gerencial) do período?
- Como evoluíram receitas, despesas e margens ao longo do tempo?
- Quais produtos, centros de custo ou unidades apresentam melhor ou pior performance?
- Onde estão os principais desvios entre orçado e realizado?
- Qual é a situação de caixa atual e projetada?
- Quais custos ou despesas apresentam comportamento atípico?

---

> Arquitetura (Visão Geral)

O sistema foi estruturado seguindo boas práticas de BI e Analytics, com separação clara entre ingestão, transformação, semântica e visualização.
Fonte → Raw / Bronze → Staging / Silver → Marts / Gold → Métricas → Dashboards


 Camadas
- Fonte: dados financeiros e orçamentários
- Raw / Bronze: dados brutos, preservados para rastreabilidade
- Staging / Silver: padronização, qualidade e regras básicas
- Marts / Gold: modelo dimensional (fatos e dimensões)
- Métricas: camada semântica com regras de negócio consolidadas
- Dashboards: consumo analítico por diferentes públicos

Detalhes completos em `docs/architecture.md`

---

> Modelo de Dados

O modelo segue abordagem dimensional (Star Schema).

 Fatos (exemplos)
- Lançamentos financeiros (regime de competência)
- Movimentações de caixa (pagamentos e recebimentos)
- Orçamento

 Dimensões (exemplos)
- Tempo (competência e caixa)
- Conta gerencial
- Centro de custo
- Produto / Linha
- Unidade / Projeto
- Cenário (realizado, orçado)

Detalhes em `docs/data_model.md`

---

> Métricas Gerenciais

As métricas são definidas em uma camada semântica única, garantindo consistência entre todos os dashboards.

Exemplos:
- Receita Líquida
- Custos e Despesas
- Margem de Contribuição
- Resultado Operacional (DRE)
- Fluxo de Caixa
- Orçado vs Realizado
- Desvios (% e valor)
- Acumulados (MTD / YTD)
- Comparativos (MoM / YoY)

Definições completas em `docs/metrics.md`

---

> Dashboards

Os dashboards são organizados por nível de decisão:

 Dashboard Executivo
- DRE gerencial resumida
- KPIs financeiros
- Tendências e alertas

 Dashboard Gestão
- Análise de custos e margens
- Orçado vs realizado
- Desvios por produto, centro de custo e unidade

 Dashboard Operacional
- Fluxo de caixa detalhado
- Lançamentos e exceções
- Drill-down até o nível transacional

📄 Detalhes em `docs/dashboards.md`

---

Qualidade e Confiabilidade dos Dados

- Regras de integridade (PK, FK, unicidade)
- Validação de valores e datas
- Reconciliação de totais por período
- Separação explícita entre competência e caixa

---

Roadmap

- v0.1 — Fundação
  - Modelo dimensional
  - Métricas base
  - Camada semântica inicial

- v0.2 — Performance & Confiabilidade
  - Agregações e otimizações
  - Validações e reconciliações
  - Análises de tendências e desvios

- v1.0 — Dashboards & Storytelling
  - Dashboards finais
  - Documentação completa
  - Projeto consolidado para portfólio

---

Estrutura do Repositório

├─ sql/
│ ├─ 01_staging/
│ ├─ 02_marts/
│ │ ├─ facts/
│ │ ├─ dimensions/
│ │ └─ aggregates/
│ └─ 03_metrics/
├─ docs/
│ ├─ architecture.md
│ ├─ data_model.md
│ ├─ metrics.md
│ └─ dashboards.md
└─ ops/
└─ runbook.md


---

Observação Final

Este projeto representa uma camada analítica corporativa, onde:
- Regras de negócio ficam no banco (SQL)
- Dashboards apenas consomem métricas consolidadas
- Decisões são baseadas em dados confiáveis e auditáveis

---

Autor: Sérgio Guerrato
