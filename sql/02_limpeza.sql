-- Pode ser rodado várias vezes: esvazia as tabelas antes de carregar
TRUNCATE core.cancelamentos, core.receita_mensal, core.clientes,
         core.historico_etapas, core.leads, core.assessores;

-- 1) Assessores
INSERT INTO core.assessores (assessor_id, nome, equipe, data_entrada)
SELECT id::int, TRIM(nome), TRIM(equipe), data_entrada::date
FROM raw.assessores;

-- 2) Leads: padroniza origem e remove duplicados
INSERT INTO core.leads (lead_id, nome, email, data_criacao, origem, assessor_id, valor_potencial)
WITH base AS (
    SELECT
        id::int                          AS lead_id,
        TRIM(nome)                       AS nome,
        LOWER(TRIM(email))               AS email,
        data_criacao::date               AS data_criacao,
        CASE LOWER(TRANSLATE(TRIM(origem),
                 'ÁÃÂÉÊÍÓÕÔÚÇáãâéêíóõôúç',
                 'AAAEEIOOOUCaaaeeiooouc'))
            WHEN 'indicacao' THEN 'Indicação'
            WHEN 'evento'    THEN 'Evento'
            WHEN 'instagram' THEN 'Instagram'
            WHEN 'insta'     THEN 'Instagram'
            WHEN 'ig'        THEN 'Instagram'
            WHEN 'anuncio'   THEN 'Anúncio'
        END                              AS origem,
        assessor_id::int                 AS assessor_id,
        valor_potencial::numeric(12,2)   AS valor_potencial
    FROM raw.leads
),
ranqueado AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY email, nome
                              ORDER BY data_criacao, lead_id) AS rn
    FROM base
)
SELECT lead_id, nome, email, data_criacao, origem, assessor_id, valor_potencial
FROM ranqueado
WHERE rn = 1;   -- mantém só o registro mais antigo de cada duplicado

-- 3) Histórico de etapas: marca datas fora de ordem (não apaga)
INSERT INTO core.historico_etapas (lead_id, etapa, data_entrada_etapa, data_inconsistente)
WITH h AS (
    SELECT
        lead_id::int AS lead_id,
        etapa,
        data_entrada_etapa::date AS data_entrada_etapa,
        CASE etapa WHEN 'lead' THEN 1 WHEN 'contato' THEN 2 WHEN 'reuniao' THEN 3
                   WHEN 'proposta' THEN 4 WHEN 'fechado' THEN 5 ELSE 6 END AS ordem
    FROM raw.historico_etapas
),
c AS (
    SELECT *,
           LAG(data_entrada_etapa) OVER (PARTITION BY lead_id ORDER BY ordem) AS data_anterior
    FROM h
)
SELECT lead_id, etapa, data_entrada_etapa,
       COALESCE(data_entrada_etapa < data_anterior, FALSE)
FROM c;

-- 4) Clientes, receita e cancelamentos
INSERT INTO core.clientes (cliente_id, lead_id, data_fechamento, plano, mensalidade)
SELECT id::int, lead_id::int, data_fechamento::date, TRIM(plano), mensalidade::numeric(10,2)
FROM raw.clientes;

INSERT INTO core.receita_mensal (cliente_id, mes, valor)
SELECT cliente_id::int, mes::date, valor::numeric(10,2)
FROM raw.receita_mensal;

INSERT INTO core.cancelamentos (cliente_id, data_cancelamento, motivo)
SELECT cliente_id::int, data_cancelamento::date, TRIM(motivo)
FROM raw.cancelamentos;