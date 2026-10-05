"""Carrega os CSVs em um schema 'raw' do PostgreSQL, sem nenhuma limpeza."""
import os
from pathlib import Path

import pandas as pd
from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

RAIZ = Path(__file__).resolve().parent.parent
load_dotenv(RAIZ / ".env")

url = URL.create(
    "postgresql+psycopg2",
    username=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    host=os.getenv("DB_HOST", "localhost"),
    port=int(os.getenv("DB_PORT", "5432")),
    database=os.getenv("DB_NAME"),
)
engine = create_engine(url)

TABELAS = ["assessores", "leads", "historico_etapas",
           "clientes", "receita_mensal", "cancelamentos"]

with engine.begin() as conn:
    conn.execute(text("CREATE SCHEMA IF NOT EXISTS raw"))

for nome in TABELAS:
    df = pd.read_csv(RAIZ / "data" / f"{nome}.csv", dtype=str)
    df.to_sql(nome, engine, schema="raw", if_exists="replace",
              index=False, chunksize=5000)
    print(f"raw.{nome}: {len(df):,} linhas carregadas")