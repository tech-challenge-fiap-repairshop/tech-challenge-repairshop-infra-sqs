# 📬 Tech Challenge RepairShop - Infra SQS (AWS SQS Messaging)

> **Repositório de Infraestrutura como Código (Terraform) para Mensageria Assíncrona**  
> **Tech Challenge SOAT (Fase 4)**  
> **Organização GitHub:** `tech-challenge-fiap-repairshop`

---

## 📌 Visão Geral

O repositório **`tech-challenge-repairshop-infra-sqs`** centraliza o provisionamento e ciclo de vida de infraestrutura em nuvem via **Terraform** para as filas de mensageria assíncrona **AWS SQS** e suas respectivas **Dead Letter Queues (DLQs)**.

Ele suporta a comunicação orientada a eventos desacoplada do **Saga Pattern** entre os microsserviços da Fase 4.

---

## 🏛️ Filas Provisionadas

| Fila Principal | Dead Letter Queue (DLQ) | Microsserviço Produtor | Microsserviço Consumidor | Propósito |
| :--- | :--- | :--- | :--- | :--- |
| `approve-notification-queue` | `approve-notification-queue-dlq` | `service_order_execution-service` | `notification-service` | Envio de orçamento para revisão do cliente |
| `callback-approve-notification-queue` | `callback-approve-notification-queue-dlq` | `notification-service` | `service_order_execution-service` | Retorno da decisão de aprovação/recusa do cliente |
| `os-ready-for-payment-queue` | `os-ready-for-payment-queue-dlq` | `service_order_execution-service` | `payment-service` | Despacho de ordens aprovadas para cobrança |
| `payment-notification-queue` | `payment-notification-queue-dlq` | `payment-service` | `notification-service` | Notificação de cobrança/recibo emitida |
| `payment-success-queue` | `payment-success-queue-dlq` | `payment-service` | `service_order_execution-service` | Liberação da OS para execução técnica após quitação |

---

## 📂 Estrutura de Diretórios

```
tech-challenge-repairshop-infra-sqs/
├── .github/workflows/         # Pipeline Terraform Plan & Apply (GitHub Actions)
├── infra/
│   ├── environments/          # dev.tfvars, hml.tfvars, prd.tfvars
│   ├── backend.tf             # Remote state S3 (bucket: fiap-repairshop2)
│   ├── main.tf                # 5 Filas SQS + 5 DLQs + Políticas de Redrive
│   ├── outputs.tf             # URLs e ARNs das filas
│   ├── providers.tf           # Configuração do AWS Provider
│   ├── variables.tf           # Parametrização por ambiente
│   └── versions.tf            # Versões mínimas requeridas
├── .gitignore
└── README.md
```

---

## 🚀 Como Aplicar Localmente

```bash
cd infra

# Inicializar Terraform
terraform init

# Validar configurações
terraform validate

# Planejar (dev)
terraform plan -var-file="environments/dev.tfvars"

# Aplicar (dev)
terraform apply -var-file="environments/dev.tfvars"
```

---

## 🛡️ Governança de Branches
- `main`: Branch de produção (protegida contra push direto).
- `homolog`: Branch de homologação.
- `develop`: Branch de desenvolvimento ativo.
- `feat/*`, `fix/*`, `chore/*`: Branches de trabalho.
