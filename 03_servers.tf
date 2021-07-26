
//  instance port == 8080
//  why not getting to load balancer?
resource "aws_security_group" "basic" {
  name   = "basic"
  vpc_id = aws_vpc.test.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "basic-access"
  }

}


resource "aws_instance" "server_1" {
  ami               = var.ami
  instance_type     = var.instance_type
  availability_zone = var.availability_zones[0]
  subnet_id         = aws_subnet.subnet_a.id
  key_name          = "terraform"
  security_groups   = [aws_security_group.basic.id]


  connection {
    user        = "ec2-user"
    host        = self.public_ip
    private_key = file(var.key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo",
      "sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key",
      "sudo yum upgrade",
      "sudo yum install jenkins java-1.8.0-openjdk-devel -y",
      "sudo systemctl daemon-reload",
      "sudo systemctl start jenkins",
      "sudo systemctl status jenkins"
    ]
  }
  tags = {
    Name = "Server 1"
  }
}



resource "aws_elb" "test_load_balancer" {

  subnets         = [aws_subnet.subnet_a.id]
  security_groups = [aws_security_group.basic.id]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  listener {
    instance_port     = 8080
    instance_protocol = "http"
    lb_port           = 8080
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 30
  }


  instances                   = [aws_instance.server_1.id]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400


  tags = {
    Name = "load-balancer"
  }
}
