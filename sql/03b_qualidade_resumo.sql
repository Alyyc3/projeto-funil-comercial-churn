SELECT 'leads em core (esperado 8000)' AS checagem, COUNT(*)::text AS resultado
FROM core.leads
UNION ALL
SELECT 'duplicados removidos (esperado 160)',
       ((SELECT COUNT(*) FROM raw.leads) - (SELECT COUNT(*) FROM core.leads))::text
UNION ALL
SELECT 'origens distintas (esperado 4)', COUNT(DISTINCT origem)::text FROM core.leads
UNION ALL
SELECT 'clientes (esperado 905)', COUNT(*)::text FROM core.clientes
UNION ALL
SELECT 'datas fora de ordem sinalizadas', COUNT(*)::text
FROM core.historico_etapas WHERE data_inconsistente
UNION ALL
SELECT 'receita antes do fechamento (esperado 0)', COUNT(*)::text
FROM core.receita_mensal r
JOIN core.clientes c USING (cliente_id)
WHERE r.mes < DATE_TRUNC('month', c.data_fechamento)
UNION ALL
SELECT 'cancelamento antes do fechamento (esperado 0)', COUNT(*)::text
FROM core.cancelamentos x
JOIN core.clientes c USING (cliente_id)
WHERE x.data_cancelamento < c.data_fechamento
UNION ALL
SELECT 'receita depois do cancelamento (esperado 0)', COUNT(*)::text
FROM core.receita_mensal r
JOIN core.cancelamentos x USING (cliente_id)
WHERE r.mes >= DATE_TRUNC('month', x.data_cancelamento)
UNION ALL
SELECT 'conversão geral % (esperado 11,3)',
       ROUND(100.0 * (SELECT COUNT(*) FROM core.clientes) / COUNT(*), 1)::text
FROM core.leads;