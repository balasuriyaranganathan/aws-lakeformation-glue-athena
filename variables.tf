variable "aws_region" {
  default = "us-east-1"
}

variable "project_tag" {
  default = "csv-to-iceberg-demo"
}

variable "glue_db_name" {
  default = "demo_iceberg_db"
}

variable "iceberg_table_name" {
  default = "customers"
}
