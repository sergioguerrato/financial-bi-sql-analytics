-- ============================================================
-- ERP SIMULADOR (IMOBILIÁRIA) + FINANCEIRO (DRE) - POSTGRES
-- 1 ano de dados sintéticos para BI contábil
-- ============================================================

BEGIN;

-- 0) Schema
CREATE SCHEMA IF NOT EXISTS erp;

-- 1) Tipos auxiliares
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_pessoa') THEN
    CREATE TYPE erp.tipo_pessoa AS ENUM ('cliente','consultor','gerente','socio');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_imovel') THEN
    CREATE TYPE erp.status_imovel AS ENUM ('disponivel','alugado','vendido');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_contrato') THEN
    CREATE TYPE erp.status_contrato AS ENUM ('ativo','cancelado','encerrado');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'tipo_conta') THEN
    CREATE TYPE erp.tipo_conta AS ENUM ('receita','despesa');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'categoria_conta') THEN
    CREATE TYPE erp.categoria_conta AS ENUM ('operacional','administrativa','financeira','tributaria');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'origem_titulo') THEN
    CREATE TYPE erp.origem_titulo AS ENUM ('aluguel','comissao_venda','despesa_fixa','despesa_variavel','imposto');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'status_titulo') THEN
    CREATE TYPE erp.status_titulo AS ENUM ('aberto','pago','cancelado','vencido');
  END IF;
END $$;

-- 2) Tabelas (drop na ordem certa para re-execução)
DROP VIEW IF EXISTS erp.dre_mensal;
DROP VIEW IF EXISTS erp.fato_financeiro;

DROP TABLE IF EXISTS erp.conta_pagar CASCADE;
DROP TABLE IF EXISTS erp.conta_receber CASCADE;
DROP TABLE IF EXISTS erp.plano_contas CASCADE;

DROP TABLE IF EXISTS erp.renovacao_contrato CASCADE;
DROP TABLE IF EXISTS erp.venda_imovel CASCADE;
DROP TABLE IF EXISTS erp.contrato_locacao CASCADE;

DROP TABLE IF EXISTS erp.imovel CASCADE;
DROP TABLE IF EXISTS erp.pessoa CASCADE;

-- 3) Entidades principais
CREATE TABLE erp.pessoa (
  id_pessoa        BIGSERIAL PRIMARY KEY,
  nome             TEXT NOT NULL,
  tipo             erp.tipo_pessoa NOT NULL,
  criado_em        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE erp.imovel (
  id_imovel        BIGSERIAL PRIMARY KEY,
  tipo             TEXT NOT NULL CHECK (tipo IN ('apartamento','casa','comercial')),
  valor_venda      NUMERIC(14,2) NOT NULL CHECK (valor_venda > 0),
  valor_aluguel    NUMERIC(14,2) NOT NULL CHECK (valor_aluguel > 0),
  status           erp.status_imovel NOT NULL DEFAULT 'disponivel',
  criado_em        TIMESTAMP NOT NULL DEFAULT now()
);

CREATE TABLE erp.contrato_locacao (
  id_contrato          BIGSERIAL PRIMARY KEY,
  id_cliente           BIGINT NOT NULL REFERENCES erp.pessoa(id_pessoa),
  id_imovel            BIGINT NOT NULL REFERENCES erp.imovel(id_imovel),
  id_consultor         BIGINT NOT NULL REFERENCES erp.pessoa(id_pessoa),
  data_inicio          DATE NOT NULL,
  data_fim             DATE NOT NULL,
  valor_aluguel        NUMERIC(14,2) NOT NULL CHECK (valor_aluguel > 0),
  taxa_administracao   NUMERIC(6,4) NOT NULL CHECK (taxa_administracao >= 0 AND taxa_administracao <= 1),
  status               erp.status_contrato NOT NULL DEFAULT 'ativo',
  criado_em            TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_periodo_contrato CHECK (data_fim > data_inicio)
);

CREATE TABLE erp.renovacao_contrato (
  id_renovacao      BIGSERIAL PRIMARY KEY,
  id_contrato       BIGINT NOT NULL REFERENCES erp.contrato_locacao(id_contrato) ON DELETE CASCADE,
  data_renovacao    DATE NOT NULL,
  nova_data_fim     DATE NOT NULL,
  criado_em         TIMESTAMP NOT NULL DEFAULT now(),
  CONSTRAINT ck_nova_data_fim CHECK (nova_data_fim > data_renovacao)
);

CREATE TABLE erp.venda_imovel (
  id_venda              BIGSERIAL PRIMARY KEY,
  id_imovel             BIGINT NOT NULL REFERENCES erp.imovel(id_imovel),
  id_cliente            BIGINT NOT NULL REFERENCES erp.pessoa(id_pessoa),
  id_consultor          BIGINT NOT NULL REFERENCES erp.pessoa(id_pessoa),
  data_venda            DATE NOT NULL,
  valor_venda           NUMERIC(14,2) NOT NULL CHECK (valor_venda > 0),
  percentual_comissao   NUMERIC(6,4) NOT NULL CHECK (percentual_comissao >= 0 AND percentual_comissao <= 1),
  criado_em             TIMESTAMP NOT NULL DEFAULT now()
);

-- 4) Financeiro
CREATE TABLE erp.plano_contas (
  id_conta      BIGSERIAL PRIMARY KEY,
  codigo        TEXT NOT NULL UNIQUE,
  descricao     TEXT NOT NULL,
  tipo          erp.tipo_conta NOT NULL,
  categoria     erp.categoria_conta NOT NULL
);

CREATE TABLE erp.conta_receber (
  id_titulo        BIGSERIAL PRIMARY KEY,
  id_conta         BIGINT NOT NULL REFERENCES erp.plano_contas(id_conta),
  origem           erp.origem_titulo NOT NULL,
  id_referencia    BIGINT NULL, -- contrato ou venda (sem FK por simplicidade)
  data_emissao     DATE NOT NULL,
  data_vencimento  DATE NOT NULL,
  data_pagamento   DATE NULL,
  valor            NUMERIC(14,2) NOT NULL CHECK (valor > 0),
  status           erp.status_titulo NOT NULL DEFAULT 'aberto',
  id_pessoa        BIGINT NULL REFERENCES erp.pessoa(id_pessoa),
  id_imovel        BIGINT NULL REFERENCES erp.imovel(id_imovel),
  CONSTRAINT ck_vencimento_ar CHECK (data_vencimento >= data_emissao)
);

CREATE TABLE erp.conta_pagar (
  id_titulo        BIGSERIAL PRIMARY KEY,
  id_conta         BIGINT NOT NULL REFERENCES erp.plano_contas(id_conta),
  origem           erp.origem_titulo NOT NULL,
  fornecedor       TEXT NOT NULL,
  data_emissao     DATE NOT NULL,
  data_vencimento  DATE NOT NULL,
  data_pagamento   DATE NULL,
  valor            NUMERIC(14,2) NOT NULL CHECK (valor > 0),
  status           erp.status_titulo NOT NULL DEFAULT 'aberto',
  recorrente       BOOLEAN NOT NULL DEFAULT false,
  CONSTRAINT ck_vencimento_ap CHECK (data_vencimento >= data_emissao)
);

-- Índices úteis
CREATE INDEX ix_contrato_status ON erp.contrato_locacao(status);
CREATE INDEX ix_contrato_datas ON erp.contrato_locacao(data_inicio, data_fim);
CREATE INDEX ix_ar_vencimento ON erp.conta_receber(data_vencimento);
CREATE INDEX ix_ap_vencimento ON erp.conta_pagar(data_vencimento);

-- 5) Seed do plano de contas (mínimo para DRE)
INSERT INTO erp.plano_contas (codigo, descricao, tipo, categoria) VALUES
('3.1.01', 'Receita de administração de aluguel', 'receita', 'operacional'),
('3.1.02', 'Receita de comissão de venda',          'receita', 'operacional'),

('4.1.01', 'Salários (consultores)',                'despesa', 'administrativa'),
('4.1.02', 'Salário (gerente)',                     'despesa', 'administrativa'),
('4.1.03', 'Pró-labore (sócios)',                   'despesa', 'administrativa'),
('4.2.01', 'Aluguel do escritório',                 'despesa', 'administrativa'),
('4.2.02', 'Sistemas e ferramentas',                'despesa', 'administrativa'),
('4.2.03', 'Contabilidade',                         'despesa', 'administrativa'),
('4.3.01', 'Marketing',                             'despesa', 'operacional'),
('4.9.01', 'Impostos sobre receita (simulado)',     'despesa', 'tributaria');

-- 6) Parâmetros do gerador
DO $$
DECLARE
  v_inicio DATE := DATE '2025-01-01';
  v_fim    DATE := DATE '2025-12-31';

  -- Parametrização
  v_contratos_iniciais INT := 50;
  v_novos_mes INT := 3;
  v_renov_mes INT := 4;
  v_cancel_mes INT := 2;

  v_consultores INT := 3;

  -- Faixas de valores
  v_taxa_min NUMERIC := 0.08;  -- 8%
  v_taxa_max NUMERIC := 0.12;  -- 12%
  v_comissao_min NUMERIC := 0.04; -- 4%
  v_comissao_max NUMERIC := 0.06; -- 6%

  -- Despesas fixas base (mensal)
  v_salario_consultor NUMERIC := 3500.00;
  v_salario_gerente   NUMERIC := 6500.00;
  v_prolabore_socio   NUMERIC := 8000.00;
  v_aluguel_escritorio NUMERIC := 4500.00;
  v_sistemas          NUMERIC := 1200.00;
  v_contabilidade     NUMERIC := 1500.00;

  -- Impostos (simulado) sobre receita bruta
  v_taxa_imposto NUMERIC := 0.08; -- 8%
BEGIN
  PERFORM setseed(0.42);

  -- 6.1) Pessoas
  -- consultores
  INSERT INTO erp.pessoa (nome, tipo)
  SELECT 'Consultor ' || gs, 'consultor'::erp.tipo_pessoa
  FROM generate_series(1, v_consultores) gs;

  -- gerente
  INSERT INTO erp.pessoa (nome, tipo) VALUES ('Gerente Comercial', 'gerente');

  -- socios
  INSERT INTO erp.pessoa (nome, tipo)
  SELECT 'Sócio ' || gs, 'socio'::erp.tipo_pessoa
  FROM generate_series(1,2) gs;

  -- clientes (quantidade suficiente para locação + vendas)
  INSERT INTO erp.pessoa (nome, tipo)
  SELECT 'Cliente ' || gs, 'cliente'::erp.tipo_pessoa
  FROM generate_series(1, 250) gs;

  -- 6.2) Imóveis (mix para locação e venda)
  INSERT INTO erp.imovel (tipo, valor_venda, valor_aluguel, status)
  SELECT
    (ARRAY['apartamento','casa','comercial'])[1 + floor(random()*3)::int],
    round((200000 + random()*800000)::numeric, 2) AS valor_venda,
    round((1200 + random()*3800)::numeric, 2)     AS valor_aluguel,
    'disponivel'::erp.status_imovel
  FROM generate_series(1, 220);

  -- 6.3) Contratos iniciais (começam antes do ano para já ter carteira ativa)
  -- pega 50 imóveis e 50 clientes, consultor aleatório
  INSERT INTO erp.contrato_locacao
    (id_cliente, id_imovel, id_consultor, data_inicio, data_fim, valor_aluguel, taxa_administracao, status)
  SELECT
    c.id_pessoa AS id_cliente,
    i.id_imovel,
    (SELECT id_pessoa FROM erp.pessoa WHERE tipo='consultor' ORDER BY random() LIMIT 1) AS id_consultor,
    (v_inicio - (30 + floor(random()*120))::int) AS data_inicio,
    (v_inicio + (180 + floor(random()*360))::int) AS data_fim,
    i.valor_aluguel,
    round((v_taxa_min + random()*(v_taxa_max - v_taxa_min))::numeric, 4),
    'ativo'::erp.status_contrato
  FROM (
    SELECT id_pessoa FROM erp.pessoa WHERE tipo='cliente' ORDER BY id_pessoa LIMIT v_contratos_iniciais
  ) c
  JOIN (
    SELECT id_imovel, valor_aluguel FROM erp.imovel ORDER BY id_imovel LIMIT v_contratos_iniciais
  ) i ON true;

  -- marca esses imóveis como alugados
  UPDATE erp.imovel im
  SET status = 'alugado'
  WHERE im.id_imovel IN (SELECT id_imovel FROM erp.contrato_locacao WHERE status='ativo');

  -- Para evitar lógica complexa em SQL puro, usamos uma abordagem set-based por mês:

  -- 6.4.1) Novos contratos por mês (3)
  INSERT INTO erp.contrato_locacao
    (id_cliente, id_imovel, id_consultor, data_inicio, data_fim, valor_aluguel, taxa_administracao, status)
  SELECT
    (SELECT id_pessoa FROM erp.pessoa WHERE tipo='cliente' ORDER BY random() LIMIT 1),
    im.id_imovel,
    (SELECT id_pessoa FROM erp.pessoa WHERE tipo='consultor' ORDER BY random() LIMIT 1),
    m.mes + (floor(random()*10))::int,
    (m.mes + interval '12 months')::date - 1,
    im.valor_aluguel,
    round((v_taxa_min + random()*(v_taxa_max - v_taxa_min))::numeric, 4),
    'ativo'::erp.status_contrato
  FROM (
    SELECT date_trunc('month', d)::date AS mes
    FROM generate_series(v_inicio, v_fim, interval '1 month') d
  ) m
  JOIN LATERAL (
    SELECT id_imovel, valor_aluguel
    FROM erp.imovel
    WHERE status='disponivel'
    ORDER BY random()
    LIMIT v_novos_mes
  ) im ON true;

  -- atualiza imóveis desses novos contratos para alugado
  UPDATE erp.imovel im
  SET status='alugado'
  WHERE im.id_imovel IN (
    SELECT id_imovel
    FROM erp.contrato_locacao
    WHERE data_inicio BETWEEN v_inicio AND v_fim
  );

  -- 6.4.2) Renovações por mês (4):
  -- escolhe contratos ativos com data_fim caindo nos próximos ~60 dias do mês e estende +12 meses
  INSERT INTO erp.renovacao_contrato (id_contrato, data_renovacao, nova_data_fim)
  SELECT
    c.id_contrato,
    m.mes + (floor(random()*8))::int AS data_renovacao,
    (c.data_fim + interval '12 months')::date AS nova_data_fim
  FROM (
    SELECT date_trunc('month', d)::date AS mes
    FROM generate_series(v_inicio, v_fim, interval '1 month') d
  ) m
  JOIN LATERAL (
    SELECT id_contrato, data_fim
    FROM erp.contrato_locacao
    WHERE status='ativo'
      AND data_fim BETWEEN m.mes AND (m.mes + interval '60 days')::date
    ORDER BY random()
    LIMIT v_renov_mes
  ) c ON true;

  -- aplica nova data_fim nos contratos renovados
  UPDATE erp.contrato_locacao c
  SET data_fim = r.nova_data_fim
  FROM erp.renovacao_contrato r
  WHERE r.id_contrato = c.id_contrato;

  -- 6.4.3) Cancelamentos por mês (2): pega ativos e marca cancelado com data_fim no mês
  UPDATE erp.contrato_locacao c
  SET status='cancelado',
      data_fim = LEAST(c.data_fim, (date_trunc('month', v_inicio)::date + (extract(month from c.criado_em)::int))::date)
  WHERE c.id_contrato IN (
    SELECT id_contrato
    FROM erp.contrato_locacao
    WHERE status='ativo'
    ORDER BY random()
    LIMIT (SELECT COUNT(*) FROM generate_series(1, v_cancel_mes))
  );

  -- imóveis de contratos cancelados voltam a disponível (simulação simples)
  UPDATE erp.imovel im
  SET status='disponivel'
  WHERE im.id_imovel IN (
    SELECT id_imovel FROM erp.contrato_locacao WHERE status='cancelado'
  );

  -- 6.5) Vendas: 2 por consultor por mês (6/mês)
  INSERT INTO erp.venda_imovel (id_imovel, id_cliente, id_consultor, data_venda, valor_venda, percentual_comissao)
  SELECT
    im.id_imovel,
    (SELECT id_pessoa FROM erp.pessoa WHERE tipo='cliente' ORDER BY random() LIMIT 1),
    cons.id_pessoa,
    m.mes + (floor(random()*20))::int AS data_venda,
    im.valor_venda,
    round((v_comissao_min + random()*(v_comissao_max - v_comissao_min))::numeric, 4)
  FROM (
    SELECT date_trunc('month', d)::date AS mes
    FROM generate_series(v_inicio, v_fim, interval '1 month') d
  ) m
  CROSS JOIN (SELECT id_pessoa FROM erp.pessoa WHERE tipo='consultor') cons
  JOIN LATERAL (
    SELECT id_imovel, valor_venda
    FROM erp.imovel
    WHERE status IN ('disponivel','alugado') -- pode vender imóvel que não está alugado idealmente; mantemos simples
    ORDER BY random()
    LIMIT 2
  ) im ON true;

  -- marca imóveis vendidos
  UPDATE erp.imovel im
  SET status='vendido'
  WHERE im.id_imovel IN (SELECT id_imovel FROM erp.venda_imovel);

  -- 6.6) Financeiro: Contas a Receber (aluguel/admin) mensal por contrato ativo naquele mês
  -- Para cada mês: receita de administração = aluguel * taxa_adm
  -- Também pode existir "aluguel" como origem, mas aqui registramos como receita de administração (BI contábil)
  INSERT INTO erp.conta_receber
    (id_conta, origem, id_referencia, data_emissao, data_vencimento, data_pagamento, valor, status, id_pessoa, id_imovel)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='3.1.01') AS id_conta,
    'aluguel'::erp.origem_titulo,
    c.id_contrato,
    (date_trunc('month', m.mes)::date + 0) AS data_emissao,
    (date_trunc('month', m.mes)::date + 5) AS data_vencimento,
    -- pagamento: 80% paga no mês (até dia 10), 20% paga com atraso no mês seguinte
    CASE WHEN random() < 0.80
         THEN (date_trunc('month', m.mes)::date + 10)
         ELSE (date_trunc('month', (m.mes + interval '1 month'))::date + 10)
    END AS data_pagamento,
    round((c.valor_aluguel * c.taxa_administracao)::numeric, 2) AS valor,
    'pago'::erp.status_titulo,
    c.id_cliente,
    c.id_imovel
  FROM (
    SELECT date_trunc('month', d)::date AS mes
    FROM generate_series(v_inicio, v_fim, interval '1 month') d
  ) m
  JOIN erp.contrato_locacao c
    ON c.data_inicio <= (m.mes + interval '1 month - 1 day')::date
   AND c.data_fim    >= m.mes
   AND c.status IN ('ativo','cancelado'); -- cancelado ainda pode ter mês corrente

  -- 6.7) Financeiro: Contas a Receber (comissão de venda) - 50% no mês, 50% no mês seguinte
  INSERT INTO erp.conta_receber
    (id_conta, origem, id_referencia, data_emissao, data_vencimento, data_pagamento, valor, status, id_pessoa, id_imovel)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='3.1.02'),
    'comissao_venda'::erp.origem_titulo,
    v.id_venda,
    v.data_venda,
    (v.data_venda + 7),
    (v.data_venda + 12),
    round((v.valor_venda * v.percentual_comissao * 0.5)::numeric, 2),
    'pago'::erp.status_titulo,
    v.id_consultor,
    v.id_imovel
  FROM erp.venda_imovel v
  WHERE v.data_venda BETWEEN v_inicio AND v_fim;

  INSERT INTO erp.conta_receber
    (id_conta, origem, id_referencia, data_emissao, data_vencimento, data_pagamento, valor, status, id_pessoa, id_imovel)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='3.1.02'),
    'comissao_venda'::erp.origem_titulo,
    v.id_venda,
    (v.data_venda + interval '1 month')::date,
    ((v.data_venda + interval '1 month')::date + 7),
    ((v.data_venda + interval '1 month')::date + 12),
    round((v.valor_venda * v.percentual_comissao * 0.5)::numeric, 2),
    'pago'::erp.status_titulo,
    v.id_consultor,
    v.id_imovel
  FROM erp.venda_imovel v
  WHERE v.data_venda BETWEEN v_inicio AND v_fim;

  -- 6.8) Contas a Pagar fixas mensais
  -- salários consultores
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.1.01'),
    'despesa_fixa'::erp.origem_titulo,
    'Folha - Consultores',
    m.mes,
    (m.mes + 5),
    (m.mes + 5),
    (v_salario_consultor * v_consultores),
    'pago'::erp.status_titulo,
    true
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- salário gerente
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.1.02'),
    'despesa_fixa'::erp.origem_titulo,
    'Folha - Gerente',
    m.mes,
    (m.mes + 5),
    (m.mes + 5),
    v_salario_gerente,
    'pago'::erp.status_titulo,
    true
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- pró-labore 2 sócios
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.1.03'),
    'despesa_fixa'::erp.origem_titulo,
    'Pró-labore Sócios',
    m.mes,
    (m.mes + 5),
    (m.mes + 5),
    (v_prolabore_socio * 2),
    'pago'::erp.status_titulo,
    true
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- aluguel escritório
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.2.01'),
    'despesa_fixa'::erp.origem_titulo,
    'Locador Escritório',
    m.mes,
    (m.mes + 3),
    (m.mes + 3),
    v_aluguel_escritorio,
    'pago'::erp.status_titulo,
    true
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- sistemas
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.2.02'),
    'despesa_fixa'::erp.origem_titulo,
    'SaaS / Sistemas',
    m.mes,
    (m.mes + 10),
    (m.mes + 10),
    v_sistemas,
    'pago'::erp.status_titulo,
    true
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- contabilidade
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.2.03'),
    'despesa_fixa'::erp.origem_titulo,
    'Escritório Contábil',
    m.mes,
    (m.mes + 12),
    (m.mes + 12),
    v_contabilidade,
    'pago'::erp.status_titulo,
    true
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- 6.9) Despesas variáveis (marketing) por mês (random em faixa)
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.3.01'),
    'despesa_variavel'::erp.origem_titulo,
    'Marketing / Tráfego',
    m.mes,
    (m.mes + 15),
    (m.mes + 15),
    round((1500 + random()*3500)::numeric, 2),
    'pago'::erp.status_titulo,
    false
  FROM (SELECT date_trunc('month', d)::date AS mes FROM generate_series(v_inicio, v_fim, interval '1 month') d) m;

  -- 6.10) Impostos simulados (percentual sobre receita do mês, calculado e lançado como conta a pagar)
  INSERT INTO erp.conta_pagar (id_conta, origem, fornecedor, data_emissao, data_vencimento, data_pagamento, valor, status, recorrente)
  SELECT
    (SELECT id_conta FROM erp.plano_contas WHERE codigo='4.9.01'),
    'imposto'::erp.origem_titulo,
    'Impostos',
    m.mes,
    (m.mes + 20),
    (m.mes + 20),
    round((receita_mes * v_taxa_imposto)::numeric, 2),
    'pago'::erp.status_titulo,
    false
  FROM (
    SELECT date_trunc('month', d)::date AS mes
    FROM generate_series(v_inicio, v_fim, interval '1 month') d
  ) m
  JOIN LATERAL (
    SELECT COALESCE(SUM(ar.valor),0) AS receita_mes
    FROM erp.conta_receber ar
    JOIN erp.plano_contas pc ON pc.id_conta = ar.id_conta
    WHERE pc.tipo='receita'
      AND ar.data_emissao >= m.mes
      AND ar.data_emissao < (m.mes + interval '1 month')::date
  ) r ON true;

END $$;

-- 7) Camada BI: fato_financeiro (union AR/AP) e DRE mensal

CREATE OR REPLACE VIEW erp.fato_financeiro AS
SELECT
  ar.data_emissao AS data_lancamento,
  ar.data_pagamento AS data_baixa,
  ar.valor AS valor,
  pc.tipo,
  pc.categoria,
  pc.codigo,
  pc.descricao,
  'AR'::text AS origem_sistema,
  ar.origem::text AS origem_negocio,
  ar.id_pessoa,
  ar.id_imovel
FROM erp.conta_receber ar
JOIN erp.plano_contas pc ON pc.id_conta = ar.id_conta

UNION ALL

SELECT
  ap.data_emissao AS data_lancamento,
  ap.data_pagamento AS data_baixa,
  (ap.valor * -1) AS valor, -- despesas negativas para facilitar DRE
  pc.tipo,
  pc.categoria,
  pc.codigo,
  pc.descricao,
  'AP'::text AS origem_sistema,
  ap.origem::text AS origem_negocio,
  NULL::bigint AS id_pessoa,
  NULL::bigint AS id_imovel
FROM erp.conta_pagar ap
JOIN erp.plano_contas pc ON pc.id_conta = ap.id_conta;

CREATE OR REPLACE VIEW erp.dre_mensal AS
SELECT
  date_trunc('month', data_lancamento)::date AS mes,
  SUM(CASE WHEN tipo='receita' THEN valor ELSE 0 END) AS receita,
  SUM(CASE WHEN tipo='despesa' THEN -valor ELSE 0 END) AS despesa, -- volta despesas para positivo aqui
  SUM(valor) AS resultado_liquido
FROM erp.fato_financeiro
GROUP BY 1
ORDER BY 1;

COMMIT;

-- Consultas rápidas:
-- SELECT * FROM erp.dre_mensal;
-- SELECT mes, receita, despesa, resultado_liquido FROM erp.dre_mensal;
-- SELECT * FROM erp.fato_financeiro LIMIT 50;
