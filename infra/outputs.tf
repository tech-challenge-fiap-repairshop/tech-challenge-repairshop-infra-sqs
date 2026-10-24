output "queue_urls" {
  description = "URLs das filas SQS principais"
  value       = { for k, q in aws_sqs_queue.main : k => q.url }
}

output "queue_arns" {
  description = "ARNs das filas SQS principais"
  value       = { for k, q in aws_sqs_queue.main : k => q.arn }
}

output "dlq_urls" {
  description = "URLs das Dead Letter Queues (DLQs)"
  value       = { for k, q in aws_sqs_queue.dlq : k => q.url }
}

output "dlq_arns" {
  description = "ARNs das Dead Letter Queues (DLQs)"
  value       = { for k, q in aws_sqs_queue.dlq : k => q.arn }
}
