output "s3_buckets" {
  value = {
    for k, v in aws_s3_bucket.this : k => v.bucket
  }
}

output "glue_job" {
  value = aws_glue_job.csv_to_iceberg.name
}

output "glue_database" {
  value = aws_glue_catalog_database.this.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.this.name
}
