# Fix: Terraform Plan-and-Apply Mode Plan File Passing

## Issue Identified
The "plan-and-apply" mode was failing because the plan file created in the plan step wasn't being properly passed to the apply step. The error showed:

```
❌ No plan file specified for apply
Error: Process completed with exit code 1.
```

## Root Cause
In `terraform-master.sh`, the script was trying to pass `$PLAN_FILE` to `terraform-apply-helper.sh`, but this variable was undefined in the master script's context. The plan file name was being set in `terraform-plan-helper.sh` and exported to `$GITHUB_ENV`, but this environment variable is not accessible within the same script execution in GitHub Actions.

## Solution Applied

### 1. Enhanced Plan File Communication
**File**: `scripts/terraform/terraform-plan-helper.sh`
- **Added**: Local file-based communication mechanism
- **Change**: Write plan file name to `.terraform-plan-file` in addition to `$GITHUB_ENV`
- **Purpose**: Allows master script to read the plan file name reliably

### 2. Improved Plan File Detection in Master Script
**File**: `scripts/terraform/terraform-master.sh`
- **Added**: Multi-method plan file detection:
  1. Read from `.terraform-plan-file` (primary method)
  2. Parse from `$GITHUB_ENV` (fallback)
  3. Find most recent `tfplan-*` file (final fallback)
- **Added**: Debug logging to show which plan file is being used
- **Added**: Cleanup of temporary files at script completion

### 3. Enhanced Error Handling in Apply Helper
**File**: `scripts/terraform/terraform-apply-helper.sh`
- **Enhanced**: Plan file validation and fallback logic
- **Added**: Automatic detection of most recent plan file if none specified
- **Added**: File existence verification before attempting apply
- **Added**: Detailed error logging showing directory contents for debugging

## Technical Details

### Plan File Flow (Before Fix)
1. `terraform-plan-helper.sh` creates plan file
2. Exports `PLAN_FILE` to `$GITHUB_ENV` 
3. `terraform-master.sh` tries to use undefined `$PLAN_FILE` variable ❌
4. `terraform-apply-helper.sh` receives empty plan file parameter ❌

### Plan File Flow (After Fix)
1. `terraform-plan-helper.sh` creates plan file
2. Writes plan file name to both `$GITHUB_ENV` and `.terraform-plan-file` ✅
3. `terraform-master.sh` reads plan file name using multiple methods ✅
4. `terraform-apply-helper.sh` receives valid plan file parameter ✅
5. Apply proceeds with proper plan file ✅

## Files Modified
- `scripts/terraform/terraform-master.sh`
- `scripts/terraform/terraform-plan-helper.sh` 
- `scripts/terraform/terraform-apply-helper.sh`

## Benefits
- **Reliable Plan File Passing**: Multiple detection methods ensure plan file is always found
- **Better Error Handling**: Clear error messages and debugging information
- **Robust Fallbacks**: Script continues working even if primary communication method fails
- **Clean Execution**: Temporary files are cleaned up after use

## Deployment Modes Now Supported
- ✅ **plan-only**: Creates plan and saves for later review
- ✅ **plan-and-apply**: Creates plan and applies immediately (FIXED)
- ✅ **apply-existing-plan**: Applies previously created plan

This fix ensures the complete Terraform workflow functions correctly in all three execution modes.
