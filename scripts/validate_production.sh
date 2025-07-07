#!/bin/bash

# Production validation script for Reddit Video Automation workflow
# This script validates the production setup and readiness

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[$timestamp] INFO:${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] SUCCESS:${NC} $message"
            ;;
        "WARNING")
            echo -e "${YELLOW}[$timestamp] WARNING:${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] ERROR:${NC} $message"
            ;;
    esac
}

# Test results tracking
TESTS_PASSED=0
TESTS_FAILED=0
TOTAL_TESTS=0

# Test function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    log "INFO" "Running test: $test_name"
    
    if eval "$test_command" > /dev/null 2>&1; then
        log "SUCCESS" "$test_name - PASSED"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log "ERROR" "$test_name - FAILED"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Validation functions
validate_json_structure() {
    log "INFO" "Validating n8n workflow JSON structure"
    
    if [ ! -f "n8n_workflow_reddit_video_automation.json" ]; then
        log "ERROR" "Workflow JSON file not found"
        return 1
    fi
    
    # Validate JSON syntax
    if ! python -c "import json; json.load(open('n8n_workflow_reddit_video_automation.json'))" 2>/dev/null; then
        log "ERROR" "Invalid JSON syntax in workflow file"
        return 1
    fi
    
    # Check for required nodes
    local required_nodes=("Start" "1. Reddit Scraper" "2. Filter Posts" "8. Upload to YouTube")
    for node in "${required_nodes[@]}"; do
        if ! grep -q "\"name\": \"$node\"" "n8n_workflow_reddit_video_automation.json"; then
            log "ERROR" "Missing required node: $node"
            return 1
        fi
    done
    
    log "SUCCESS" "JSON structure validation passed"
    return 0
}

validate_scripts() {
    log "INFO" "Validating production scripts"
    
    local scripts=(
        "scripts/cleanup_temp_files.sh"
        "scripts/monitor_workflow.sh"
        "scripts/setup_production.sh"
        "scripts/rotate_logs.sh"
        "scripts/security_functions.sh"
        "scripts/upload_tiktok.sh"
        "scripts/upload_instagram.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [ ! -f "$script" ]; then
            log "ERROR" "Missing script: $script"
            return 1
        fi
        
        if [ ! -x "$script" ]; then
            log "ERROR" "Script not executable: $script"
            return 1
        fi
        
        # Basic syntax check
        if ! bash -n "$script"; then
            log "ERROR" "Syntax error in script: $script"
            return 1
        fi
    done
    
    log "SUCCESS" "All scripts validated"
    return 0
}

validate_environment() {
    log "INFO" "Validating environment configuration"
    
    if [ ! -f ".env.example" ]; then
        log "ERROR" "Missing .env.example file"
        return 1
    fi
    
    # Check for required environment variables in example
    local required_vars=(
        "POSTGRES_PASSWORD"
        "N8N_ENCRYPTION_KEY"
        "N8N_USER_MANAGEMENT_JWT_SECRET"
    )
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^$var=" ".env.example"; then
            log "ERROR" "Missing environment variable in .env.example: $var"
            return 1
        fi
    done
    
    log "SUCCESS" "Environment configuration validated"
    return 0
}

validate_docker_compose() {
    log "INFO" "Validating Docker Compose configuration"
    
    if [ ! -f "docker-compose.yml" ]; then
        log "ERROR" "Missing docker-compose.yml file"
        return 1
    fi
    
    # Check if docker-compose is valid
    if ! docker-compose config > /dev/null 2>&1; then
        log "ERROR" "Invalid docker-compose.yml syntax"
        return 1
    fi
    
    # Check for required services
    local required_services=("n8n" "postgres" "ollama-cpu" "qdrant")
    for service in "${required_services[@]}"; do
        if ! grep -q "^  $service:" "docker-compose.yml"; then
            log "ERROR" "Missing required service in docker-compose.yml: $service"
            return 1
        fi
    done
    
    log "SUCCESS" "Docker Compose configuration validated"
    return 0
}

validate_security_config() {
    log "INFO" "Validating security configuration"
    
    # Check nginx configuration
    if [ ! -f "nginx.conf" ]; then
        log "WARNING" "Missing nginx.conf - reverse proxy not configured"
    else
        # Check for security headers
        if ! grep -q "X-Frame-Options" "nginx.conf"; then
            log "WARNING" "Missing security headers in nginx.conf"
        fi
        
        # Check for rate limiting
        if ! grep -q "limit_req_zone" "nginx.conf"; then
            log "WARNING" "Rate limiting not configured in nginx.conf"
        fi
    fi
    
    # Check security functions
    if [ -f "scripts/security_functions.sh" ]; then
        if ! grep -q "validate_url" "scripts/security_functions.sh"; then
            log "ERROR" "Missing URL validation function"
            return 1
        fi
        
        if ! grep -q "check_rate_limit" "scripts/security_functions.sh"; then
            log "ERROR" "Missing rate limiting function"
            return 1
        fi
    fi
    
    log "SUCCESS" "Security configuration validated"
    return 0
}

validate_monitoring() {
    log "INFO" "Validating monitoring configuration"
    
    if [ ! -f "prometheus.yml" ]; then
        log "WARNING" "Missing prometheus.yml - monitoring not fully configured"
    else
        # Check for required scrape configs
        if ! grep -q "job_name: 'n8n'" "prometheus.yml"; then
            log "WARNING" "Missing n8n monitoring configuration"
        fi
    fi
    
    # Check for monitoring in docker-compose
    if ! grep -q "prometheus:" "docker-compose.yml"; then
        log "WARNING" "Prometheus not configured in docker-compose.yml"
    fi
    
    log "SUCCESS" "Monitoring configuration validated"
    return 0
}

check_system_dependencies() {
    log "INFO" "Checking system dependencies"
    
    local dependencies=("docker" "docker-compose" "curl" "jq")
    local missing_deps=()
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        return 1
    fi
    
    log "SUCCESS" "All system dependencies available"
    return 0
}

run_integration_tests() {
    log "INFO" "Running integration tests"
    
    # Test security functions
    if [ -f "scripts/security_functions.sh" ]; then
        # Source the functions
        source scripts/security_functions.sh
        
        # Test URL validation
        if validate_url "https://reddit.com/test"; then
            log "SUCCESS" "URL validation working"
        else
            log "ERROR" "URL validation not working"
            return 1
        fi
        
        # Test input sanitization
        local sanitized=$(sanitize_input "test; rm -rf /" 100)
        if [[ "$sanitized" == "test rm -rf /" ]]; then
            log "SUCCESS" "Input sanitization working"
        else
            log "ERROR" "Input sanitization not working properly"
            return 1
        fi
    fi
    
    log "SUCCESS" "Integration tests passed"
    return 0
}

generate_report() {
    log "INFO" "Generating validation report"
    
    echo ""
    echo "=================================="
    echo "PRODUCTION VALIDATION REPORT"
    echo "=================================="
    echo "Date: $(date)"
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ ALL TESTS PASSED - PRODUCTION READY${NC}"
        echo ""
        echo "Next Steps:"
        echo "1. Copy .env.example to .env and configure your environment variables"
        echo "2. Set up your social media API credentials"
        echo "3. Run: docker compose --profile cpu up -d"
        echo "4. Run: docker exec -it n8n /app/scripts/setup_production.sh"
        echo "5. Access n8n at http://localhost:5678"
        return 0
    else
        echo -e "${RED}❌ SOME TESTS FAILED - REVIEW REQUIRED${NC}"
        echo ""
        echo "Please fix the failed tests before deploying to production."
        return 1
    fi
}

# Main validation sequence
main() {
    log "INFO" "Starting production validation for Reddit Video Automation workflow"
    echo ""
    
    # Run all tests
    run_test "JSON Structure Validation" "validate_json_structure"
    run_test "Scripts Validation" "validate_scripts"
    run_test "Environment Configuration" "validate_environment"
    run_test "Docker Compose Configuration" "validate_docker_compose"
    run_test "Security Configuration" "validate_security_config"
    run_test "Monitoring Configuration" "validate_monitoring"
    run_test "System Dependencies" "check_system_dependencies"
    run_test "Integration Tests" "run_integration_tests"
    
    echo ""
    generate_report
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    main "$@"
fi