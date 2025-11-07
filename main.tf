terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  tags = {
    Project = var.project_tag
  }
}

######################################
# S3 BUCKETS
######################################

# Use for_each to modularize
resource "aws_s3_bucket" "this" {
  for_each = toset(["raw", "iceberg", "athena_results"])
  bucket   = "${var.project_tag}-${replace(each.key, "_", "-")}-bucket"
  tags     = local.tags
}


# Common security config for all buckets
resource "aws_s3_bucket_public_access_block" "this" {
  for_each = aws_s3_bucket.this
  bucket                  = each.value.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = aws_s3_bucket.this
  bucket = each.value.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = aws_s3_bucket.this
  bucket = each.value.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

######################################
# GLUE DATABASE
######################################

resource "aws_glue_catalog_database" "this" {
  name = var.glue_db_name
}

######################################
# IAM ROLE FOR GLUE
######################################

data "aws_iam_policy_document" "glue_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["glue.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "glue_role" {
  name               = "${var.project_tag}-glue-role"
  assume_role_policy = data.aws_iam_policy_document.glue_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "glue_policy_doc" {
  statement {
    sid     = "S3Access"
    actions = [
      "s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"
    ]
    resources = flatten([
      [for b in aws_s3_bucket.this : b.arn],
      [for b in aws_s3_bucket.this : "${b.arn}/*"]
    ])
  }

  statement {
    sid     = "GlueAccess"
    actions = ["glue:*"]
    resources = ["*"]
  }

  statement {
    sid     = "Logs"
    actions = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}
# creating the custom inline policy
resource "aws_iam_policy" "glue_inline" {
  name   = "${var.project_tag}-glue-inline"
  policy = data.aws_iam_policy_document.glue_policy_doc.json
}
#Attach the custom policy to the glue role
resource "aws_iam_role_policy_attachment" "glue_inline_attach" {
  role       = aws_iam_role.glue_role.name
  policy_arn = aws_iam_policy.glue_inline.arn
}
# Attach AWS's managed glue service role policy
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

######################################
# GLUE JOB
######################################

resource "aws_s3_object" "glue_script" {
  bucket       = aws_s3_bucket.this["raw"].id
  key          = "scripts/glue_job_script.py"
  source       = "${path.module}/glue_job_script.py"
  content_type = "text/x-python"
}

resource "aws_glue_job" "csv_to_iceberg" {
  name     = "${var.project_tag}-csv-to-iceberg"
  role_arn = aws_iam_role.glue_role.arn

  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.this["raw"].bucket}/${aws_s3_object.glue_script.key}"
    python_version  = "3"
  }

  glue_version = "5.0"
  number_of_workers = 2
  worker_type       = "G.1X"

  default_arguments = {
    "--job-language"           = "python"
    "--enable-glue-datacatalog"= "true"
    "--datalake-formats"       = "iceberg"
    "--RAW_BUCKET"             = aws_s3_bucket.this["raw"].bucket
    "--WAREHOUSE_PATH"         = "s3://${aws_s3_bucket.this["iceberg"].bucket}/warehouse/"
    "--GLUE_DB"                = var.glue_db_name
    "--ICEBERG_TABLE"          = var.iceberg_table_name
  }

  tags = local.tags
}

######################################
# ATHENA WORKGROUP
######################################

resource "aws_athena_workgroup" "this" {
  name = "${var.project_tag}-wg"
  configuration {
    enforce_workgroup_configuration = true
    publish_cloudwatch_metrics_enabled = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.this["athena_results"].bucket}/results/"
    }
    engine_version {
      selected_engine_version = "Athena engine version 3"
    }
  }
  tags = local.tags
}
