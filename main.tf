provider "aws"{
  access_key= "${var.aws_access_key}"
  secret_key= "${var.aws_secret_key}"
  region= "${var.aws_region}"
}

resource "aws_vpc" "vpc-id"{
  cidr_block = "10.0.0.0/16"
  
  tags={
    Name="vpc-tf"
  }
}

resource "aws_subnet" "Public_subnet1"{
  vpc_id= "${aws_vpc.vpc-id.id}"
  cidr_block= "10.0.1.0/24"
  availability_zone= "ap-south-1a"
  map_public_ip_on_launch= "true"

  tags= {
    Name= "Public_subnet_tf1"
  }
}

resource "aws_subnet" "Public_subnet2"{
  vpc_id= "${aws_vpc.vpc-id.id}"
  cidr_block= "10.0.2.0/24"
  availability_zone= "ap-south-1b"
  map_public_ip_on_launch= "true"

  tags= {
    Name= "Public_subnet_tf2"
  }
}

resource "aws_subnet" "Private_subnet1"{
  vpc_id= "${aws_vpc.vpc-id.id}"
  cidr_block= "10.0.3.0/24"
  availability_zone= "ap-south-1b"
  map_public_ip_on_launch= "false"

  tags= {
    Name= "Private_subnet_tf1"
  }
}

resource "aws_subnet" "Private_subnet2"{
  vpc_id= "${aws_vpc.vpc-id.id}"
  cidr_block= "10.0.4.0/24"
  availability_zone= "ap-south-1a"
  map_public_ip_on_launch= "false"

  tags= {
    Name= "Private_subnet_tf2"
  }
}

resource "aws_internet_gateway" "IGW"{
  vpc_id= "${aws_vpc.vpc-id.id}"
  
  tags={
    Name="IGW-Tf"
  }
}



resource "aws_route_table" "route_table" {
  vpc_id= "${aws_vpc.vpc-id.id}"
 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id= "${aws_internet_gateway.IGW.id}"
  }

  tags= {
    Name="routetable-Tf1"
  }

}


resource "aws_route_table_association" "public_subnet_1"{
  subnet_id= "${aws_subnet.Public_subnet1.id}"
  route_table_id= "${aws_route_table.route_table.id}"
}

resource "aws_route_table_association" "public_subnet_2"{
  subnet_id= "${aws_subnet.Public_subnet2.id}"
  route_table_id= "${aws_route_table.route_table.id}"
}

resource "aws_security_group" "vpc_sg"{
  name= "vpc_sg"
  description= "Allow Inbound traffic"
  vpc_id= "${aws_vpc.vpc-id.id}"

  ingress {
  
    from_port = 22
    to_port= 22
    protocol= "tcp"
    cidr_blocks= ["114.79.180.62/32"]
  }
   ingress {

    from_port = 5432
    to_port= 5432
    protocol= "tcp"
    cidr_blocks= ["0.0.0.0/0"]
  }

  ingress {
  
    from_port = 80
    to_port= 80
    protocol= "tcp"
    cidr_blocks= ["0.0.0.0/0"]
  }

  ingress {
  
    from_port = 25
    to_port= 25
    protocol= "tcp"
    cidr_blocks= ["0.0.0.0/0"]
  }

  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags= {
    Name= "VPC_SG"
  }
}

resource "aws_elb" "lb-tf" {
  name = "lb-tf"
  listener {
    instance_port = 80
    instance_protocol= "http"
    lb_port = 80
    lb_protocol= "http"
  }
  
  health_check {
    healthy_threshold = 3
    unhealthy_threshold = 3
    timeout = 5
    target = "HTTP:80/"
    interval = 30
  }
  security_groups = ["${aws_security_group.vpc_sg.id}"]
    subnets = [
      "${aws_subnet.Public_subnet1.id}",
      "${aws_subnet.Public_subnet2.id}",
    ]
  tags = {
    Name = "LoadBalancer_Tf"
  }
}
 
data "aws_iam_role" "iam_role" {
  name= "EC2-Fullaccess"
}


resource "aws_launch_configuration" "lc-tf" {
  
  image_id = "ami-03e03b67c4e7c015d"
  instance_type= "t2.micro"
  key_name = "instance"
  security_groups= ["${aws_security_group.vpc_sg.id}"] 
  iam_instance_profile = "${data.aws_iam_role.iam_role.id}"
}

resource "aws_autoscaling_group" "asg-tf" {
  launch_configuration = "${aws_launch_configuration.lc-tf.id}"
  max_size= 5
  min_size= 2
  health_check_grace_period= 300
  health_check_type = "ELB"
  desired_capacity = 2
  default_cooldown= 120
  name = "asg-TF"
  load_balancers = ["${aws_elb.lb-tf.name}"]
  vpc_zone_identifier = [
    "${aws_subnet.Public_subnet1.id}",
    "${aws_subnet.Public_subnet2.id}"
  ]
  tag {
    key                 = "Name"
    value               = "chatapp-tf"
    propagate_at_launch = true
  }
}  

resource "aws_autoscaling_policy" "asg_policy" {
  name= "asg_policy"
  autoscaling_group_name = "${aws_autoscaling_group.asg-tf.name}"
  adjustment_type        = "ChangeInCapacity"
  policy_type= "StepScaling"
  metric_aggregation_type= "Average"
  estimated_instance_warmup = 120
  step_adjustment {
  scaling_adjustment          = 1
  metric_interval_lower_bound = 40
  metric_interval_upper_bound = 60
  }
  step_adjustment {
  scaling_adjustment          = 1
  metric_interval_lower_bound = 60
  metric_interval_upper_bound = 80 
  }
  step_adjustment {
  scaling_adjustment          = 1
  metric_interval_lower_bound = 80
  metric_interval_upper_bound = null
  }

}

resource "aws_autoscaling_policy" "asg_policy1" {
  name= "asg_policy1"
  autoscaling_group_name = "${aws_autoscaling_group.asg-tf.name}"
  adjustment_type        = "ChangeInCapacity"
  policy_type= "StepScaling"
  metric_aggregation_type= "Average"
  step_adjustment {
  scaling_adjustment          = -1
  metric_interval_lower_bound = 35
  metric_interval_upper_bound = 55
  }
  step_adjustment {
  scaling_adjustment          = -1
  metric_interval_lower_bound = 55
  metric_interval_upper_bound = 75 
  }
  step_adjustment {
  scaling_adjustment          = -1
  metric_interval_lower_bound = 75
  metric_interval_upper_bound = null
  }

}

resource "aws_security_group" "db-sg" {
  name = "rds_sg"
  vpc_id= "${aws_vpc.vpc-id.id}"
  ingress {
    from_port= 5432
    to_port= 5432
    protocol= "tcp"
    cidr_blocks= ["10.0.0.0/16"]   
  }
  egress {
    from_port = "0"
    to_port = "0"
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags= {
    Name= "db-sg-tf"
  }
}

resource "aws_db_subnet_group" "db-subnet-tf" {
  name = "db-subnet-tf"
  subnet_ids= ["${aws_subnet.Private_subnet1.id}", "${aws_subnet.Private_subnet2.id}"]

  tags= {
    Name= "Db subnet group"
  }

}

resource "aws_db_instance" "db_instance" {
  allocated_storage = "${var.db_size}"
  engine = "postgres"
  engine_version= "11.5"
  instance_class= "db.t2.micro"
  name= "${var.db_name}"
  username= "${var.db_user_name}"
  password= "${var.db_password}"
  db_subnet_group_name= "${aws_db_subnet_group.db-subnet-tf.id}"
  identifier= "chatapptf"
  vpc_security_group_ids= ["${aws_security_group.db-sg.id}"]
  skip_final_snapshot = true
  tags= {
    Name= "chatapp-db-tf"
  }
}


resource "aws_codedeploy_app" "chatapp-tf" {
  compute_platform = "Server"
  name= "${var.application_name}"
}

resource "aws_codedeploy_deployment_group" "chatapp-dep-tf" {
  app_name = "${aws_codedeploy_app.chatapp-tf.name}"
  deployment_group_name= "chatapp-tf"
  service_role_arn= "arn:aws:iam::261328727219:role/CodeDeployServiceRole"
 
  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type = "IN_PLACE"
  }
  deployment_config_name= "CodeDeployDefault.AllAtOnce"
  autoscaling_groups= ["${aws_autoscaling_group.asg-tf.name}"]
  load_balancer_info {
    elb_info {
      name= "${aws_elb.lb-tf.name}"
    }
  }

}
