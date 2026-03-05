select
  id_titulo,
  id_conta,
  origem,
  fornecedor,
  data_emissao,
  data_vencimento,
  data_pagamento,
  valor,
  status,
  recorrente
from {{ source('erp', 'conta_pagar') }}
