aws_region                 = "us-east-1"
environment                = "prd"
max_receive_count          = 5
visibility_timeout_seconds = 60
message_retention_seconds  = 345600 # 4 dias em producao
dlq_retention_seconds      = 1209600 # 14 dias
