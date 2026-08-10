resource "aws_route53_zone" "main" {
  name = "fault-lens-penina.pp.ua"
  tags = {
    Name = "fault-lens-penina.pp.ua"
  }
}

resource "aws_route53_record" "chat" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "chat.fault-lens-penina.pp.ua"
  type    = "A"
  ttl     = 300
  records = [var.bastion_public_ip]
}

resource "aws_route53_record" "grafana" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "grafana.fault-lens-penina.pp.ua"
  type    = "A"
  ttl     = 300
  records = [var.bastion_public_ip]
}