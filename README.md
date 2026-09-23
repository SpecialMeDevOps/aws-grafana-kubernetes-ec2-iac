# AWS Grafana Kubernetes EC2 Infrastructure

A production-style Infrastructure as Code and CI/CD project that provisions a single-node EC2 Kubernetes environment on AWS, deploys a lightweight web application, installs Prometheus and Grafana, and automates delivery through GitHub Actions.

## Overview

This repository demonstrates the full delivery chain:

GitHub Actions
↓
Terraform
↓
CloudFormation
↓
AWS VPC and Networking
↓
EC2 instance
↓
Bootstrap automation
↓
Docker
↓
Kubernetes
↓
Application deployment
↓
Prometheus
↓
Grafana dashboard

The goal is to provide a clean DevOps portfolio project that is easy to understand, secure by default, and suitable for demonstration in a GitHub repository.

## Architecture

Developer
|
V
GitHub Repository
|
V
GitHub Actions
|
V
Terraform
|
V
AWS CloudFormation
|
+-------------------------+
|                         |
|   VPC                  |
|   Internet Gateway     |
|   Public Subnet        |
|   Route Table          |
|   Security Group       |
|   EC2 Instance         |
|   IAM Role/Profile     |
|   S3 Bucket            |
|   EC2 Key Pair         |
|                         |
+-------------------------+
        |
        V
     EC2 bootstrap
        |
        V
     Docker
        |
        V
     Kubernetes (single-node)
        |
        V
     Application Deployment
        |
        V
     Prometheus + Grafana
        |
        V
    Monitoring dashboard

## Technology Stack

- AWS EC2
- VPC, subnet, route table, security groups, IAM
- Terraform for orchestration
- AWS CloudFormation to create the underlying stack
- S3 bucket for secure SSH key storage
- Docker
- Kubernetes (single-node via K3s for reliability and speed)
- Helm
- Prometheus + Grafana
- GitHub Actions with OIDC
- SSH access for management and troubleshooting

## Project Structure

```text
.
├── .github/
│   └── workflows/
│       ├── terraform-apply.yml
│       └── terraform-destroy.yml
├── app/
│   ├── Dockerfile
│   ├── index.html
│   ├── nginx.conf
│   └── style.css
├── cloudformation/
│   └── infrastructure.yaml
├── kubernetes/
│   ├── deployment.yaml
│   ├── namespace.yaml
│   └── service.yaml
├── scripts/
│   ├── bootstrap.sh
│   └── check-existing-ec2.sh
├── terraform/
│   ├── cloudformation.tf
│   ├── locals.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars.example
│   ├── variables.tf
│   └── versions.tf
├── .gitignore
├── LICENSE
├── README.md
└── docs/
    └── screenshots/
```

## Prerequisites

Before you run the project, make sure you have:

- AWS account with permission to create VPC, EC2, IAM, CloudFormation, and S3 resources
- GitHub repository with Actions enabled
- Terraform 1.6+ installed locally if you want to run it outside GitHub Actions
- AWS CLI v2 installed and configured
- Docker installed locally if you plan to test the app image outside the EC2 instance
- A GitHub OIDC role configured for AWS authentication

## AWS Configuration

1. Log in to AWS and create or identify the target AWS account.
2. Set your default region to `us-east-1` unless you intentionally override it.
3. Configure an IAM role for GitHub Actions OIDC with least-privilege permissions for:
   - CloudFormation
   - EC2
   - IAM
   - VPC
   - S3
   - Terraform state management if you are using remote state
4. Save the ARN as a repository secret named `AWS_ROLE_ARN`.

## GitHub OIDC Setup

This project prefers GitHub Actions OIDC over long-lived AWS static credentials.

Example IAM trust policy for the GitHub role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:<OWNER>/<REPO>:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

For this repository, replace `<ACCOUNT_ID>` with the AWS account ID and use this exact subject:

```text
repo:SpecialMeDevOps/aws-grafana-kubernetes-ec2-iac:ref:refs/heads/main
```

The OIDC provider URL must be `token.actions.githubusercontent.com`, and the audience must be `sts.amazonaws.com`. The `AWS_ROLE_ARN` repository secret must contain the ARN of this exact role, not a different role with a similar name.

Grant access only to the exact actions and resources you need.

## Repository Configuration

Create a GitHub secret:

- `AWS_ROLE_ARN`

Optional environment variables can be set in the repository or in GitHub Environments as needed.

## Terraform Configuration

The Terraform code in `terraform/` is responsible for orchestrating the CloudFormation stack.

Terraform does the following:

- Defines the AWS provider and Terraform version constraints
- Sets a central `aws_region` configuration
- Defines environment and naming variables
- Executes a CloudFormation template
- Exposes important non-secret outputs

### Example values

Copy `terraform/terraform.tfvars.example` to `terraform/terraform.tfvars` before local use. Do not commit this file.

```hcl
project_name = "aws-grafana-kubernetes-ec2-iac"
environment = "dev"
aws_region = "us-east-1"
```

## CloudFormation Architecture

The CloudFormation template in `cloudformation/infrastructure.yaml` creates:

- VPC
- Internet Gateway
- Public Subnet
- Route Table and Route
- Security Group
- EC2 instance
- EC2 Key Pair
- S3 bucket for SSH private key storage
- IAM instance profile and role

Important outputs from the template include:

- VPC ID
- Subnet ID
- Security Group ID
- Instance ID
- Public IP
- Public DNS
- Key Pair Name
- S3 Bucket Name

Terraform reads these outputs and exposes them to the operator.

## EC2 Bootstrap Process

The EC2 instance automatically runs the bootstrap script from `scripts/bootstrap.sh` through CloudFormation `UserData`.

The bootstrap process is designed to install and configure:

- Docker
- Kubernetes (K3s single-node cluster)
- Helm
- Prometheus
- Grafana
- Application deployment
- Monitoring configuration
- Logging in `/var/log/bootstrap.log`

The script logs progress and fails clearly if a required step breaks.

### Checking bootstrap status

After the EC2 instance is created, connect to it and inspect the log:

```bash
sudo tail -f /var/log/bootstrap.log
```

Also check service status:

```bash
systemctl status docker
kubectl get nodes
kubectl get pods -A
```

## Docker Setup

Docker is installed during the bootstrap step.

Verification commands:

```bash
docker --version
docker ps
```

A simple static web application is containerized in `app/` and served by nginx.

## Kubernetes Setup

This project uses a single-node Kubernetes cluster for demonstration and monitoring.

Kubernetes resources are in `kubernetes/`:

- `namespace.yaml`
- `deployment.yaml`
- `service.yaml`

Verification:

```bash
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
```

The application is exposed with a NodePort service on port `30080`.

## Application Deployment

The sample app is a lightweight `nginx` page that explains the stack:

- AWS Infrastructure
- Docker
- Kubernetes
- Prometheus
- Grafana
- Terraform
- CloudFormation
- GitHub Actions

The app is accessible through the EC2 public IP and the Kubernetes NodePort:

```text
http://EC2_PUBLIC_IP:30080
```

## Prometheus Setup

Prometheus is deployed through Helm using the `kube-prometheus-stack` chart.

This is the standard monitoring approach for Kubernetes and provides:

- CPU and memory metrics
- Node availability
- Pod and container metrics
- Kubernetes resource metrics
- App-friendly monitoring hooks

## Grafana Setup

Grafana is installed automatically as part of the Prometheus stack.

The default admin password is intentionally set to a temporary value during deployment:

- `admin123`

This is a demo-only value and should be changed immediately in a real environment.

Grafana is exposed at:

```text
http://EC2_PUBLIC_IP:3000
```

### How Grafana monitoring works

Application / Kubernetes
↓
Metrics
↓
Prometheus
↓
Grafana
↓
Dashboard

Prometheus scrapes the cluster and workloads, and Grafana uses Prometheus as its data source to render a dashboard for metrics such as:

- CPU usage
- Memory usage
- Pod status
- Node status
- Network activity
- Container metrics where available

## Monitoring Architecture

The project demonstrates a standard monitoring flow:

- Application runs in Kubernetes
- Prometheus collects platform and workload metrics
- Grafana queries Prometheus
- Dashboard visualizes cluster health and performance

## GitHub Actions

GitHub Actions is used to automate Terraform deployment.

Workflow files:

- `.github/workflows/terraform-apply.yml`
- `.github/workflows/terraform-destroy.yml`

### Terraform Apply workflow

The apply workflow performs the following:

1. Checkout code
2. Check for existing matching EC2 resources
3. Configure AWS via OIDC
4. Setup Terraform
5. `terraform fmt -check`
6. `terraform init`
7. `terraform validate`
8. `terraform plan`
9. `terraform apply`
10. Display useful outputs

This workflow does not destroy resources automatically after a successful apply.

### Terraform Destroy workflow

The destroy workflow is manual and requires an explicit confirmation input:

```text
DESTROY
```

It is intentionally designed to avoid accidental deletion of active infrastructure.

## Terraform Apply

Run the workflow from GitHub Actions or run locally:

```bash
cd terraform
terraform init
terraform validate
terraform plan
terraform apply
```

## Terraform Destroy

Destroy must be done intentionally from GitHub Actions with confirmation:

```text
confirm_destroy: DESTROY
```

This protects against accidental teardown of an active stack.

## Existing EC2 Handling

The repository includes `scripts/check-existing-ec2.sh` to help prevent accidental destruction of an existing instance.

The logic is intentionally conservative:

- If a matching EC2 instance is detected, the workflow stops and explains the situation.
- The user must review the instance before proceeding.
- The project never silently destroys an EC2 instance.
- If Terraform state is missing but infrastructure exists, the operator is told to review the environment carefully before replacing or importing resources.

This is required for safe operations in real AWS environments.

## SSH Access

The infrastructure creates an EC2 key pair automatically, so the user does not need to pre-create `~/.ssh/id_rsa.pub`.

The private SSH key is stored in an S3 bucket that is:

- Encrypted
- Versioned
- Public-blocked
- Not publicly readable
- Managed with least-privilege access

Do not commit any private key to GitHub.

### Find the S3 bucket and key

For a manual key handoff, use the helper script `scripts/store-ssh-key-s3.sh` to create a private key and upload it securely to the S3 bucket created by the CloudFormation stack. The same pattern can also be adapted to a controlled CI/CD or operator workflow.

1. Open the AWS console.
2. Find the bucket created by the CloudFormation stack.
3. Download the private key when you need SSH access.
4. Save it locally as a `.pem` file.
5. Set the right permissions.

### Linux/macOS

```bash
chmod 400 key.pem
ssh -i key.pem ec2-user@EC2_PUBLIC_IP
```

### Windows PowerShell

```powershell
icacls .\key.pem /inheritance:r
icacls .\key.pem /grant:r "$env:USERNAME":(R)
ssh -i .\key.pem ec2-user@EC2_PUBLIC_IP
```

Never print or commit the private key contents into logs or repository files.

## Application Access

Once the instance is available:

```text
http://EC2_PUBLIC_IP:30080
```

This is the NodePort URL for the sample application.

## Grafana Access

```text
http://EC2_PUBLIC_IP:3000
```

Use the temporary username/password:

- Username: `admin`
- Password: `admin123`

Change it after first login in a real environment.

## Verification Commands

```bash
docker --version
docker ps
kubectl get nodes
kubectl get pods -A
kubectl get svc -A
systemctl status docker
systemctl status k3s
```

## Troubleshooting

### EC2 not reachable

- Check Security Group ingress rules
- Confirm the EC2 instance is running
- Verify the public IP or DNS in AWS
- Check route table and subnet association

### SSH permission denied

- Confirm the private key file permissions are correct
- Make sure the user matches the EC2 AMI (often `ec2-user` for Amazon Linux)
- Confirm SSH is open on port 22 in the security group

### Docker not running

```bash
sudo systemctl status docker
sudo journalctl -u docker -n 50
```

### Kubernetes node NotReady

```bash
kubectl get nodes
kubectl describe node <node-name>
```

### Grafana not accessible

- Check the service status in Kubernetes
- Confirm NodePort `3000` is reachable
- Review the Grafana pod logs

### Prometheus not receiving metrics

```bash
kubectl get pods -A -n monitoring
kubectl logs -n monitoring deploy/kube-prometheus-prometheus
```

### Security Group port issue

- Check if ports `22`, `80`, `3000`, `8080`, and `30080` are expected
- Restrict source CIDRs appropriately
- Adjust the CloudFormation template if needed

### Bootstrap failure

```bash
sudo tail -f /var/log/bootstrap.log
```

### GitHub Actions authentication failure

- Validate `AWS_ROLE_ARN` secret
- Confirm the IAM trust policy includes the correct `sub` claim
- Check that the repo uses the right branch and environment

### Terraform state problems

- Ensure `terraform.tfvars` is not accidentally committed
- Review `terraform.tfstate` files and ensure they are excluded by `.gitignore`
- If infrastructure already exists, verify the correct resource ownership before replacing it

### Existing EC2 detected

This means a matching instance already exists in AWS. Review it carefully before choosing to replace it.

## Screenshots

This project is designed so that you can add screenshots after successful deployment.

Planned screenshot set:

- `docs/screenshots/architecture.png`
- `docs/screenshots/github-actions.png`
- `docs/screenshots/aws-ec2.png`
- `docs/screenshots/application.png`
- `docs/screenshots/kubernetes.png`
- `docs/screenshots/grafana-dashboard.png`
- `docs/screenshots/prometheus.png`

These should be added after deployment to document the infrastructure and monitoring flow. No fake screenshots are included in this repository.

## What happens when I run Terraform?

Terraform creates the CloudFormation stack, which then provisions the VPC, subnet, security group, EC2 instance, IAM resources, and S3 bucket for SSH key storage. Once the EC2 instance boots, `UserData` installs Docker, Kubernetes, Helm, Prometheus, Grafana, and the application.

## What happens after EC2 is created?

The EC2 instance downloads the bootstrap script and runs it automatically. This script installs required packages, starts Docker, launches the K3s single-node Kubernetes cluster, installs Helm, deploys the app, installs Prometheus and Grafana, and waits for workloads to become ready.

## How does Docker get installed?

Docker is installed during the EC2 bootstrap process using the official Ubuntu Docker repository.

## How does Kubernetes get installed?

The bootstrap script installs K3s, a lightweight but full-featured single-node Kubernetes distribution. The cluster is initialized automatically, and `kubectl` becomes available immediately after startup.

## How does the application reach Kubernetes?

The application is built into a Docker image and imported into the K3s runtime, then deployed through a Kubernetes Deployment and Service. The Service uses a NodePort so the app is reachable from the EC2 public IP.

## How does Prometheus collect metrics?

Prometheus is installed with Helm using the `kube-prometheus-stack` chart. It scrapes cluster and workload metrics and exposes them to Grafana.

## How does Grafana display the metrics?

Grafana uses Prometheus as its data source. The deployed monitoring stack configures the connection automatically, so the dashboard shows the data without requiring manual Prometheus configuration.

## How does GitHub Actions trigger Terraform?

GitHub Actions authenticates to AWS using OIDC and then runs `terraform init`, `validate`, `plan`, and `apply` to provision the infrastructure via CloudFormation.

## Where is the SSH key stored?

The EC2 key pair is created as part of the CloudFormation stack and the private key is expected to be securely retrieved and stored in S3 according to the project's operational process.

## How do I safely destroy the infrastructure?

Use the dedicated destroy workflow, which requires the explicit confirmation entry:

```text
DESTROY
```

This avoids accidental deletion of active AWS resources.

## Final Notes

This project is intentionally simple and professional enough for a portfolio, while still demonstrating the full chain of:

- GitHub Actions
- Terraform
- CloudFormation
- AWS infrastructure
- EC2 bootstrap
- Docker
- Kubernetes
- Monitoring
- Grafana

It is not meant to be a production-grade multi-AZ production cluster, but it is structured to behave like a realistic, demonstrable DevOps project.

## License

This project is licensed under the MIT License. See the `LICENSE` file.
