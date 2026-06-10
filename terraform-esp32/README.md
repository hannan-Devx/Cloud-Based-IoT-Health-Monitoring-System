# ESP32 Health Monitor – Terraform Deployment Guide

Yeh guide aapke dost ke liye hai jo same infrastructure dobara banana chahta hai.

---

## Folder Structure

```
terraform-esp32/
├── main.tf                    ← Root: sab modules ko jodta hai
├── variables.tf               ← Saari settings ek jagah
├── outputs.tf                 ← Deploy ke baad URLs aur ARNs
├── modules/
│   ├── iot/                   ← IoT Thing + Certificate + Policy
│   ├── dynamodb/              ← DynamoDB table (esp32-vitals)
│   ├── lambda/
│   │   ├── main.tf            ← Dono Lambda functions
│   │   ├── functions/
│   │   │   ├── vitals_reader/ ← esp32-vitals-reader ka code
│   │   │   └── vitals_history/← get-vitals-history ka code
│   └── api_gateway/           ← HTTP API + routes
```

---

## Pre-requisites (Pehle yeh install karo)

### 1. AWS CLI Install
```bash
# Windows (PowerShell as Admin)
winget install Amazon.AWSCLI

# Mac
brew install awscli

# Ubuntu/Linux
sudo apt install awscli -y
```

### 2. Terraform Install
```bash
# Windows (PowerShell as Admin)
winget install Hashicorp.Terraform

# Mac
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Ubuntu/Linux
sudo apt-get update && sudo apt-get install -y terraform
```

### 3. AWS Credentials Configure karo
```bash
aws configure
```
Yeh 4 cheezein poochega:
- **AWS Access Key ID** → IAM se lo
- **AWS Secret Access Key** → IAM se lo
- **Default region** → `us-east-1` type karo (ya jo chahiye)
- **Output format** → `json` type karo

---

## Deploy Karna (Step by Step)

### Step 1 – Files copy karo
```bash
# Folder mein jao
cd terraform-esp32
```

### Step 2 – Terraform initialize karo (sirf pehli baar)
```bash
terraform init
```
Yeh providers download karega. Output mein `Terraform has been successfully initialized!` aana chahiye.

### Step 3 – Plan check karo (kya banega dekhna)
```bash
terraform plan
```
Yeh sab resources list karega jo create honge. Koi error nahi aani chahiye.

### Step 4 – Deploy karo
```bash
terraform apply
```
`yes` type karo jab pooche. Deploy hone mein 2-3 minute lagte hain.

### Step 5 – URLs dekhna
Deploy hone ke baad yeh command chalaao:
```bash
terraform output
```
Aapko milega:
```
api_endpoint   = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod"
vitals_url     = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/vitals"
history_url    = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/history"
```

### Step 6 – Certificates download karo (IoT ke liye)
```bash
# Certificate PEM (device.crt)
terraform output -raw iot_certificate_pem > device.crt

# Private Key (private.key)
terraform output -raw iot_private_key > private.key

# Public Key
terraform output -raw iot_public_key > public.key
```
**Amazon Root CA** manually download karo:
https://www.amazontrust.com/repository/AmazonRootCA1.pem

---

## Region Change Karna

Agar `us-east-1` ki jagah koi aur region chahiye (jaise `ap-south-1` for Mumbai):
```bash
# terraform.tfvars file banao
echo 'aws_region = "ap-south-1"' > terraform.tfvars
terraform apply
```

---

## Sab Delete Karna (Cleanup)

```bash
terraform destroy
```
`yes` type karo. Sab kuch delete ho jaega.

---

## Test Karna

Deploy ke baad browser ya curl se test karo:
```bash
# Latest vitals
curl https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/vitals

# History (last 30 days)
curl "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/history?patient_id=esp32-health-monitor&limit=50"
```

---

## Common Errors aur Fix

| Error | Fix |
|-------|-----|
| `No valid credential sources found` | `aws configure` dobara chalaao |
| `Error: creating IoT Thing: already exists` | Purana manually delete karo ya `terraform import` use karo |
| `ResourceNotFoundException` on Lambda | `terraform apply` dobara chalaao (ordering issue) |
| Certificate files empty | `terraform output -raw` use karo (bina `-raw` ke quotes aate hain) |

---

## Notes

- **IoT Certificate** sirf ek baar generate hota hai. Agar khoya toh naya banana hoga.
- **DynamoDB TTL** (`expiry_time` field) automatically enable hai – purana data khud delete hoga.
- **API Gateway** CORS already configured hai – browser se directly call kar sakte ho.
