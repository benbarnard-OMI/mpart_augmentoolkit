#!/bin/bash
# Validation script for Augmentoolkit container setup
# Run this before deploying to ensure everything is configured correctly

echo "=========================================="
echo "Augmentoolkit Container Validation"
echo "=========================================="
echo ""

ERRORS=0
WARNINGS=0

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

echo "Checking repository files..."

# Check required files
required_files=(
    "Dockerfile"
    "entrypoint.sh"
    "build.sh"
    "config.yaml"
    "qa_generation.yaml"
    "run_augmentoolkit.slurm"
    "run_augmentoolkit_test.slurm"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        check_pass "Found $file"
    else
        check_fail "Missing $file"
    fi
done

echo ""
echo "Checking shell script syntax..."

# Check shell scripts
shell_scripts=(
    "entrypoint.sh"
    "build.sh"
)

for script in "${shell_scripts[@]}"; do
    if [ -f "$script" ]; then
        if bash -n "$script" 2>/dev/null; then
            check_pass "$script syntax valid"
        else
            check_fail "$script has syntax errors"
        fi
        
        if [ -x "$script" ]; then
            check_pass "$script is executable"
        else
            check_warn "$script is not executable (run: chmod +x $script)"
        fi
    fi
done

echo ""
echo "Checking YAML configuration files..."

# Check YAML files
if command -v python3 &> /dev/null; then
    yaml_files=(
        "config.yaml"
        "qa_generation.yaml"
        "examples/config_high_throughput.yaml"
        "examples/config_high_quality.yaml"
    )
    
    for yaml_file in "${yaml_files[@]}"; do
        if [ -f "$yaml_file" ]; then
            if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
                check_pass "$yaml_file is valid YAML"
            else
                check_fail "$yaml_file has YAML syntax errors"
            fi
        fi
    done
else
    check_warn "Python3 not found - skipping YAML validation"
fi

echo ""
echo "Checking documentation..."

# Check documentation
docs=(
    "README.md"
    "QUICKSTART.md"
    "CONTRIBUTING.md"
    "DEPLOYMENT.md"
    "CHANGELOG.md"
)

for doc in "${docs[@]}"; do
    if [ -f "$doc" ]; then
        check_pass "Found $doc"
    else
        check_warn "Missing $doc (optional but recommended)"
    fi
done

echo ""
echo "Checking examples..."

if [ -d "examples" ]; then
    check_pass "Examples directory exists"
    
    example_count=$(find examples -name "*.yaml" -type f | wc -l)
    if [ "$example_count" -gt 0 ]; then
        check_pass "Found $example_count example configuration(s)"
    else
        check_warn "No example configurations found"
    fi
else
    check_warn "Examples directory not found"
fi

echo ""
echo "Checking Docker/Apptainer compatibility..."

# Check Dockerfile
if [ -f "Dockerfile" ]; then
    # Check for FROM statement
    if grep -q "^FROM" Dockerfile; then
        check_pass "Dockerfile has valid FROM statement"
    else
        check_fail "Dockerfile missing FROM statement"
    fi
    
    # Check for CUDA base image
    if grep -q "nvidia/cuda" Dockerfile; then
        check_pass "Using NVIDIA CUDA base image"
    else
        check_warn "Not using NVIDIA CUDA base image - GPU support may not work"
    fi
    
    # Check for ENTRYPOINT
    if grep -q "ENTRYPOINT" Dockerfile; then
        check_pass "Dockerfile has ENTRYPOINT"
    else
        check_warn "Dockerfile missing ENTRYPOINT"
    fi
fi

echo ""
echo "Checking SLURM scripts..."

slurm_scripts=(
    "run_augmentoolkit.slurm"
    "run_augmentoolkit_test.slurm"
)

for script in "${slurm_scripts[@]}"; do
    if [ -f "$script" ]; then
        # Check for required SBATCH directives
        if grep -q "^#SBATCH" "$script"; then
            check_pass "$script has SBATCH directives"
        else
            check_fail "$script missing SBATCH directives"
        fi
        
        # Check for placeholder warnings
        if grep -q "REPLACE_WITH_YOUR" "$script" 2>/dev/null; then
            check_warn "$script contains placeholders - remember to update before running"
        fi
    fi
done

echo ""
echo "=========================================="
echo "Validation Summary"
echo "=========================================="

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Build the container: ./build.sh"
    echo "2. Review the QUICKSTART.md guide"
    echo "3. Customize configuration files for your needs"
    echo "4. Deploy to cluster following DEPLOYMENT.md"
    EXIT_CODE=0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Validation completed with $WARNINGS warning(s)${NC}"
    echo "Review warnings above and fix if needed."
    echo ""
    echo "You can proceed but may want to address warnings first."
    EXIT_CODE=0
else
    echo -e "${RED}Validation failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo "Fix errors above before proceeding."
    echo ""
    EXIT_CODE=1
fi

echo ""
echo "For more information:"
echo "  README.md - Complete documentation"
echo "  QUICKSTART.md - Quick setup guide"
echo "  DEPLOYMENT.md - Cluster deployment guide"
echo "  CONTRIBUTING.md - Customization guide"
echo "=========================================="

exit ${EXIT_CODE:-0}
