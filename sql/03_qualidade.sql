-- 1) Duplicados removidos (esperado: 160)
SELECT (SELECT COUNT(*) FROM raw.leads)  AS leads_raw,
       (SELECT COUNT(*) FROM core.leads) AS leads_core,
       (SELECT COUNT(*) FROM raw.leads) - (SELECT COUNT(*) FROM core.leads) AS removidos;

-- 2) Origens padronizadas (esperado: 1400 / 1600 / 2600 / 2400)
SELECT origem, COUNT(*) AS leads
FROM core.leads
GROUP BY origem
ORDER BY leads DESC;

-- 3) Datas fora de ordem sinalizadas, por etapa
SELECT etapa, COUNT(*) FILTER (WHERE data_inconsistente) AS inconsistentes, COUNT(*) AS total
FROM core.historico_etapas
GROUP BY etapa
ORDER BY inconsistentes DESC;

-- 4) Regras de consistência (esperado: tudo 0)
SELECT 'receita antes do fechamento' AS checagem, COUNT(*) AS problemas
FROM core.receita_mensal r
JOIN core.clientes c USING (cliente_id)
WHERE r.mes < DATE_TRUNC('month', c.data_fechamento)
UNION ALL
SELECT 'cancelamento antes do fechamento', COUNT(*)
FROM core.cancelamentos x
JOIN core.clientes c USING (cliente_id)
WHERE x.data_cancelamento < c.data_fechamento
UNION ALL
SELECT 'receita depois do cancelamento', COUNT(*)
FROM core.receita_mensal r
JOIN core.cancelamentos x USING (cliente_id)
WHERE r.mes >= DATE_TRUNC('month', x.data_cancelamento);

-- 5) Conversão geral (esperado: ~11,3%)
SELECT ROUND(100.0 * (SELECT COUNT(*) FROM core.clientes) / COUNT(*), 1) AS conversao_pct
FROM core.leads;