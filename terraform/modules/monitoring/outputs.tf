output "dashboard_url" {
  description = "CloudWatch Dashboard URL"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "log_group_names" {
  description = "CloudWatch log group names"
  value = {
    eks_cluster   = aws_cloudwatch_log_group.eks_cluster.name
    application   = aws_cloudwatch_log_group.application.name
  }
}
