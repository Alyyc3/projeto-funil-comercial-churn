"""Gera dados sintéticos de funil comercial e churn de uma assessoria fictícia."""
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
from faker import Faker

SEED = 42
rng = np.random.default_rng(SEED)
fake = Faker("pt_BR")
Faker.seed(SEED)

INICIO = pd.Timestamp("2024-01-01")
FIM = pd.Timestamp("2025-12-31")
SAIDA = Path(__file__).resolve().parent.parent / "data"
SAIDA.mkdir(exist_ok=True)

# ---------- Regras de negócio (as mesmas do README) ----------
# origem: (nº de leads, conversão, ciclo médio em dias, multiplicador de churn)
ORIGENS = {
    "Indicação": (1400, 0.28, 20, 0.7),
    "Evento":    (1600, 0.13, 30, 1.0),
    "Instagram": (2600, 0.075, 35, 1.1),
    "Anúncio":   (2400, 0.04, 45, 1.5),
}
ETAPAS = ["lead", "contato", "reuniao", "proposta", "fechado"]
# em qual etapa para quem NÃO fecha (0 = nunca foi contatado ... 3 = parou na proposta)
PESO_PARADA = [0.30, 0.25, 0.20, 0.25]
PLANOS = {"Básico": (150, 0.55), "Intermediário": (350, 0.33), "Premium": (800, 0.12)}
MOTIVOS = ["Preço", "Insatisfação com rentabilidade", "Mudou de assessoria",
           "Fim da necessidade", "Atendimento"]
# sazonalidade: mais leads no início do ano (jan..dez)
PESO_MES = [1.3, 1.2, 1.1, 1.0, 1.0, 0.9, 0.9, 0.9, 1.0, 1.0, 0.9, 0.8]

# ---------- Assessores ----------
equipes = ["Alfa", "Beta", "Gama"]
assessores = pd.DataFrame({
    "id": range(1, 13),
    "nome": [fake.name() for _ in range(12)],
    "equipe": [equipes[i % 3] for i in range(12)],
    "data_entrada": [fake.date_between(date(2021, 1, 1), date(2023, 12, 31))
                     for _ in range(12)],
})
habilidade = rng.uniform(0.75, 1.25, 12)  # cada assessor converte mais ou menos

# ---------- Leads e histórico de etapas ----------
dias = pd.date_range(INICIO, FIM)
pesos_dia = np.array([PESO_MES[d.month - 1] for d in dias])
pesos_dia = pesos_dia / pesos_dia.sum()

leads, historico = [], []
origem_do_lead = {}
lead_id = 0

for origem, (n, conv, ciclo, _) in ORIGENS.items():
    datas = rng.choice(dias, size=n, p=pesos_dia)
    escala = ciclo / 8  # 4 transições, gamma(shape=2): média = ciclo/4 cada
    for data in datas:
        lead_id += 1
        data = pd.Timestamp(data)
        idx_ass = int(rng.integers(0, 12))
        fecha = rng.random() < min(conv * habilidade[idx_ass], 0.95)
        ultima = 4 if fecha else int(rng.choice(4, p=PESO_PARADA))

        origem_do_lead[lead_id] = origem
        leads.append({
            "id": lead_id,
            "nome": fake.name(),
            "email": fake.email(),
            "data_criacao": data,
            "origem": origem,
            "assessor_id": idx_ass + 1,
            "valor_potencial": round(float(rng.lognormal(np.log(50000), 0.8)), 2),
        })

        data_etapa = data
        for i in range(ultima + 1):
            if i > 0:
                data_etapa += pd.Timedelta(days=max(1, round(rng.gamma(2, escala))))
            if data_etapa > FIM:
                break
            historico.append({"lead_id": lead_id, "etapa": ETAPAS[i],
                              "data_entrada_etapa": data_etapa})

        if not fecha and data_etapa <= FIM:
            data_perda = data_etapa + pd.Timedelta(days=int(rng.integers(3, 31)))
            if data_perda <= FIM:
                historico.append({"lead_id": lead_id, "etapa": "perdido",
                                  "data_entrada_etapa": data_perda})

hist_df = pd.DataFrame(historico)

# ---------- Clientes, receita mensal e cancelamentos ----------
CHURN_MULT = {o: v[3] for o, v in ORIGENS.items()}
nomes_planos = list(PLANOS)
prob_planos = [v[1] for v in PLANOS.values()]

fechados = hist_df[hist_df["etapa"] == "fechado"]
clientes, receita, cancelamentos = [], [], []

for cid, row in enumerate(fechados.itertuples(), start=1):
    plano = str(rng.choice(nomes_planos, p=prob_planos))
    mensalidade = PLANOS[plano][0]
    clientes.append({"id": cid, "lead_id": row.lead_id,
                     "data_fechamento": row.data_entrada_etapa,
                     "plano": plano, "mensalidade": mensalidade})

    mult = CHURN_MULT[origem_do_lead[row.lead_id]]
    mes = row.data_entrada_etapa.to_period("M").to_timestamp()
    idade = 0
    while mes <= FIM:
        receita.append({"cliente_id": cid, "mes": mes, "valor": mensalidade})
        idade += 1
        prox = mes + pd.offsets.MonthBegin(1)
        risco = (0.04 if idade <= 3 else 0.015) * mult  # churn maior no início
        if prox <= FIM and rng.random() < risco:
            cancelamentos.append({
                "cliente_id": cid,
                "data_cancelamento": prox + pd.Timedelta(days=int(rng.integers(0, 28))),
                "motivo": str(rng.choice(MOTIVOS)),
            })
            break
        mes = prox

leads_df = pd.DataFrame(leads)

# ---------- Sujeira controlada ----------
# 1) ~2% de leads duplicados (mesmo nome/email, novo id, um dia depois)
dup = leads_df.sample(frac=0.02, random_state=SEED).copy()
dup["id"] = range(leads_df["id"].max() + 1, leads_df["id"].max() + 1 + len(dup))
dup["data_criacao"] = dup["data_criacao"] + pd.Timedelta(days=1)
leads_df = pd.concat([leads_df, dup], ignore_index=True)

# 2) ~5% das origens com grafia diferente
variacoes = {
    "Indicação": ["indicacao", "Indicacao", "INDICAÇÃO"],
    "Evento": ["evento", "EVENTO"],
    "Instagram": ["instagram", "IG", "Insta"],
    "Anúncio": ["anuncio", "Anuncio", "ANÚNCIO"],
}
mask = rng.random(len(leads_df)) < 0.05
leads_df.loc[mask, "origem"] = [str(rng.choice(variacoes[o]))
                                for o in leads_df.loc[mask, "origem"]]

# 3) ~2% das datas de reunião/proposta anteriores à etapa anterior
alvo = hist_df[hist_df["etapa"].isin(["reuniao", "proposta"])].sample(
    frac=0.02, random_state=SEED).index
hist_df.loc[alvo, "data_entrada_etapa"] -= pd.Timedelta(days=20)

# ---------- Salvar ----------
tabelas = {
    "assessores": assessores,
    "leads": leads_df,
    "historico_etapas": hist_df,
    "clientes": pd.DataFrame(clientes),
    "receita_mensal": pd.DataFrame(receita),
    "cancelamentos": pd.DataFrame(cancelamentos),
}
for nome, df in tabelas.items():
    df.to_csv(SAIDA / f"{nome}.csv", index=False, encoding="utf-8")
    print(f"{nome}: {len(df):,} linhas")

print(f"\nConversão geral: {len(clientes) / len(leads):.1%}")