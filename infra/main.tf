locals {
  queues = {
    approve_notification = {
      name = "approve-notification-queue"
    }
    callback_approve_notification = {
      name = "callback-approve-notification-queue"
    }
    os_ready_for_payment = {
      name = "os-ready-for-payment-queue"
    }
    payment_notification = {
      name = "payment-notification-queue"
    }
    payment_success = {
      name = "payment-success-queue"
    }
  }
}

# -----------------------------------------------------------------------------
# Dead Letter Queues (DLQs)
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "dlq" {
  for_each = locals.queues

  name                      = "${each.value.name}-dlq-${var.environment}"
  message_retention_seconds = var.dlq_retention_seconds
  sqs_managed_sse_enabled   = true

  tags = {
    Name = "${each.value.name}-dlq-${var.environment}"
    Type = "DeadLetterQueue"
  }
}

# -----------------------------------------------------------------------------
# Main SQS Queues
# -----------------------------------------------------------------------------
resource "aws_sqs_queue" "main" {
  for_each = locals.queues

  name                       = "${each.value.name}-${var.environment}"
  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  sqs_managed_sse_enabled    = true

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = var.max_receive_count
  })

  tags = {
    Name = "${each.value.name}-${var.environment}"
    Type = "StandardQueue"
  }
}
