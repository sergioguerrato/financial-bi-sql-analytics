# Financial BI Project

Projeto de **Business Intelligence end-to-end** utilizando uma stack moderna de Data Engineering.

O objetivo do projeto é simular um **ERP de imobiliária**, processar os dados com **dbt** e construir dashboards analíticos no **Apache Superset**.

---

# Arquitetura

```
Supabase (PostgreSQL)
   └── erp (raw data)

dbt
   └── analytics (staging + marts)

Apache Superset (Docker)
   └── Dashboards
```

Fluxo de dados:

```
ERP (schema erp)
        ↓
dbt (transformações)
        ↓
schema analytics
        ↓
Apache Superset
        ↓
Dashboards BI
```

---

# Tecnologias utilizadas

* PostgreSQL (Supabase)
* dbt (data transformation)
* Apache Superset (data visualization)
* Docker
* WSL + Ubuntu
* Python virtual environment

---

# Estrutura do Projeto

```
financial-bi/

docker/
   superset/
      docker-compose.yml

dbt/
   financial_dbt/
      dbt_project.yml
      models/
         staging/
         marts/

sql/
   create_erp_schema.sql

superset/
   exports/
      dashboards_export.zip
```

---

# Setup do Ambiente

## 1️ Abrir o WSL

```
wsl
```

---

## 2️ Criar ambiente Python

```
cd ~/financial-bi/dbt
python3 -m venv venv
source venv/bin/activate
```

---

## 3️ Instalar dbt

```
pip install dbt-postgres
```

---

## 4️ Configurar profiles.yml

Criar arquivo:

```
~/.dbt/profiles.yml
```

Exemplo:

```
financial_dbt:
  target: dev
  outputs:
    dev:
      type: postgres
      host: aws-1-us-east-2.pooler.supabase.com
      user: postgres.SEUTENANT
      password: SUA_SENHA
      port: 6543
      dbname: postgres
      schema: analytics
      sslmode: require
```

---

# Testar conexão

```
dbt debug
```

Resultado esperado:

```
All checks passed!
```

---

# Rodar transformações dbt

```
dbt run
```

Isso irá gerar as views no schema:

```
analytics
```

Exemplo:

```
analytics.mart_dre_mensal
```

---

# Subir Apache Superset

```
cd docker/superset
docker compose up -d
```

Verificar:

```
docker ps
```

Abrir no navegador:

```
http://localhost:8088
```

Login padrão:

```
admin
admin
```

---

# 🔗 Conectar Superset ao Banco

Dentro do Superset:

```
Settings → Database Connections → PostgreSQL
```

Configuração:

Host

```
aws-1-us-east-2.pooler.supabase.com
```

Port

```
6543
```

Database

```
postgres
```

Schema utilizado:

```
analytics
```

---

# Dataset utilizado

```
analytics.mart_dre_mensal
```

Esse dataset alimenta os dashboards de **DRE mensal**.

---

# Dashboards

Os dashboards exibem:

* Receita mensal
* Despesas mensais
* Lucro líquido
* Evolução financeira

---

# Export dos Dashboards

Os dashboards do Superset podem ser exportados em:

```
superset/exports/
```

Isso permite importar o BI completo em outro ambiente.

---

# Conceitos aplicados

Este projeto demonstra:

* Data Modeling
* ELT Architecture
* Data Warehouse layers (raw → staging → marts)
* Containerização
* Versionamento de transformações
* BI self-service

---

# Objetivo do Projeto

Demonstrar uma **arquitetura moderna de dados** utilizando ferramentas amplamente usadas no mercado de Data Engineering.

---

# Autor
Sérgio Guerrato
