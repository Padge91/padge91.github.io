---
layout: post
title: 'Terraform'
date: '2022-07-16'
categories: 'general'
---


Terraform is pretty sweet, let's you organize your environments into code, and manage them from code. It's pretty nice because it also is a form of self-documentation (albeit not perfect).

# Secrets & Passwords

You shouldn't know any secrets or passwords being pumped into your stack, but I found a way to make secrets.

{% highlight bash %}

resource "random_password" "db_password" {
  length  = 60
  special = false
}

resource "random_password" "redis_password" {
  length  = 128
  special = false
}

resource "random_password" "session_secret" {
  length  = 128
  special = false
}

{% endhighlight %}

You can then put these in AWS secret manager like so:

{% highlight bash %}

locals {
    secrets_map = {
        db_password = random_password.db_password
        redis_password = random_password.redis_password
        session_secret = random_password.session_secret
    }
}

resource "aws_secretsmanager_secret" "secrets" {
  name                    = "secrets"
  recovery_window_in_days = var.deletion_protection ? 30 : 0
  description             = "secrets"

  depends_on = [aws_db_instance.example]

  tags = {
    Name   = "secrets"
  }

}

resource "aws_secretsmanager_secret_version" "secrets" {
  secret_id     = aws_secretsmanager_secret.secrets.id
  secret_string = jsonencode(local.secrets_map)
}

{% endhighlight %}

You'll then probably want these secrets backed up also:

{% highlight bash %}

resource "local_file" "secrets_backup" {
  content  = jsonencode(local.secrets_map)
  filename = "out/secrets.json"
}

{% endhighlight %}

# Bastion instance

We should use a public instance to connect to the private services, so the services aren't open publicly. It's not all that bad

First, we need to create a key to connect to the instance:

{% highlight bash %}

resource "tls_private_key" "pk" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


resource "aws_key_pair" "bation" {
  key_name   = "bastion.pem"
  public_key = tls_private_key.pk.public_key_openssh
}

{% endhighlight %}

Then, we can create the instance

{% highlight bash %}

resource "aws_instance" "bastion" {
  subnet_id        = aws_subnet.subnet.id
  instance_type    = "t2.nano"
  ami              = "" \# use an AMI or ephemeral instance to use a stock AMI
  user_data_base64 = "" \# path to user data script to bootstrap the instance

  vpc_security_group_ids      = []
  key_name                    = aws_key_pair.bastion.key_name
  associate_public_ip_address = true

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "2"
    delete_on_termination = "true"
  }

  tags = {
    Name   = "Bastion"
  }

  lifecycle {
    ignore_changes = [instance_state]
  }
}

{% endhighlight %}

# Database Bootstrapping

I also ran into trouble on how to bootstrap a database automatically. I want the database to be provisioned, and then run some SQL automatically. It's possible with the below configuration

{% highlight bash %}

resource "aws_db_instance" "main" {
  username   = "postgres"
  password   = random_password.db_password.result
  identifier = "example"

  allocated_storage                     = 200
  engine                                = "postgres"
  engine_version                        = "10.18"
  instance_class                        = "db.t3.medium
  parameter_group_name                  = "default.postgres10"
  multi_az                              = true
  allow_major_version_upgrade           = true
  auto_minor_version_upgrade            = false
  db_subnet_group_name                  = aws_db_subnet_group.db_subnet.name
  backup_retention_period               = 7
  vpc_security_group_ids                = [aws_security_group.database.id]
  deletion_protection                   = true
  storage_encrypted                     = true
  monitoring_interval                   = 0
  apply_immediately                     = true
  performance_insights_enabled          = true
  performance_insights_retention_period = 7 # 7 days is free

  publicly_accessible = false

  skip_final_snapshot       = false
  final_snapshot_identifier = "example-final-snapshot"
  copy_tags_to_snapshot     = true

  maintenance_window = "sat:01:30-sat:02:00"
  backup_window      = "00:00-01:00"

  tags = {
    Name   = "database"
  }
}


{% endhighlight %}

What do we want to run? These sql files that are formatted as terraform templates.

{% highlight bash %}

\# db.tpl
create database ${DB_NAME} owner ${OWNER} tablespace default allow_connections true connection limit -1;

\# schema.tpl
create schema ${SCHEMA_NAME};

\# db_users.tpl
create user ${MAIN_USERNAME} with password '${MAIN_PASSWORD}';

\# template script we need to run run_all.sh.tpl
sudo apt-get update -y
sudo apt-get install postgresql-client-common postgresql-client-10 -y

export PGPASSWORD="${PASSWORD}"

# db
psql -h "${ADDRESS}" -p "${PORT}" -U "${USERNAME}" -d postgres -c "${DB_COMMAND}"

# schema
psql -h "${ADDRESS}" -p "${PORT}" -U "${USERNAME}" -d "${DATABASE}" -c "${SCHEMA_COMMAND}"

# users
psql -h "${ADDRESS}" -p "${PORT}" -U "${USERNAME}" -d "${DATABASE}" -c "${USERS_COMMAND}"

# tables
psql -h "${ADDRESS}" -p "${PORT}" -U "${USERNAME}" -d "${DATABASE}" -f "/tmp/db_tables.sql"


{% endhighlight %}

How do we run it? Like so

{% highlight bash %}

locals {
  db_name           = "db"
  schema_name       = "schema"
  username          = "user"

  db = templatefile("${path.cwd}/postgres/db.tpl", {
    DB_NAME = "${local.db_name}"
    OWNER   = "${aws_db_instance.main.username}"
  })

  schema = templatefile("${path.cwd}/postgres/schema.tpl", {
    SCHEMA_NAME = "${local.schema_name}"
  })

  db_users = templatefile("${path.cwd}/postgres/db_users.tpl", {
    MAIN_USERNAME     = "${local.username}"
    MAIN)PASSWORD     = "${random_password.db.value}
  })

  db_tables = templatefile("${var.database_tables_script}", {})


  bootstrap_script = templatefile("${path.cwd}/postgres/run_all.sh.tpl", {
    ADDRESS             = "${aws_db_instance.main.address}"
    PORT                = "${aws_db_instance.main.port}"
    USERNAME            = "${aws_db_instance.main.username}"
    PASSWORD            = "${aws_db_instance.main.password}"
    DATABASE            = "${local.db_name}"
    DB_COMMAND          = "${local.db}"
    SCHEMA_COMMAND      = "${local.schema}"
    USERS_COMMAND       = "${local.db_users}"
    TABLES_COMMAND      = "${local.db_tables}"
  })
}

{% endhighlight %}

Database is easy enough, but how do you get to it? You need to use that bastion instance.

{% highlight bash %}

resource "null_resource" "db_provision" {
  depends_on = [aws_db_instance.main, aws_instance.bastion]

  connection {
    type        = "ssh"
    host        = aws_instance.bastion.public_ip
    user        = "ubuntu"
    private_key = file("${path.cwd}/out/bastion.pem")
  }

  provisioner "file" {
    content     = local.db_bootstrap
    destination = "/tmp/db_bootstrap.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/db_bootstrap.sh",
      "/tmp/db_bootstrap.sh"
    ]
  }
}

{% endhighlight %}

In general, this will template the provided .tpl files into valid sql. We will then read these values into variables and execute these using another template.

The shell script does some bootstrapping so it will install the appropriate libs and then execute those commands.

We need a bastion instance because the db is not publicly available. So the db_provisioner will use SSH to connect to the bastion, install the depds, and run the scripts remotely. Awesome!

# Workspaces

How do I organize workspaces and/or different environments? I have two things: A) Workspace for each environment and B) a .tfvars file for each environment.

The tfvars file includes changes specific to an environment. E.G. for dev vs prod they have different DNS values and instance sizes. The WORKSPACE functionality in terraform just helps segregate the environments conceptually, so we don't need to duplicate terraform structures. 

Only weird part is, to apply or plan changes in an environment, you need to change the workspace to that environment, and then also apply using the correct tfvars file. This isn't so bad since terraform will warn you on how much will be created or destroyed.

This also means we can have one tfvars for each customer single-tenant environment. If we write it carefully enough, we can customize customer single-tenant environments by just using the .tfvars file.