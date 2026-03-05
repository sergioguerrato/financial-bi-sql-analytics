select
  id_contrato,
  id_cliente,
  id_imovel,
  id_consultor,
  data_inicio,
  data_fim,
  valor_aluguel,
  taxa_administracao,
  status,
  criado_em
from {{ source('erp', 'contrato_locacao') }}
