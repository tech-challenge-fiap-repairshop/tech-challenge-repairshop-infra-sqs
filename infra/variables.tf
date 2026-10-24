variable "aws_region" {
  description = "Região da AWS para provisionamento"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de execução (dev, hml, prd)"
  type        = string
  default     = "dev"
}

variable "max_receive_count" {
  description = "Quantidade máxima de tentativas de recebimento antes de enviar para a DLQ"
  type        = number
  default     = 3
}

variable "visibility_timeout_seconds" {
  description = "Tempo de visibilidade da mensagem em segundos"
  type        = number
  default     = 60
}

variable "message_retention_seconds" {
  description = "Tempo de retenção de mensagens na fila principal (em segundos)"
  type        = number
  default     = 86400 # 1 dia
}

variable "dlq_retention_seconds" {
  description = "Tempo de retenção de mensagens na DLQ (em segundos)"
  type        = number
  default     = 1209600 # 14 dias
}
