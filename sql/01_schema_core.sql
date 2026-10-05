CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.cancelamentos, core.receita_mensal, core.clientes,
                     core.historico_etapas, core.leads, core.assessores CASCADE;

CREATE TABLE core.assessores (
    assessor_id   INT PRIMARY KEY,
    nome          VARCHAR(100) NOT NULL,
    equipe        VARCHAR(20)  NOT NULL,
    data_entrada  DATE         NOT NULL
);

CREATE TABLE core.leads (
    lead_id          INT PRIMARY KEY,
    nome             VARCHAR(150) NOT NULL,
    email            VARCHAR(150) NOT NULL,
    data_criacao     DATE         NOT NULL,
    origem           VARCHAR(20)  NOT NULL
        CHECK (origem IN ('Indicação', 'Evento', 'Instagram', 'Anúncio')),
    assessor_id      INT          NOT NULL REFERENCES core.assessores(assessor_id),
    valor_potencial  NUMERIC(12,2)
);

CREATE TABLE core.historico_etapas (
    lead_id             INT         NOT NULL REFERENCES core.leads(lead_id),
    etapa               VARCHAR(20) NOT NULL
        CHECK (etapa IN ('lead', 'contato', 'reuniao', 'proposta', 'fechado', 'perdido')),
    data_entrada_etapa  DATE        NOT NULL,
    data_inconsistente  BOOLEAN     NOT NULL DEFAULT FALSE,
    PRIMARY KEY (lead_id, etapa)
);

CREATE TABLE core.clientes (
    cliente_id       INT PRIMARY KEY,
    lead_id          INT           NOT NULL UNIQUE REFERENCES core.leads(lead_id),
    data_fechamento  DATE          NOT NULL,
    plano            VARCHAR(20)   NOT NULL,
    mensalidade      NUMERIC(10,2) NOT NULL
);

CREATE TABLE core.receita_mensal (
    cliente_id  INT           NOT NULL REFERENCES core.clientes(cliente_id),
    mes         DATE          NOT NULL,
    valor       NUMERIC(10,2) NOT NULL,
    PRIMARY KEY (cliente_id, mes)
);

CREATE TABLE core.cancelamentos (
    cliente_id         INT PRIMARY KEY REFERENCES core.clientes(cliente_id),
    data_cancelamento  DATE        NOT NULL,
    motivo             VARCHAR(50) NOT NULL
);

-- Índices nas colunas mais usadas em filtros e joins
CREATE INDEX idx_leads_origem        ON core.leads(origem);
CREATE INDEX idx_leads_assessor      ON core.leads(assessor_id);
CREATE INDEX idx_leads_data          ON core.leads(data_criacao);
CREATE INDEX idx_hist_etapa          ON core.historico_etapas(etapa);
CREATE INDEX idx_receita_mes         ON core.receita_mensal(mes);
CREATE INDEX idx_cancel_data         ON core.cancelamentos(data_cancelamento);