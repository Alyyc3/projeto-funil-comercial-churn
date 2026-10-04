# Funil Comercial e Churn: Análise de uma Assessoria de Investimentos

> Projeto de portfólio com dados **sintéticos** (gerados por script em Python).
> Nenhuma informação real de empresas ou clientes foi utilizada.

## Contexto
Assessoria de investimentos fictícia com 3 equipes e 12 assessores,
que capta clientes por quatro origens: indicação, evento, Instagram e anúncio.

## Problema
A diretoria não sabe quais origens de lead geram clientes que permanecem,
em que etapa o funil trava e quanto da receita recorrente se perde por cancelamento.

## Escopo dos dados
- **Período:** 24 meses (jan/2024 a dez/2025)
- **Volume:** ~8.000 leads, ~900 clientes fechados, ~250 cancelamentos
- **Fonte:** dados sintéticos com regras de negócio realistas e inconsistências
  controladas (duplicidades, grafias diferentes, datas fora de ordem)

## Ferramentas
PostgreSQL · Python (pandas, statsmodels) · Power BI

## Perguntas de negócio

| # | Pergunta | Métrica | Decisão que apoia |
|---|---|---|---|
| 1 | Onde o funil perde mais leads? | Conversão etapa a etapa | Onde melhorar o processo |
| 2 | Qual origem converte mais e mais rápido? | Conversão e dias até fechar, por origem | Onde investir em captação |
| 3 | Quais assessores e equipes performam melhor? | Conversão e MRR gerado | Treinamento e distribuição de leads |
| 4 | Quanto da receita recorrente estamos perdendo? | MRR e churn % mensal | Prioridade de retenção |
| 5 | Clientes de quais origens e planos ficam mais tempo? | Retenção por coorte | Qualidade do lead, não só volume |

## Definições das métricas

- **Conversão por etapa:** leads que chegaram à etapa N+1 ÷ leads que chegaram à etapa N
- **Conversão geral:** clientes fechados ÷ leads criados
- **Ciclo de venda:** data de fechamento − data de criação do lead (em dias)
- **MRR:** soma da receita recorrente dos clientes ativos no mês
- **Churn mensal:** clientes cancelados no mês ÷ clientes ativos no início do mês
- **Retenção da coorte:** % dos clientes de um mês de entrada ainda ativos N meses depois

**Etapas do funil:** lead → contato → reunião → proposta → fechado (com "perdido" possível em qualquer etapa)