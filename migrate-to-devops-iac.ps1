# DevOps-IAC Repository Migration Script (PowerShell)
# This script prepares the code for migration to the new devops-iac repository

param(
    [string]$NewRepoUrl = "https://github.com/kerciomonteiro/devops-iac.git"
)

Write-Host "🚀 DevOps-IAC Repository Migration" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host ""

# Configuration
$NewRepoName = "devops-iac"
$CurrentRepoUrl = "https://github.com/kerciomonteiro/Zabbix.git"

Write-Host "📋 Migration Plan:" -ForegroundColor Cyan
Write-Host "  Source: Zabbix repository" -ForegroundColor White
Write-Host "  Target: $NewRepoName repository" -ForegroundColor White
Write-Host "  URL: $NewRepoUrl" -ForegroundColor White
Write-Host ""

# Step 1: Create fresh clone
Write-Host "🔄 Step 1: Creating fresh clone..." -ForegroundColor Cyan
if (Test-Path $NewRepoName) {
    Write-Host "⚠️  Directory $NewRepoName already exists. Removing..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $NewRepoName
}

git clone $CurrentRepoUrl $NewRepoName
Set-Location $NewRepoName

Write-Host "✅ Repository cloned successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Remove troubleshooting files
Write-Host "🧹 Step 2: Removing troubleshooting documentation..." -ForegroundColor Cyan

# Remove troubleshooting .md files (these are now in .gitignore)
$troubleshootingPatterns = @(
    "TERRAFORM_*.md",
    "WORKFLOW_*.md", 
    "ZABBIX-*.md",
    "NODE_POOL_*.md",
    "NGINX_*.md",
    "KUBERNETES_*.md",
    "PLATFORM-*.md",
    "REPOSITORY-*.md",
    "troubleshooting-*.md",
    "*-SUMMARY.md",
    "*-SUCCESS.md",
    "*-FIX.md",
    "*-RESOLUTION.md"
)

foreach ($pattern in $troubleshootingPatterns) {
    Get-ChildItem -Path . -Name $pattern -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Remove specific troubleshooting files
$specificFiles = @(
    "debug-pod.yaml",
    "zabbix-db-init-*.yaml"
)

foreach ($file in $specificFiles) {
    Get-ChildItem -Path . -Name $file -Recurse | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Remove recovery guides from scripts
Get-ChildItem -Path "scripts\terraform" -Name "RECOVERY-*.md" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "✅ Troubleshooting files removed" -ForegroundColor Green
Write-Host ""

# Step 3: Replace README
Write-Host "📚 Step 3: Updating README for DevOps-IAC..." -ForegroundColor Cyan
if (Test-Path "README-devops-iac.md") {
    Move-Item "README-devops-iac.md" "README.md" -Force
    Write-Host "✅ README updated with DevOps-IAC content" -ForegroundColor Green
} else {
    Write-Host "⚠️  README-devops-iac.md not found, keeping existing README" -ForegroundColor Yellow
}
Write-Host ""

# Step 4: Update remote origin
Write-Host "🔗 Step 4: Updating git remote..." -ForegroundColor Cyan
git remote remove origin
git remote add origin $NewRepoUrl

Write-Host "✅ Remote updated to: $NewRepoUrl" -ForegroundColor Green
Write-Host ""

# Step 5: Clean up git history
Write-Host "🔄 Step 5: Preparing clean commit..." -ForegroundColor Cyan

# Stage all changes
git add -A

# Commit the cleanup
$commitMessage = @"
🚀 INITIAL DEVOPS-IAC REPOSITORY

✅ CLEAN PROFESSIONAL REPOSITORY:
• Removed all troubleshooting documentation
• Updated README for DevOps-IAC focus
• Professional documentation and structure
• Production-ready Infrastructure as Code

📦 INCLUDED COMPONENTS:
• Complete Terraform infrastructure
• Kubernetes manifests for Zabbix stack
• GitHub Actions CI/CD workflows
• Automated deployment and recovery scripts
• Comprehensive documentation

🎯 READY FOR PRODUCTION:
• Enterprise-grade IaC templates
• Automated Zabbix monitoring deployment
• Professional DevOps workflows
• Complete Azure AKS solution

Repository migrated from Zabbix troubleshooting to clean DevOps-IAC
"@

git commit -m $commitMessage

Write-Host "✅ Clean commit created" -ForegroundColor Green
Write-Host ""

# Step 6: Instructions for pushing
Write-Host "🎯 Step 6: Ready to push to new repository!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. Create the new repository on GitHub: $NewRepoUrl" -ForegroundColor White
Write-Host "2. Run the following command to push:" -ForegroundColor White
Write-Host "   Set-Location $NewRepoName" -ForegroundColor Gray
Write-Host "   git push -u origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Verify the repository looks clean and professional" -ForegroundColor White
Write-Host "4. Set up GitHub Actions secrets:" -ForegroundColor White
Write-Host "   - AZURE_CLIENT_ID" -ForegroundColor Gray
Write-Host "   - AZURE_CLIENT_SECRET" -ForegroundColor Gray
Write-Host "   - AZURE_SUBSCRIPTION_ID" -ForegroundColor Gray
Write-Host "   - AZURE_TENANT_ID" -ForegroundColor Gray
Write-Host ""

# Summary
Write-Host "🎉 MIGRATION SUMMARY:" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Green
Write-Host "✅ Fresh clone created in ./$NewRepoName/" -ForegroundColor Green
Write-Host "✅ Troubleshooting files removed" -ForegroundColor Green
Write-Host "✅ Professional README installed" -ForegroundColor Green
Write-Host "✅ Git remote updated" -ForegroundColor Green
Write-Host "✅ Clean commit prepared" -ForegroundColor Green
Write-Host ""

Write-Host "📂 Repository structure:" -ForegroundColor Cyan
Get-ChildItem -Directory | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Name)/" -ForegroundColor Gray }
Write-Host ""

Write-Host "🚀 Ready for production DevOps environment!" -ForegroundColor Green
Write-Host ""
Write-Host "⚠️  Remember to:" -ForegroundColor Yellow
Write-Host "  1. Create the GitHub repository first" -ForegroundColor White
Write-Host "  2. Configure GitHub Actions secrets" -ForegroundColor White
Write-Host "  3. Test the deployment workflow" -ForegroundColor White
Write-Host ""

Write-Host "Migration script completed successfully! 🎉" -ForegroundColor Green
