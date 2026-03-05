select
  id_titulo,
  id_conta,
  origem,
  id_referencia,
  data_emissao,
  data_vencimento,
  data_pagamento,
  valor,
  status,
  id_pessoa,
  id_imovel
from {{ source('erp', 'conta_receber') }}
