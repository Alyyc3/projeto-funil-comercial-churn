"""Análise do funil e do churn: gráficos, qui-quadrado e regressão logística."""
import os
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import statsmodels.formula.api as smf
from dotenv import load_dotenv
from scipy.stats import chi2_contingency
from sklearn.metrics import roc_auc_score
from sqlalchemy import create_engine
from sqlalchemy.engine import URL

RAIZ = Path(__file__).resolve().parent.parent
FIG = RAIZ / "docs" / "img"
FIG.mkdir(parents=True, exist_ok=True)
load_dotenv(RAIZ / ".env")
sns.set_theme(style="whitegrid")

engine = create_engine(URL.create(
    "postgresql+psycopg2",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "5432")),
    database=os.getenv("DB_NAME"),
))

# ---------- 1) Dados vindos das views ----------
origem = pd.read_sql("SELECT * FROM analytics.vw_origem ORDER BY conversao_pct DESC", engine)
coorte = pd.read_sql("SELECT * FROM analytics.vw_coorte_retencao", engine)
mrr = pd.read_sql("SELECT * FROM analytics.vw_mrr_mensal ORDER BY mes", engine)
leads = pd.read_sql("SELECT * FROM analytics.vw_leads_detalhe", engine)

print(f"Leads: {len(leads):,} | Clientes: {leads['virou_cliente'].sum():,} "
      f"| Cancelados: {leads['cancelou'].sum():,}\n")

# ---------- 2) Gráfico: conversão por origem ----------
fig, ax = plt.subplots(figsize=(7, 4))
sns.barplot(data=origem, x="origem", y="conversao_pct", color="#2f6fb3", ax=ax)
for i, v in enumerate(origem["conversao_pct"]):
    ax.text(i, v + 0.4, f"{v:.1f}%", ha="center")
ax.set_title("Conversão de lead em cliente, por origem")
ax.set_xlabel("")
ax.set_ylabel("Conversão (%)")
fig.tight_layout()
fig.savefig(FIG / "conversao_por_origem.png", dpi=150)
plt.close(fig)

# ---------- 3) Gráfico: heatmap de retenção por coorte ----------
mat = coorte.pivot(index="mes_coorte", columns="meses_desde_entrada", values="retencao_pct")
mat.index = pd.to_datetime(mat.index).strftime("%Y-%m")
fig, ax = plt.subplots(figsize=(14, 8))
sns.heatmap(mat, annot=True, fmt=".0f", annot_kws={"size": 7},
            cmap="Blues", vmin=60, vmax=100, cbar_kws={"label": "Retenção (%)"}, ax=ax)
ax.set_title("Retenção por coorte de entrada (% de clientes ainda ativos)")
ax.set_xlabel("Meses desde a entrada")
ax.set_ylabel("Mês de entrada")
fig.tight_layout()
fig.savefig(FIG / "retencao_coorte.png", dpi=150)
plt.close(fig)

# ---------- 4) Gráfico: MRR e churn mensal ----------
mrr["mes"] = pd.to_datetime(mrr["mes"])
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(10, 7), sharex=True)
ax1.plot(mrr["mes"], mrr["mrr"], marker="o", color="#2f6fb3")
ax1.set_title("Receita recorrente mensal (MRR)")
ax1.set_ylabel("R$")
ax2.bar(mrr["mes"], mrr["churn_pct"], width=20, color="#c0504d")
ax2.set_title("Churn mensal (%)")
ax2.set_ylabel("%")
fig.tight_layout()
fig.savefig(FIG / "mrr_e_churn.png", dpi=150)
plt.close(fig)

# ---------- 5) Teste qui-quadrado: origem x conversão ----------
tabela = pd.crosstab(leads["origem"], leads["virou_cliente"])
chi2, p, gl, esperado = chi2_contingency(tabela)
n = tabela.values.sum()
cramer_v = np.sqrt(chi2 / (n * (min(tabela.shape) - 1)))

print("=== Qui-quadrado: origem x conversão ===")
print(tabela, "\n")
print(f"chi2 = {chi2:.1f} | gl = {gl} | p-valor = {p:.2e} | V de Cramér = {cramer_v:.3f}")
print(f"Menor frequência esperada = {esperado.min():.1f} (pressuposto: >= 5)\n")

# ---------- 6) Regressão logística: o que explica o cancelamento? ----------
cli = leads[leads["virou_cliente"]].copy()
cli["data_fechamento"] = pd.to_datetime(cli["data_fechamento"])
cli["cancelou"] = cli["cancelou"].astype(int)
# Exposição: meses entre a entrada e o fim da base (quem entrou antes teve mais tempo para cancelar)
cli["meses_exposicao"] = (pd.Timestamp("2025-12-31") - cli["data_fechamento"]).dt.days / 30.44

modelo = smf.logit(
    "cancelou ~ C(origem, Treatment('Evento')) + C(plano, Treatment('Básico')) + meses_exposicao",
    data=cli,
).fit(disp=False)

ic = modelo.conf_int()
resultado = pd.DataFrame({
    "odds_ratio": np.exp(modelo.params),
    "ic95_inf": np.exp(ic[0]),
    "ic95_sup": np.exp(ic[1]),
    "p_valor": modelo.pvalues,
}).round(3)
resultado.index = (resultado.index
                   .str.replace(r"C\(origem, Treatment\('Evento'\)\)\[T\.", "origem: ", regex=True)
                   .str.replace(r"C\(plano, Treatment\('Básico'\)\)\[T\.", "plano: ", regex=True)
                   .str.replace("]", "", regex=False))

auc = roc_auc_score(cli["cancelou"], modelo.predict(cli))
print("=== Regressão logística: cancelamento (referência: origem Evento, plano Básico) ===")
print(resultado.to_string(), "\n")
print(f"N = {int(modelo.nobs)} | Pseudo R² (McFadden) = {modelo.prsquared:.3f} "
      f"| p-valor do teste LR = {modelo.llr_pvalue:.3g} | AUC = {auc:.3f}")

resultado.to_csv(RAIZ / "docs" / "resultado_regressao_churn.csv", encoding="utf-8")
print(f"\nGráficos salvos em: {FIG}")
print("=== Conversão por origem ===")
print(origem.to_string(index=False), "\n")