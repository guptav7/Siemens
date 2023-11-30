resource "aws_lb_listener_certificate" "example" {
  listener_arn    = aws_lb_listener.example.arn
  certificate_arn = "your-imported-certificate-arn"  # Replace with the ACM certificate ARN
}

resource "aws_route53_zone" "example" {
  name              = "test.example.com"
  private_zone      = true
  vpc_id            = module.vpc.vpc_id
  tags              = { Name = "example-private-hosted-zone" }
}


resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.example.id
  name    = "www"
  type    = "A"

  alias {
    name                   = module.alb.dns_name
    zone_id                = module.alb.dns_name
    evaluate_target_health = true
  }
}