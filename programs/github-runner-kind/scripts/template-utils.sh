#!/usr/bin/env bash
# Template processing utilities for GitHub runner configurations

set -euo pipefail

# Process cached privileged template with volume mounts
process_cached_privileged_template() {
  local template_file="$1"
  local cache_paths="$2"
  local installation_name="$3"
  local output_file="$4"
  
  cp "$template_file" "$output_file"
  
  if [ -n "$cache_paths" ] && [ "$cache_paths" != "[]" ]; then
    # Add cache volume mounts for runner container
    local temp_json=$(mktemp)
    printf '%s\n' "$cache_paths" > "$temp_json"
    local cache_count
    cache_count=$(jq length < "$temp_json")
    
    for i in $(seq 0 $((cache_count-1))); do
      local cache_name
      local cache_path
      cache_name=$(jq -r ".[$i].name" < "$temp_json")
      cache_path=$(jq -r ".[$i].path" < "$temp_json")
      
      # Insert volume mount after the work volume mount using awk
      awk -v cache_name="$cache_name" -v cache_path="$cache_path" '
        /mountPath: \/home\/runner\/_work/ {
          print $0
          print "        - name: cache-" cache_name
          print "          mountPath: " cache_path
          next
        }
        { print }
      ' "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
      
      # Insert volume after work volume using awk
      local host_cache_path="/tmp/github-runner-cache/$installation_name/$cache_name"
      awk -v cache_name="$cache_name" -v host_path="$host_cache_path" '
        /emptyDir:/ && prev_line ~ /name: work/ {
          print $0
          print "      - name: cache-" cache_name
          print "        hostPath:"
          print "          path: " host_path
          print "          type: DirectoryOrCreate"
          next
        }
        { prev_line = $0; print }
      ' "$output_file" > "$output_file.tmp" && mv "$output_file.tmp" "$output_file"
    done
    
    rm -f "$temp_json"
  fi
  
  # Clean up placeholder comments
  sed -i '/# CACHE_VOLUME_MOUNTS will be dynamically inserted here/d' "$output_file"
  sed -i '/# CACHE_VOLUMES will be dynamically inserted here/d' "$output_file"
}

# Process DinD sidecar template 
process_dind_sidecar_template() {
  local template_file="$1"
  local dind_image="$2"
  local installation_name="$3"
  local dind_storage_size="$4"
  local output_file="$5"
  
  cp "$template_file" "$output_file"
  
  # Replace image placeholder
  sed -i "s|DIND_IMAGE_PLACEHOLDER|$dind_image|g" "$output_file"
  
  # Configure storage
  if [ -n "$dind_storage_size" ]; then
    # Use persistent volume claim
    sed -i '/# STORAGE_TYPE will be dynamically replaced with either persistentVolumeClaim or emptyDir/c\      persistentVolumeClaim:\n        claimName: dind-storage-'$installation_name "$output_file"
  else
    # Use emptyDir
    sed -i '/# STORAGE_TYPE will be dynamically replaced with either persistentVolumeClaim or emptyDir/c\      emptyDir: {}' "$output_file"
  fi
}

# Create PVC from template
create_dind_pvc() {
  local pvc_template="$1"
  local installation_name="$2"
  local storage_size="$3"
  local runners_namespace="$4"
  
  sed -e "s|INSTALLATION_NAME|$installation_name|g" \
      -e "s|STORAGE_SIZE|$storage_size|g" \
      -e "s|RUNNERS_NAMESPACE|$runners_namespace|g" \
      "$pvc_template" | kubectl apply -f -
}

# Export functions for use in other scripts
export -f process_cached_privileged_template
export -f process_dind_sidecar_template
export -f create_dind_pvc