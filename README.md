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
- **Volume:** 8.000 leads (+160 duplicados propositais, 8.160 registros), 905 clientes fechados, 198 cancelamentos
- **Conversão geral:** 11,3% (clientes fechados ÷ leads únicos)
- **Tabelas geradas:** assessores (12), leads (8.160), histórico de etapas (28.256), clientes (905), receita mensal (9.808), cancelamentos (198)
- **Fonte:** dados sintéticos com regras de negócio realistas e inconsistências
  controladas (duplicidades, grafias diferentes, datas fora de ordem)

## Regras de negócio da simulação

| Origem | Leads | Conversão alvo | Ciclo médio de venda |
|---|---|---|---|
| Indicação | 1.400 | 28% | ~20 dias |
| Evento | 1.600 | 13% | ~30 dias |
| Instagram | 2.600 | 7,5% | ~35 dias |
| Anúncio | 2.400 | 4% | ~45 dias |

- Três planos de mensalidade: Básico (R$ 150), Intermediário (R$ 350) e Premium (R$ 800)
- Churn maior nos 3 primeiros meses de cliente e maior em clientes vindos de anúncio
- Sazonalidade: mais leads no início do ano
- Cada assessor tem uma habilidade de conversão diferente

## Ferramentas
PostgreSQL · Python (pandas, SQLAlchemy, statsmodels) · Power BI

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

## Estrutura do repositório

```
projeto2-funil-comercial/
├── data/        # CSVs gerados (dados sintéticos)
├── sql/         # schema, limpeza e views analíticas
├── python/      # geração de dados, carga e análise
├── powerbi/     # dashboard (.pbix) e prints
└── README.md
```

## Como reproduzir

1. Criar o ambiente e instalar as dependências: `pip install pandas numpy faker sqlalchemy psycopg2-binary python-dotenv`
2. Gerar os dados: `python python/gerar_dados.py`
3. Criar o banco `funil_comercial` no PostgreSQL e configurar o arquivo `.env`
4. Carregar os dados brutos: `python python/carga.py`
5. Executar os scripts da pasta `sql/` em ordem

## Status

- [x] Escopo e perguntas de negócio
- [x] Geração de dados sintéticos
- [X] Carga no PostgreSQL (schema `raw`)
- [X] Limpeza e modelagem em SQL
- [ ] Análise em Python (coortes, testes estatísticos)
- [ ] Dashboard no Power BI
- [ ] Principais insights