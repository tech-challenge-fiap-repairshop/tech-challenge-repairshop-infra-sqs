# 📨🔁 Repair Shop — Infra Amazon SQS & Dead Letter Queues (`infra-sqs`)

[![CI/CD Pipeline](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-sqs/actions/workflows/ci-cd-sqs.yml/badge.svg)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-sqs/actions/workflows/ci-cd-sqs.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.8.5-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Amazon SQS](https://img.shields.io/badge/Amazon-SQS%20%2B%20DLQ-FF4F8B?logo=amazonsqs&logoColor=white)](https://aws.amazon.com/sqs/)

Repositório de **Infraestrutura como Código (Terraform)** que provisiona todas as filas **Amazon SQS** e suas respectivas **Dead Letter Queues (DLQs)** da plataforma **Repair Shop (Tech Challenge FIAP — 15SOAT)**, sustentando a **Saga Coreografada** assíncrona entre Execução de Ordens de Serviço, Pagamentos e Notificações com criptografia gerenciada e Redrive Policy.

---

## 📋 Índice

- [Filas Provisionadas, DLQs e Redrive Policy](#filas-provisionadas-dlqs-e-redrive-policy)
- [Arquitetura Atual — Motivação e Benefícios dos Componentes](#arquitetura-atual--motivação-e-benefícios-dos-componentes)
- [Por que DynamoDB em vez de Banco Relacional nos Serviços Conectados ao SQS?](#por-que-dynamodb-em-vez-de-banco-relacional-nos-serviços-conectados-ao-sqs)
- [Como Executar e Validar Localmente (Terraform)](#como-executar-e-validar-localmente-terraform)
- [Como Executar em Produção (Esteira CI/CD GitHub Actions)](#como-executar-em-produção-esteira-cicd-github-actions)
- [Documentação Técnica e Collection do Postman](#documentação-técnica-e-collection-do-postman)

---

## Filas Provisionadas, DLQs e Redrive Policy

Conforme [`infra/main.tf`](infra/main.tf), [`infra/variables.tf`](infra/variables.tf) e `infra/environments/{dev,hml,prd}.tfvars`, cada fluxo recebe **1 fila principal** pareada com **1 DLQ (`-dlq-{env}`)**:

| Fila (`-{env}`) | DLQ Pareada (`-{env}`) | Produtor | Consumidor | Papel na Saga |
| :--- | :--- | :--- | :--- | :--- |
| `approve-notification-queue` | `approve-notification-queue-dlq` | `service-order` | `notification` | Solicita aprovação de orçamento/tarefas extras ao cliente. |
| `callback-approve-notification-queue` | `callback-approve-notification-queue-dlq` | `notification` | `service-order` | Entrega a decisão (`approved`/`reason`) para avançar a OS. |
| `os-ready-for-payment-queue` | `os-ready-for-payment-queue-dlq` | `service-order` | `payment` | Dispara geração de cobrança ao finalizar a OS. |
| `payment-notification-queue` | `payment-notification-queue-dlq` | `payment` | `notification` | Solicita envio de e-mail de aprovação/recusa de pagamento. |
| `payment-success-queue` | `payment-success-queue-dlq` | `payment` | `service-order` | Confirma quitação para transicionar a OS para **`PAID`**. |

### Parâmetros de Resiliência e Segurança
- **Criptografia**: `sqs_managed_sse_enabled = true` em todas as 10 filas (principais e DLQs).
- **Visibility Timeout**: `60s` para processamento seguro sem reentrega prematura.
- **Retenção de Mensagens**:
  - Filas principais: **`86400s` (1 dia)** em `dev`/`hml` e **`345600s` (4 dias)** em `prd`.
  - Dead Letter Queues (`-dlq`): **`1209600s` (14 dias)** em todos os ambientes para análise e reprocessamento pós-incidente.
- **Redrive Policy (`maxReceiveCount`)**: **`3`** tentativas em `dev`/`hml` e **`5`** tentativas em `prd` antes do redirecionamento automático à DLQ.
- **Observabilidade distribuída**: Os microsserviços utilizam `SqsListenerHealthIndicator` nas *liveness probes* do EKS e propagam `traceparent` nos `MessageAttributes` de cada mensagem.

---

## Arquitetura Atual — Motivação e Benefícios dos Componentes

| Pilar / Tecnologia | Papel no Ecossistema | Motivação Técnica e Pontos Positivos |
| :--- | :--- | :--- |
| **RDS (PostgreSQL 16)** | Base cadastral no [`app-register-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-register-service) ([`infra-db-rds`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-rds)) | Mantido exclusivo para o domínio relacional de Clientes, Veículos e Usuários (`ACID`, FK e `UNIQUE`), evitando mistura com eventos assíncronos da Saga. |
| **DynamoDB (NoSQL)** | Persistência de OS e Pagamentos ([`infra-db-dynamo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-dynamo)) | Alimenta os despachos para as filas SQS via GSIs (`pending-dispatch-index`, `dispatch-notification-index`) com escala `PAY_PER_REQUEST` e atomicidade em `TransactWriteItems`. |
| **ElastiCache (Redis 7.0)** | Cache em memória ([`infra-redis`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-redis)) | Provisionado em sub-rede privada (`6379`) para suportar cache de login/sessão do `register-service` sem interferir nas filas da Saga. |
| **Apps (EKS + Lambda Auth)** | Microsserviços **EKS (`1.31`)** ([`infra-eks`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-eks)) + [`lambda-auth`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-lambda-auth) | Cada microsserviço no EKS atua como produtor/consumidor independente das filas com HPA, enquanto o `lambda-auth` garante login *serverless* elástico na borda. |
| **Amazon SQS (Mensageria + DLQ)** | **Camada provisionada por este repositório** | Substitui chamadas HTTP síncronas frágeis por **acoplamento frouxo**, oferece *buffering* durável contra picos e isola mensagens problemáticas nas **DLQs** em vez de perder transações ou travar threads. |
| **API Gateway (HTTP API v2)** | Borda única ([`infra-apigateway`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-apigateway)) | Expõe endpoints REST (inclusive callback `/notifications/approval/{orderId}` que publica direto no SQS), propagando cabeçalhos W3C no CORS. |
| **Observabilidade (Grafana)** | OpenTelemetry + Prometheus + Loki + Jaeger + Grafana | A propagação do `traceparent` via atributos SQS garante que uma transação HTTP apareça conectada ao consumidor assíncrono e ao envio de e-mail dentro do Jaeger e nos 11 dashboards Grafana. |

---

## Por que DynamoDB em vez de Banco Relacional nos Serviços Conectados ao SQS?

Os produtores e consumidores que interagem diretamente com estas filas SQS (`service-order-execution-service` e `payment-service`) utilizam **DynamoDB** e **não** banco relacional por razões críticas de arquitetura distribuída:

1. **Concorrência paralela sem exaustão de pool JDBC**: Consumidores SQS escalados em múltiplas réplicas no EKS (HPA) + webhooks simultâneos facilmente esgotariam conexões TCP em uma instância RDS (`db.t3.micro`). O DynamoDB opera por chamadas HTTPS *stateless* sem limite de pool de conexões.
2. **Despacho orientado por GSIs sem `SCAN`**: Os agendadores e despachantes consultam diretamente `pending-dispatch-index` e `dispatch-notification-index` antes de publicar no SQS, evitando `JOIN`s complexos e *locks* em tabelas relacionais.
3. **Agregados evolutivos e consistência transacional local**: Registros polimórficos (`ORDER#<id>`, `BILLING#<serviceOrderId>`) evoluem sem bloqueios DDL (`ALTER TABLE`) e usam `TransactWriteItems` para consistência atômica do agregado.

---

## Como Executar e Validar Localmente (Terraform)

> **Pré-requisitos**: **Terraform `1.8.5`**, **AWS CLI v2** autenticado (ou **LocalStack** para simular filas SQS nos `docker-compose.yml` dos microsserviços).

```bash
cd infra

# Inicializar com state remoto no S3 (ex.: dev)
terraform init \
  -backend-config="bucket=SEU_BUCKET_TERRAFORM_STATE" \
  -backend-config="key=sqs/dev.tfstate" \
  -backend-config="region=us-east-1"

terraform fmt -check -recursive
terraform validate
terraform plan -var-file="environments/dev.tfvars"
```

Para validar sintaxe localmente sem S3:
```bash
cd infra
terraform init -backend=false
terraform validate
```

---

## Como Executar em Produção (Esteira CI/CD GitHub Actions)

Definida em [`.github/workflows/ci-cd-sqs.yml`](.github/workflows/ci-cd-sqs.yml) e destruição controlada em [`.github/workflows/destroy.yml`](.github/workflows/destroy.yml).

### Mapeamento de Ambientes
- `develop` -> **`dev`** (`infra/environments/dev.tfvars`)
- `homolog` -> **`hml`** (`infra/environments/hml.tfvars`)
- `main` -> **`prd`** (`infra/environments/prd.tfvars`)

### Etapas da Esteira
1. `terraform fmt -check` e `terraform validate`.
2. `terraform init` com backend S3 `sqs/${ENV}.tfstate` no bucket `AWS_TERRAFORM_STATE_BUCKET`.
3. `terraform plan -var-file="environments/${ENV}.tfvars"`.
4. `terraform apply -auto-approve` em push para `develop`, `homolog` e `main`.

> **Posição na Ordem de Provisionamento**: Pode ser executado logo após `infra-network` (em paralelo aos bancos) e **obrigatoriamente antes** dos microsserviços `app-service-order-execution-service`, `app-payment-service` e `app-notification-service`.

---

## Documentação Técnica e Collection do Postman

- **Arquivos Terraform deste Repositório**: [`infra/main.tf`](infra/main.tf) | [`infra/variables.tf`](infra/variables.tf) | [`infra/environments/dev.tfvars`](infra/environments/dev.tfvars) | [`infra/environments/prd.tfvars`](infra/environments/prd.tfvars)
- **Consumidores e Produtores na Organização**:
  - [`app-service-order-execution-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service)
  - [`app-payment-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-payment-service)
  - [`app-notification-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-notification-service)
- **ADRs, RFCs e Diagramas**:
  - [ADRs (`ADR-001` a `ADR-013`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/ADRs/README.md)
  - [RFCs (`RFC-001` a `RFC-014`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/RFCs/README.md)
  - [`Diagrama de Infraestrutura Cloud`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/delivery/infrastructure/repairshop-diagrama-infra-cloud.svg)
- **Postman Collections & Environments (Organização)**:
  - Collection Principal: [`Repair Shop (Tech Challenge FIAP)`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Repair%20Shop%20%28Tech%20Challenge%20FIAP%29.postman_collection.json)
  - Collection Completa: [`Tech Challenge FIAP - Completo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Tech_Challenge_Fiap_-_Completo.postman_collection.json)
  - Environment Local: [`Local.postman_environment.json`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Local.postman_environment.json)
  - Guia do Postman: [`docs/postman/README.md`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/README.md)
- **Dashboards Grafana (11 JSONs)**: [`dashboards/`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/tree/main/local/observability/grafana/dashboards)
