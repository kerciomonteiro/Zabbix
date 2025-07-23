# 🔄 Manual Migration Guide to devops-iac Repository

## Quick Migration Steps

### 1. **Create New Repository**
- Go to GitHub and create a new repository called `devops-iac`
- Initialize it as empty (no README, .gitignore, or license)

### 2. **Run Migration Script**

**Option A: PowerShell (Windows)**
```powershell
# Update the URL with your actual repository URL
.\migrate-to-devops-iac.ps1 -NewRepoUrl "https://github.com/YOUR_USERNAME/devops-iac.git"
```

**Option B: Bash (Linux/macOS/WSL)**
```bash
# Make script executable
chmod +x migrate-to-devops-iac.sh

# Run migration (update URL first)
./migrate-to-devops-iac.sh
```

### 3. **Push to New Repository**
```bash
cd devops-iac
git push -u origin main
```

### 4. **Configure GitHub Actions**
Set up these secrets in your new repository:
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`

## What Gets Migrated

### ✅ **Included**
- Complete Terraform infrastructure (`infra/terraform/`)
- Kubernetes manifests (`applications/zabbix/k8s/`)
- GitHub Actions workflows (`.github/workflows/`)
- Deployment and recovery scripts (`scripts/terraform/`)
- Core documentation (new professional README)

### ❌ **Excluded** (via .gitignore)
- All troubleshooting .md files
- Temporary debugging files
- Development artifacts
- Issue resolution documentation

## Manual Alternative

If you prefer to do it manually:

### 1. **Clone Repository**
```bash
git clone https://github.com/kerciomonteiro/Zabbix.git devops-iac
cd devops-iac
```

### 2. **Remove Troubleshooting Files**
```bash
# Remove troubleshooting documentation
rm -f TERRAFORM_*.md WORKFLOW_*.md ZABBIX-*.md
rm -f NODE_POOL_*.md NGINX_*.md KUBERNETES_*.md
rm -f PLATFORM-*.md REPOSITORY-*.md troubleshooting-*.md
rm -f *-SUMMARY.md *-SUCCESS.md *-FIX.md *-RESOLUTION.md
rm -f scripts/terraform/RECOVERY-*.md
rm -f debug-pod.yaml zabbix-db-init-*.yaml
```

### 3. **Update README**
```bash
mv README-devops-iac.md README.md
```

### 4. **Update Git Remote**
```bash
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/devops-iac.git
```

### 5. **Commit and Push**
```bash
git add -A
git commit -m "🚀 Initial DevOps-IAC repository - clean professional setup"
git push -u origin main
```

## Verification

After migration, your new repository should have:

### **Clean Structure**
```
devops-iac/
├── .github/workflows/     # CI/CD pipelines
├── infra/terraform/       # Infrastructure as Code
├── applications/zabbix/   # Kubernetes manifests
├── scripts/terraform/     # Automation scripts
├── README.md             # Professional documentation
└── .gitignore            # Excludes troubleshooting files
```

### **No Troubleshooting Artifacts**
- No TERRAFORM_*.md files
- No troubleshooting-*.md files
- No debug or temporary files
- Clean, professional appearance

### **Professional README**
- Enterprise-focused documentation
- Clear architecture diagrams
- Complete deployment guide
- Production-ready instructions

## Post-Migration Tasks

### 1. **GitHub Repository Setup**
- Enable GitHub Actions
- Set up branch protection rules
- Configure repository settings

### 2. **Test Deployment**
- Trigger the workflow manually
- Verify all secrets are configured
- Test the complete deployment process

### 3. **Documentation Review**
- Update any URLs or references
- Customize for your environment
- Add any organization-specific documentation

## Success Criteria

✅ **New repository is clean and professional**  
✅ **All troubleshooting artifacts excluded**  
✅ **GitHub Actions workflow functional**  
✅ **Infrastructure deployment successful**  
✅ **Documentation complete and accurate**

---

**Ready for production DevOps environment! 🚀**
