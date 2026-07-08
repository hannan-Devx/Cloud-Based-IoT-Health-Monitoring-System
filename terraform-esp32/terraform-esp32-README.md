# ESP32 Health Monitor – Terraform Deployment Guide

This guide is for anyone who wants to redeploy the same infrastructure from scratch.

---

## Folder Structure

```
terraform-esp32/
├── main.tf                    ← Root: connects all modules together
├── variables.tf               ← All configuration settings in one place
├── outputs.tf                 ← URLs and ARNs after deployment
├── modules/
│   ├── iot/                   ← IoT Thing + Certificate + Policy
│   ├── dynamodb/              ← DynamoDB table (esp32-vitals)
│   ├── lambda/
│   │   ├── main.tf            ← Both Lambda functions
│   │   ├── functions/
│   │   │   ├── vitals_reader/ ← Code for esp32-vitals-reader
│   │   │   └── vitals_history/← Code for get-vitals-history
│   └── api_gateway/           ← HTTP API + routes
```

---

## Prerequisites (Install these first)

### 1. Install AWS CLI
```bash
# Windows (PowerShell as Admin)
winget install Amazon.AWSCLI

# Mac
brew install awscli

# Ubuntu/Linux
sudo apt install awscli -y
```

### 2. Install Terraform
```bash
# Windows (PowerShell as Admin)
winget install Hashicorp.Terraform

# Mac
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Ubuntu/Linux
sudo apt-get update && sudo apt-get install -y terraform
```

### 3. Configure AWS Credentials
```bash
aws configure
```
This will ask for 4 things:
- **AWS Access Key ID** → from IAM
- **AWS Secret Access Key** → from IAM
- **Default region** → type `us-east-1` (or your preferred region)
- **Output format** → type `json`

> ⚠️ **Security note:** Never commit your AWS Access Key, Secret Access Key, or any generated certificate/private key files to version control. Add `*.pem`, `*.crt`, `*.key`, and `terraform.tfvars` to your `.gitignore` before running any of the steps below.

---

## Deployment (Step by Step)

### Step 1 – Navigate to the folder
```bash
cd terraform-esp32
```

### Step 2 – Initialize Terraform (first time only)
```bash
terraform init
```
This downloads the required providers. You should see `Terraform has been successfully initialized!` in the output.

### Step 3 – Review the plan (see what will be created)
```bash
terraform plan
```
This lists all the resources that will be created. There should be no errors.

### Step 4 – Deploy
```bash
terraform apply
```
Type `yes` when prompted. Deployment takes about 2-3 minutes.

### Step 5 – View the URLs
After deployment, run:
```bash
terraform output
```
You'll get:
```
api_endpoint   = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod"
vitals_url     = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/vitals"
history_url    = "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/history"
```

### Step 6 – Download certificates (for IoT)
```bash
# Certificate PEM (device.crt)
terraform output -raw iot_certificate_pem > device.crt

# Private Key (private.key)
terraform output -raw iot_private_key > private.key

# Public Key
terraform output -raw iot_public_key > public.key
```
Download the **Amazon Root CA** manually:
https://www.amazontrust.com/repository/AmazonRootCA1.pem

> 🔒 Keep `device.crt`, `private.key`, and `public.key` local only — treat them like passwords. Anyone with the private key can impersonate your device on AWS IoT Core.

---

## Changing the Region

If you want a region other than `us-east-1` (e.g. `ap-south-1` for Mumbai):
```bash
# Create a terraform.tfvars file
echo 'aws_region = "ap-south-1"' > terraform.tfvars
terraform apply
```

---

## Cleanup (Delete Everything)

```bash
terraform destroy
```
Type `yes`. Everything will be deleted.

---

## Testing

After deployment, test using a browser or curl:
```bash
# Latest vitals
curl https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/vitals

# History (last 30 days)
curl "https://xxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/history?patient_id=esp32-health-monitor&limit=50"
```

---

## Common Errors and Fixes

| Error | Fix |
|-------|-----|
| `No valid credential sources found` | Run `aws configure` again |
| `Error: creating IoT Thing: already exists` | Delete the old one manually, or use `terraform import` |
| `ResourceNotFoundException` on Lambda | Run `terraform apply` again (ordering issue) |
| Certificate files empty | Use `terraform output -raw` (without `-raw`, quotes get included) |

---

## Notes

- The **IoT Certificate** is generated only once. If it's lost, a new one must be created.
- **DynamoDB TTL** (`expiry_time` field) is enabled automatically — old data will be deleted on its own.
- **API Gateway** already has CORS configured — you can call it directly from a browser.
- Never commit real AWS credentials, certificates, or private keys to this repository. Use environment variables or a local, git-ignored `terraform.tfvars` for sensitive values.
