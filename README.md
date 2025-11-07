# AWS Lake Formation + Glue + Athena ETL Project

## 📘 Overview
This project builds an AWS data lake using Terraform, integrating:
- AWS Glue for ETL (CSV → Iceberg)
- AWS Lake Formation for fine-grained data governance
- Amazon Athena for querying data in S3

## ⚙️ Components
- **Terraform** provisions:
  - 3 S3 buckets (raw, iceberg, athena results)
  - Glue catalog database and job
  - IAM roles and policies
  - Lake Formation data location and permissions
  - Athena workgroup

- **Python ETL Script (`glue_job_script.py`)**
  - Reads CSV data from the raw bucket
  - Writes an Iceberg table into the Glue Data Catalog
  - Validates data read-back from the Iceberg table

## 🧩 Directory Structure
```
infra/
├── main.tf                   # Core Terraform setup
├── lakeformation.tf          # Lake Formation governance config
├── glue_job_script.py        # ETL logic
├── variables.tf              # Input variables
├── outputs.tf                # Outputs after apply
├── policies/                 # IAM trust and assume role policies
├── terraform.tfvars.example  # Example values
├── .gitignore
└── README.md
```

## 🔒 Secrets & Security
- No AWS keys or tfstate files are stored in this repo.
- `.gitignore` prevents Terraform state from being pushed.
- Sensitive files like `terraform.tfvars` remain local.

## 🚀 Running the Project
```bash
terraform init
terraform plan
terraform apply
```


---

### 💾 Step 5 — Initialize Git and push to GitHub

1️⃣ Create your GitHub repo (e.g. `aws-lakeformation-glue-athena-demo`)  

2️⃣ Run these commands in your local folder:
```bash
cd infra
git init
git add .
git commit -m "Initial commit: Lake Formation + Glue + Athena project"
git branch -M main
git remote add origin https://github.com/<your-username>/<your-repo>.git
git push -u origin main
```

