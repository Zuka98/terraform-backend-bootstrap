#!/bin/bash

# Terraform State Cleanup Script
# This script removes Terraform state files from S3 and clears any stuck DynamoDB locks
# Usage: ./cleanup-project-state.sh <bucket-name> <dynamodb-table> <project-key> [--keep-md5]
# Example: ./cleanup-project-state.sh my-terraform-state terraform-locks "my-project/terraform.tfstate"

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Usage: $0 <bucket-name> <dynamodb-table> <project-key> [--keep-md5]"
    echo ""
    echo "Parameters:"
    echo "  bucket-name     : S3 bucket name containing Terraform state"
    echo "  dynamodb-table  : DynamoDB table name for state locking"
    echo "  project-key     : Project state key path (e.g., 'my-project/terraform.tfstate')"
    echo "  --keep-md5      : Optional. Keep MD5 integrity entries (default: remove them)"
    echo ""
    echo "Examples:"
    echo "  $0 my-terraform-state terraform-locks 'my-project/terraform.tfstate'"
    echo "  $0 company-tf-state tf-locks 'accounts/prod-123/web-app/terraform.tfstate'"
    echo "  $0 my-state terraform-locks 'project/terraform.tfstate' --keep-md5"
    echo ""
    echo "Note: Make sure AWS CLI is configured with appropriate permissions"
    echo "      MD5 entries are encryption-related checksums that can usually be removed"
}

confirm_action() {
    local message="$1"
    echo -e "${YELLOW}${message}${NC}"
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Operation cancelled by user"
        exit 0
    fi
}

check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed or not in PATH"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        print_error "jq is not installed or not in PATH (required for JSON processing)"
        print_info "Install jq: https://stedolan.github.io/jq/download/"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS CLI is not configured or credentials are invalid"
        exit 1
    fi
    
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_info=$(aws sts get-caller-identity --query Arn --output text)
    print_info "AWS CLI configured for account: $account_id"
    print_info "Using identity: $user_info"
}

list_s3_objects() {
    local bucket="$1"
    local project_key="$2"
    local project_prefix="${project_key%/*}"
    
    print_info "Checking S3 bucket '$bucket' for project files..."
    
    if aws s3 ls "s3://$bucket/$project_key" &> /dev/null; then
        print_warning "Found state file: s3://$bucket/$project_key"
        return 0
    fi
    
    local objects=$(aws s3 ls "s3://$bucket/$project_prefix/" 2>/dev/null || true)
    if [ -n "$objects" ]; then
        print_warning "Found project files in s3://$bucket/$project_prefix/:"
        echo "$objects"
        return 0
    fi
    
    print_info "No state files found for project"
    return 1
}

remove_s3_state() {
    local bucket="$1"
    local project_key="$2"
    local project_prefix="${project_key%/*}"
    
    print_info "Removing S3 state files..."
    
    if aws s3 rm "s3://$bucket/$project_prefix/" --recursive 2>/dev/null; then
        print_success "Removed project folder: s3://$bucket/$project_prefix/"
    else
        if aws s3 rm "s3://$bucket/$project_key" 2>/dev/null; then
            print_success "Removed state file: s3://$bucket/$project_key"
        else
            print_warning "No state files found to remove"
        fi
    fi
}

check_dynamodb_locks() {
    local table="$1"
    local project_key="$2"
    
    print_info "Checking DynamoDB table '$table' for locks and MD5 entries..."
    
    local all_items=$(aws dynamodb scan \
        --table-name "$table" \
        --filter-expression "contains(LockID, :project_key)" \
        --expression-attribute-values "{\":project_key\":{\"S\":\"${project_key%/*}\"}}" \
        --query "Items[]" \
        --output json 2>/dev/null || echo "[]")
    
    local real_locks=""
    local md5_entries=""
    local has_items=false
    
    if [ "$all_items" != "[]" ] && [ -n "$all_items" ]; then
        while IFS= read -r item; do
            if [ -n "$item" ]; then
                local lock_id=$(echo "$item" | jq -r '.LockID.S // empty')
                if [ -n "$lock_id" ]; then
                    has_items=true
                    if [[ "$lock_id" == *"-md5" ]]; then
                        local digest=$(echo "$item" | jq -r '.Digest.S // "N/A"')
                        md5_entries="${md5_entries}${lock_id} (digest: ${digest})\n"
                    else
                        local info=$(echo "$item" | jq -r '.Info.S // empty')
                        if [ -n "$info" ]; then
                            local operation=$(echo "$info" | jq -r '.Operation // "N/A"')
                            local who=$(echo "$info" | jq -r '.Who // "N/A"')
                            real_locks="${real_locks}${lock_id} (${operation} by ${who})\n"
                        else
                            real_locks="${real_locks}${lock_id}\n"
                        fi
                    fi
                fi
            fi
        done <<< "$(echo "$all_items" | jq -c '.[]')"
    fi
    
    if [ "$has_items" = false ]; then
        print_info "No locks or MD5 entries found"
        return 1
    fi
    
    if [ -n "$real_locks" ]; then
        print_warning "Found REAL Terraform locks (these should be removed):"
        echo -e "$real_locks"
    fi
    
    if [ -n "$md5_entries" ]; then
        print_info "Found MD5 integrity entries (these are normally persistent):"
        echo -e "$md5_entries"
        print_info "💡 MD5 entries are checksum records from S3 encryption - they're usually harmless"
    fi
    
    export FOUND_REAL_LOCKS="$real_locks"
    export FOUND_MD5_ENTRIES="$md5_entries"
    
    return 0
}

remove_dynamodb_locks() {
    local table="$1"
    local project_key="$2"
    local keep_md5="${3:-false}"
    
    print_info "Processing DynamoDB locks and entries..."
    
    if [ -n "$FOUND_REAL_LOCKS" ]; then
        print_info "Removing real Terraform locks..."
        while IFS= read -r lock_line; do
            if [ -n "$lock_line" ]; then
                local lock_id=$(echo "$lock_line" | cut -d' ' -f1)
                if aws dynamodb delete-item \
                    --table-name "$table" \
                    --key "{\"LockID\":{\"S\":\"$lock_id\"}}" &> /dev/null; then
                    print_success "Removed lock: $lock_id"
                else
                    print_error "Failed to remove lock: $lock_id"
                fi
            fi
        done <<< "$(echo -e "$FOUND_REAL_LOCKS")"
    fi
    
    if [ -n "$FOUND_MD5_ENTRIES" ]; then
        local remove_md5=true
        
        if [ "$keep_md5" = "true" ]; then
            remove_md5=false
            print_info "Keeping MD5 integrity entries (--keep-md5 specified)"
        else
            echo
            print_warning "Found MD5 integrity entries (encryption checksums):"
            echo -e "$FOUND_MD5_ENTRIES"
            print_info "💡 These are created by S3 encryption and are usually safe to remove"
            echo -e "${YELLOW}Do you want to remove these MD5 entries?${NC}"
            read -p "Remove MD5 entries? (Y/n): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Nn]$ ]]; then
                remove_md5=false
                print_info "Keeping MD5 integrity entries"
            else
                print_info "Will remove MD5 integrity entries"
            fi
        fi
        
        if [ "$remove_md5" = true ]; then
            print_info "Removing MD5 integrity entries..."
            while IFS= read -r md5_line; do
                if [ -n "$md5_line" ]; then
                    local lock_id=$(echo "$md5_line" | cut -d' ' -f1)
                    if aws dynamodb delete-item \
                        --table-name "$table" \
                        --key "{\"LockID\":{\"S\":\"$lock_id\"}}" &> /dev/null; then
                        print_success "Removed MD5 entry: $lock_id"
                    else
                        print_error "Failed to remove MD5 entry: $lock_id"
                    fi
                fi
            done <<< "$(echo -e "$FOUND_MD5_ENTRIES")"
        fi
    fi
    
    if [ -z "$FOUND_REAL_LOCKS" ] && [ -z "$FOUND_MD5_ENTRIES" ]; then
        print_info "No locks or entries to process"
    fi
}

verify_cleanup() {
    local bucket="$1"
    local table="$2"
    local project_key="$3"
    local keep_md5="$4"
    
    print_info "Verifying cleanup..."
    
    if list_s3_objects "$bucket" "$project_key" &> /dev/null; then
        print_warning "Some S3 files may still exist"
    else
        print_success "S3 cleanup verified - no project files found"
    fi
    
    export FOUND_REAL_LOCKS=""
    export FOUND_MD5_ENTRIES=""
    
    if check_dynamodb_locks "$table" "$project_key" &> /dev/null; then
        if [ -n "$FOUND_REAL_LOCKS" ]; then
            print_warning "Some real Terraform locks may still exist"
        else
            print_success "DynamoDB cleanup verified - no stuck locks found"
        fi
        
        if [ -n "$FOUND_MD5_ENTRIES" ]; then
            if [ "$keep_md5" = "true" ]; then
                print_success "MD5 integrity entries preserved (as requested)"
            else
                print_warning "Some MD5 entries may still exist (user may have chosen to keep them)"
            fi
        else
            if [ "$keep_md5" = "true" ]; then
                print_info "No MD5 entries found"
            else
                print_success "MD5 entries successfully removed"
            fi
        fi
    else
        print_success "DynamoDB cleanup verified - no locks or entries found"
    fi
}

main() {
    if [ $# -lt 3 ] || [ $# -gt 4 ]; then
        print_error "Invalid number of arguments"
        show_usage
        exit 1
    fi
    
    local bucket_name="$1"
    local dynamodb_table="$2"
    local project_key="$3"
    local keep_md5=false
    
    if [ $# -eq 4 ]; then
        if [ "$4" = "--keep-md5" ]; then
            keep_md5=true
        else
            print_error "Invalid option: $4"
            show_usage
            exit 1
        fi
    fi
    
    # Validate inputs
    if [ -z "$bucket_name" ] || [ -z "$dynamodb_table" ] || [ -z "$project_key" ]; then
        print_error "All parameters must be non-empty"
        show_usage
        exit 1
    fi
    
    print_info "Starting Terraform state cleanup..."
    print_info "Bucket: $bucket_name"
    print_info "DynamoDB Table: $dynamodb_table"
    print_info "Project Key: $project_key"
    if [ "$keep_md5" = true ]; then
        print_info "MD5 entries: WILL BE KEPT (--keep-md5 specified)"
    else
        print_info "MD5 entries: WILL PROMPT FOR REMOVAL (default behavior)"
    fi
    echo
    
    check_aws_cli
    echo
    
    local has_s3_files=false
    local has_dynamo_locks=false
    
    if list_s3_objects "$bucket_name" "$project_key"; then
        has_s3_files=true
        echo
    fi
    
    if check_dynamodb_locks "$dynamodb_table" "$project_key"; then
        has_dynamo_locks=true
        echo
    fi
    
    if [ "$has_s3_files" = false ] && [ "$has_dynamo_locks" = false ]; then
        print_success "Nothing to clean up - project state is already clean!"
        exit 0
    fi
    
    confirm_action "This will permanently delete the above Terraform state files and locks."
    echo
    
    if [ "$has_s3_files" = true ]; then
        remove_s3_state "$bucket_name" "$project_key"
        echo
    fi
    
    if [ "$has_dynamo_locks" = true ]; then
        remove_dynamodb_locks "$dynamodb_table" "$project_key" "$keep_md5"
        echo
    fi
    
    verify_cleanup "$bucket_name" "$dynamodb_table" "$project_key" "$keep_md5"
    echo
    
    print_success "Terraform state cleanup completed!"
}

main "$@" 