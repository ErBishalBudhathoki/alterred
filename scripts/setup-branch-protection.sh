#!/bin/bash

# Setup Branch Protection Rules for Neuropilot Repository
# This script configures GitHub branch protection rules via GitHub CLI

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REPO_OWNER="your-username"  # TODO: Update this with your GitHub username
REPO_NAME="neuropilot"      # TODO: Update this with your repository name
REPO="$REPO_OWNER/$REPO_NAME"

echo -e "${BLUE}🛡️  Setting up branch protection rules for $REPO${NC}"
echo -e "${YELLOW}⚠️  Please update REPO_OWNER and REPO_NAME variables in this script first!${NC}"

# Verify configuration
if [ "$REPO_OWNER" = "your-username" ]; then
    echo -e "${RED}❌ Please update REPO_OWNER variable with your GitHub username${NC}"
    echo -e "Edit this script and change 'your-username' to your actual GitHub username"
    exit 1
fi

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI (gh) is not installed. Please install it first.${NC}"
    echo "Visit: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo -e "${RED}❌ GitHub CLI is not authenticated. Please run 'gh auth login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ GitHub CLI is ready${NC}"

# Function to create branch protection rule
create_branch_protection() {
    local branch=$1
    local required_checks=$2
    local require_pr_reviews=$3
    local dismiss_stale_reviews=$4
    local require_code_owner_reviews=$5
    local allow_force_pushes=$6
    
    echo -e "${YELLOW}📋 Setting up protection for branch: $branch${NC}"
    
    # Create the protection rule
    gh api repos/$REPO/branches/$branch/protection \
        --method PUT \
        --field required_status_checks='{
            "strict": true,
            "contexts": '"$required_checks"'
        }' \
        --field enforce_admins=true \
        --field required_pull_request_reviews='{
            "required_approving_review_count": '"$require_pr_reviews"',
            "dismiss_stale_reviews": '"$dismiss_stale_reviews"',
            "require_code_owner_reviews": '"$require_code_owner_reviews"'
        }' \
        --field restrictions=null \
        --field allow_force_pushes='{
            "enabled": '"$allow_force_pushes"'
        }' \
        --field allow_deletions='{
            "enabled": false
        }' || {
        echo -e "${RED}❌ Failed to set protection for $branch${NC}"
        return 1
    }
    
    echo -e "${GREEN}✅ Protection set for $branch${NC}"
}

# Main branch protection (Production)
echo -e "\n${BLUE}🏭 Configuring main branch (Production)${NC}"
MAIN_REQUIRED_CHECKS='[
    "Security & Secrets Validation",
    "Code Quality Checks", 
    "Test Coverage",
    "Deployment Readiness"
]'

create_branch_protection "main" "$MAIN_REQUIRED_CHECKS" 2 true true false

# Staging branch protection
echo -e "\n${BLUE}🧪 Configuring staging branch${NC}"
STAGING_REQUIRED_CHECKS='[
    "Security & Secrets Validation",
    "Code Quality Checks",
    "Test Coverage"
]'

create_branch_protection "staging" "$STAGING_REQUIRED_CHECKS" 1 true false false

# Development branch protection
echo -e "\n${BLUE}🔧 Configuring dev branch${NC}"
DEV_REQUIRED_CHECKS='[
    "Security & Secrets Validation",
    "Code Quality Checks"
]'

create_branch_protection "dev" "$DEV_REQUIRED_CHECKS" 1 false false true

# Development branch protection (alternative name)
echo -e "\n${BLUE}🔧 Configuring development branch${NC}"
create_branch_protection "development" "$DEV_REQUIRED_CHECKS" 1 false false true

# Create CODEOWNERS file if it doesn't exist
echo -e "\n${BLUE}📝 Setting up CODEOWNERS${NC}"
if [ ! -f ".github/CODEOWNERS" ]; then
    cat > .github/CODEOWNERS << 'EOF'
# Global code owners
* @your-username  # TODO: Update with your GitHub username

# Deployment and infrastructure
/.github/workflows/ @your-username
/scripts/ @your-username
/Dockerfile @your-username
/firebase.json @your-username

# Security-sensitive files
/.env.example @your-username
/.gitignore @your-username
/credentials/ @your-username

# Backend API
/api_server.py @your-username
/routers/ @your-username
/services/ @your-username

# Frontend core
/frontend/flutter_neuropilot/lib/core/ @your-username
/frontend/flutter_neuropilot/lib/services/ @your-username
/frontend/flutter_neuropilot/lib/state/ @your-username
EOF
    echo -e "${GREEN}✅ Created .github/CODEOWNERS${NC}"
else
    echo -e "${YELLOW}⚠️  .github/CODEOWNERS already exists${NC}"
fi

# Create pull request template
echo -e "\n${BLUE}📋 Setting up PR template${NC}"
mkdir -p .github/pull_request_template
cat > .github/pull_request_template/default.md << 'EOF'
## Description
Brief description of changes made.

## Type of Change
- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🔧 Configuration change
- [ ] 🧪 Test update

## Environment
- [ ] Development
- [ ] Staging  
- [ ] Production

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] No new security vulnerabilities introduced

## Security Checklist
- [ ] No hardcoded secrets or credentials
- [ ] Sensitive data properly handled
- [ ] Authentication/authorization working correctly
- [ ] Input validation implemented

## Deployment Notes
- [ ] Database migrations required: No / Yes (describe)
- [ ] Environment variables changed: No / Yes (list)
- [ ] Breaking changes: No / Yes (describe impact)
- [ ] Rollback plan documented: No / Yes / N/A

## Screenshots/Videos
<!-- Add screenshots or videos if applicable -->

## Additional Notes
<!-- Any additional information, context, or considerations -->
EOF

echo -e "${GREEN}✅ Created PR template${NC}"

# Summary
echo -e "\n${GREEN}🎉 Branch protection setup complete!${NC}"
echo -e "\n${BLUE}Summary of protections:${NC}"
echo -e "📋 Main (Production):"
echo -e "   • Requires 2 approving reviews"
echo -e "   • Dismisses stale reviews"
echo -e "   • Requires code owner reviews"
echo -e "   • All status checks must pass"
echo -e "   • No force pushes allowed"

echo -e "\n📋 Staging:"
echo -e "   • Requires 1 approving review"
echo -e "   • Security and quality checks required"
echo -e "   • No force pushes allowed"

echo -e "\n📋 Dev/Development:"
echo -e "   • Requires 1 approving review"
echo -e "   • Security checks required"
echo -e "   • Force pushes allowed for development flexibility"

echo -e "\n${YELLOW}⚠️  Next steps:${NC}"
echo -e "1. Update CODEOWNERS file with actual GitHub usernames"
echo -e "2. Test the protection rules by creating a test PR"
echo -e "3. Verify all required status checks are working"
echo -e "4. Train team members on the new workflow"

echo -e "\n${BLUE}🔗 Useful commands:${NC}"
echo -e "• View protection status: gh api repos/$REPO/branches/main/protection"
echo -e "• List required checks: gh api repos/$REPO/branches/main/protection/required_status_checks"
echo -e "• Update this script: $0"