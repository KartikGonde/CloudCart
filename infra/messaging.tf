# Module 8: order events fan out from SNS to email and an SQS shipping queue

resource "aws_sns_topic" "order_events" {
  name         = "${local.name}-order-events"
  display_name = "eCommerce Order Events"
}

resource "aws_sqs_queue" "order_shipping" {
  name                    = "${local.name}-order-shipping"
  sqs_managed_sse_enabled = true
}

resource "aws_sqs_queue_policy" "order_shipping" {
  queue_url = aws_sqs_queue.order_shipping.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sns.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.order_shipping.arn
      Condition = {
        ArnEquals = { "aws:SourceArn" = aws_sns_topic.order_events.arn }
      }
    }]
  })
}

resource "aws_sns_topic_subscription" "shipping_queue" {
  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.order_shipping.arn

  depends_on = [aws_sqs_queue_policy.order_shipping]
}

# Stays "pending confirmation" until the recipient clicks the link AWS emails them
resource "aws_sns_topic_subscription" "email" {
  count = var.notification_email == "" ? 0 : 1

  topic_arn = aws_sns_topic.order_events.arn
  protocol  = "email"
  endpoint  = var.notification_email
}
