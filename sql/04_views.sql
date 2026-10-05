CREATE SCHEMA IF NOT EXISTS analytics;

-- P1: Funil etapa a etapa
CREATE OR REPLACE VIEW analytics.vw_funil_etapas AS
WITH ordem(etapa, ordem) AS (
    VALUES ('lead', 1), ('contato', 2), ('reuniao', 3), ('proposta', 4), ('fechado', 5)
),
alcance AS (
    SELECT etapa, COUNT(DISTINCT lead_id) AS leads
    FROM core.historico_etapas
    GROUP BY etapa
)
SELECT o.ordem, o.etapa, a.leads,
       ROUND(100.0 * a.leads / LAG(a.leads) OVER (ORDER BY o.ordem), 1)           AS conv_etapa_anterior_pct,
       ROUND(100.0 * a.leads / FIRST_VALUE(a.leads) OVER (ORDER BY o.ordem), 1)   AS conv_acumulada_pct
FROM ordem o
JOIN alcance a USING (etapa);

-- P1: Tempo entre etapas (ignora datas marcadas como inconsistentes)
CREATE OR REPLACE VIEW analytics.vw_tempo_etapas AS
WITH h AS (
    SELECT lead_id, etapa, data_entrada_etapa, data_inconsistente,
           CASE etapa WHEN 'lead' THEN 1 WHEN 'contato' THEN 2 WHEN 'reuniao' THEN 3
                      WHEN 'proposta' THEN 4 WHEN 'fechado' THEN 5 END AS ordem
    FROM core.historico_etapas
    WHERE etapa <> 'perdido'
),
t AS (
    SELECT *,
           LAG(etapa)              OVER w AS etapa_anterior,
           LAG(data_inconsistente) OVER w AS inconsistente_anterior,
           data_entrada_etapa - LAG(data_entrada_etapa) OVER w AS dias
    FROM h
    WINDOW w AS (PARTITION BY lead_id ORDER BY ordem)
)
SELECT ordem,
       etapa_anterior || ' > ' || etapa AS transicao,
       COUNT(*)                         AS casos,
       ROUND(AVG(dias), 1)              AS dias_medios,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY dias))::numeric, 1) AS dias_mediana
FROM t
WHERE etapa_anterior IS NOT NULL
  AND NOT data_inconsistente
  AND NOT inconsistente_anterior
GROUP BY ordem, etapa_anterior, etapa;

-- P2: Origem (conversão, ciclo de venda e ticket)
CREATE OR REPLACE VIEW analytics.vw_origem AS
SELECT l.origem,
       COUNT(*)                                                   AS leads,
       COUNT(c.cliente_id)                                        AS clientes,
       ROUND(100.0 * COUNT(c.cliente_id) / COUNT(*), 1)           AS conversao_pct,
       ROUND(AVG(c.data_fechamento - l.data_criacao), 1)          AS ciclo_medio_dias,
       ROUND(AVG(c.mensalidade), 2)                               AS mensalidade_media
FROM core.leads l
LEFT JOIN core.clientes c ON c.lead_id = l.lead_id
GROUP BY l.origem;

-- P3: Assessores e ranking por equipe
CREATE OR REPLACE VIEW analytics.vw_assessores AS
WITH receita_cliente AS (
    SELECT cliente_id, SUM(valor) AS receita_total
    FROM core.receita_mensal
    GROUP BY cliente_id
)
SELECT a.assessor_id, a.nome, a.equipe,
       COUNT(DISTINCT l.lead_id)    AS leads,
       COUNT(DISTINCT c.cliente_id) AS clientes,
       ROUND(100.0 * COUNT(DISTINCT c.cliente_id) / NULLIF(COUNT(DISTINCT l.lead_id), 0), 1) AS conversao_pct,
       COALESCE(SUM(rc.receita_total), 0) AS receita_gerada,
       RANK() OVER (PARTITION BY a.equipe
                    ORDER BY COUNT(DISTINCT c.cliente_id)::numeric
                             / NULLIF(COUNT(DISTINCT l.lead_id), 0) DESC) AS rank_conversao_equipe
FROM core.assessores a
LEFT JOIN core.leads l          ON l.assessor_id = a.assessor_id
LEFT JOIN core.clientes c       ON c.lead_id = l.lead_id
LEFT JOIN receita_cliente rc    ON rc.cliente_id = c.cliente_id
GROUP BY a.assessor_id, a.nome, a.equipe;

-- P4: MRR e churn mensal
-- Cliente ativo no mês = tem linha em receita_mensal. Quem cancela no mês M
-- pagou até M-1, por isso o churn usa os ativos do mês anterior como base.
CREATE OR REPLACE VIEW analytics.vw_mrr_mensal AS
WITH meses AS (
    SELECT generate_series(DATE '2024-01-01', DATE '2025-12-01', INTERVAL '1 month')::date AS mes
),
rec AS (
    SELECT mes, SUM(valor) AS mrr, COUNT(*) AS clientes_ativos
    FROM core.receita_mensal
    GROUP BY mes
),
novos AS (
    SELECT DATE_TRUNC('month', data_fechamento)::date AS mes, COUNT(*) AS novos
    FROM core.clientes
    GROUP BY 1
),
canc AS (
    SELECT DATE_TRUNC('month', data_cancelamento)::date AS mes, COUNT(*) AS cancelados
    FROM core.cancelamentos
    GROUP BY 1
)
SELECT m.mes,
       COALESCE(r.mrr, 0)             AS mrr,
       COALESCE(r.clientes_ativos, 0) AS clientes_ativos,
       COALESCE(n.novos, 0)           AS novos_clientes,
       COALESCE(c.cancelados, 0)      AS cancelados,
       COALESCE(LAG(r.clientes_ativos) OVER (ORDER BY m.mes), 0) AS ativos_inicio_mes,
       ROUND(100.0 * COALESCE(c.cancelados, 0)
             / NULLIF(LAG(r.clientes_ativos) OVER (ORDER BY m.mes), 0), 2) AS churn_pct
FROM meses m
LEFT JOIN rec r   USING (mes)
LEFT JOIN novos n USING (mes)
LEFT JOIN canc c  USING (mes);

-- P5: Coorte de retenção
CREATE OR REPLACE VIEW analytics.vw_coorte_retencao AS
WITH coorte AS (
    SELECT cliente_id, DATE_TRUNC('month', data_fechamento)::date AS mes_coorte
    FROM core.clientes
),
tamanho AS (
    SELECT mes_coorte, COUNT(*) AS clientes_coorte
    FROM coorte
    GROUP BY mes_coorte
),
atividade AS (
    SELECT c.mes_coorte,
           ((EXTRACT(YEAR FROM r.mes) * 12 + EXTRACT(MONTH FROM r.mes))
          - (EXTRACT(YEAR FROM c.mes_coorte) * 12 + EXTRACT(MONTH FROM c.mes_coorte)))::int AS meses_desde_entrada,
           COUNT(*) AS clientes_ativos
    FROM core.receita_mensal r
    JOIN coorte c USING (cliente_id)
    GROUP BY 1, 2
)
SELECT a.mes_coorte, a.meses_desde_entrada, t.clientes_coorte, a.clientes_ativos,
       ROUND(100.0 * a.clientes_ativos / t.clientes_coorte, 1) AS retencao_pct
FROM atividade a
JOIN tamanho t USING (mes_coorte);

-- P5: Permanência por origem e plano
CREATE OR REPLACE VIEW analytics.vw_retencao_origem_plano AS
SELECT l.origem, c.plano,
       COUNT(*)                                          AS clientes,
       COUNT(x.cliente_id)                               AS cancelados,
       ROUND(100.0 * COUNT(x.cliente_id) / COUNT(*), 1)  AS cancelados_pct,
       ROUND(AVG(m.meses_pagos), 1)                      AS meses_pagos_medios
FROM core.clientes c
JOIN core.leads l ON l.lead_id = c.lead_id
LEFT JOIN core.cancelamentos x ON x.cliente_id = c.cliente_id
JOIN (SELECT cliente_id, COUNT(*) AS meses_pagos
      FROM core.receita_mensal GROUP BY cliente_id) m ON m.cliente_id = c.cliente_id
GROUP BY l.origem, c.plano;

-- Base única para o Power BI (um registro por lead)
CREATE OR REPLACE VIEW analytics.vw_leads_detalhe AS
SELECT l.lead_id, l.data_criacao,
       DATE_TRUNC('month', l.data_criacao)::date AS mes_criacao,
       l.origem, l.assessor_id, a.nome AS assessor, a.equipe, l.valor_potencial,
       (c.cliente_id IS NOT NULL)                AS virou_cliente,
       c.cliente_id, c.data_fechamento, c.plano, c.mensalidade,
       (c.data_fechamento - l.data_criacao)      AS ciclo_dias,
       (x.cliente_id IS NOT NULL)                AS cancelou,
       x.data_cancelamento, x.motivo
FROM core.leads l
JOIN core.assessores a ON a.assessor_id = l.assessor_id
LEFT JOIN core.clientes c ON c.lead_id = l.lead_id
LEFT JOIN core.cancelamentos x ON x.cliente_id = c.cliente_id;
SELECT * FROM analytics.vw_funil_etapas ORDER BY ordem;
SELECT * FROM analytics.vw_origem ORDER BY conversao_pct DESC;
SELECT * FROM analytics.vw_mrr_mensal ORDER BY mes;
SELECT COUNT(*) FROM analytics.vw_leads_detalhe;