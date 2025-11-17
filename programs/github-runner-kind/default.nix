{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.github-runner-kind;
  
  repositoryType = types.submodule {
    options = {
      name = mkOption {
        type = types.str;
        description = "GitHub repository (owner/repo format)";
        example = "myorg/myproject";
      };
      
      installationName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Helm installation name (auto-generated if not specified)";
      };
      
      minRunners = mkOption {
        type = types.int;
        default = 0;
        description = "Minimum number of runners to keep available";
      };
      
      maxRunners = mkOption {
        type = types.int;
        default = 5;
        description = "Maximum number of runners to scale to";
      };
      
      containerMode = mkOption {
        type = types.enum [ "dind" "kubernetes" "kubernetes-novolume" "privileged-kubernetes" ];
        default = "kubernetes";
        description = "Container mode for runner (dind, kubernetes, kubernetes-novolume, privileged-kubernetes, rootless, or rootless-docker)";
      };
      
      dinDSidecar = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Docker-in-Docker sidecar container for OpenCode workspace support";
      };
      
      dinDImage = mkOption {
        type = types.str;
        default = "docker:24-dind";
        description = "Docker-in-Docker image to use for sidecar container";
      };
      
      dinDStorageSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Docker storage size for DinD sidecar (e.g., '20Gi'). Uses emptyDir if not set.";
        example = "20Gi";
      };
      
      instances = mkOption {
        type = types.int;
        default = 1;
        description = "Number of runner scale set instances to create for this repository";
      };
      

      
      buildCacheSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Build artifacts cache size (e.g., '10Gi', '20Gi'). When set, enables build cache volume.";
        example = "10Gi";
      };
      
      cachePaths = mkOption {
        type = types.listOf (types.submodule {
          options = {
            path = mkOption {
              type = types.str;
              description = "Container path to cache";
              example = "/nix/store";
            };
            name = mkOption {
              type = types.str;
              description = "Volume name identifier";
              example = "nix-store";
            };
          };
        });
        default = [];
        description = "List of paths to cache with hostPath volumes shared between workers (only for privileged-kubernetes mode)";
        example = literalExpression ''
          [
            { path = "/nix/store"; name = "nix-store"; }
            { path = "/var/lib/docker"; name = "docker-daemon"; }
            { path = "/root/.cache/nix"; name = "nix-cache"; }
          ]
        '';
      };

      workVolumeClaimTemplate = mkOption {
        type = types.nullOr (types.submodule {
          options = {
            storageClassName = mkOption {
              type = types.str;
              default = "standard";
              description = "Storage class for work volume PVC";
            };
            accessModes = mkOption {
              type = types.listOf types.str;
              default = ["ReadWriteOnce"];
              description = "Access modes for work volume PVC";
            };
            storage = mkOption {
              type = types.str;
              default = "10Gi";
              description = "Storage size for work volume";
              example = "10Gi";
            };
          };
        });
        default = null;
        description = "Work volume claim template for sharing workspace between runner and job containers in kubernetes mode";
        example = literalExpression ''
          {
            storageClassName = "standard";
            accessModes = ["ReadWriteOnce"];
            storage = "10Gi";
          }
        '';
      };
    };
  };
  
  processedRepos = map (repo: 
    let
      repoSlug = replaceStrings ["/"] ["-"] repo.name;
    in
    repo // {
      installationName = if repo.installationName != null then repo.installationName else "arc-runner-${repoSlug}";
    }
  ) cfg.repositories;
  
  expandedInstances = builtins.concatLists (map (repo: 
    if repo.instances > 1 then
      (map (instanceNum: 
        repo // {
          instanceId = instanceNum;
          installationName = "${repo.installationName}-${toString instanceNum}";
        }
      ) (builtins.genList (x: x + 1) repo.instances))
    else
      [ (repo // { instanceId = 1; }) ]
  ) processedRepos);
in
{
  options.programs.github-runner-kind = {
    enable = mkEnableOption "GitHub Actions Runner Controller with kind";

    repositories = mkOption {
      type = types.listOf repositoryType;
      default = [];
      description = "List of GitHub repositories to create runner scale sets for";
       example = literalExpression ''
          [
              {
                name = "myorg/project1";
                maxRunners = 3;
                buildCacheSize = "10Gi";
                containerMode = "privileged-kubernetes";
                cachePaths = [
                  { path = "/nix/store"; name = "nix-store"; }
                  { path = "/var/lib/docker"; name = "docker-daemon"; }
                ];
              }
             {
               name = "myorg/project2";
               maxRunners = 10;
               instances = 3;
               containerMode = "dind";
               dinDSidecar = false;
               dinDStorageSize = "20Gi";
             }
          ]
        '';
    };

    clusterName = mkOption {
      type = types.str;
      default = "github-runners";
      description = "Name for the shared kind cluster";
    };
    
    controllerNamespace = mkOption {
      type = types.str;
      default = "arc-systems";
      description = "Namespace for ARC controller pods";
    };
    
    runnersNamespace = mkOption {
      type = types.str;
      default = "arc-runners";
      description = "Namespace for runner pods";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.repositories != [];
        message = "Must specify at least one repository in repositories list";
      }
    ];

    home.packages = with pkgs; [
      kind
      kubectl
      kubernetes-helm
      docker
    ];

    home.file = {
      ".config/github-runner-kind/kind-config.yaml" = {
        text = ''
          kind: Cluster
          apiVersion: kind.x-k8s.io/v1alpha4
          name: ${cfg.clusterName}
          nodes:
          - role: control-plane
            extraPortMappings:
            - containerPort: 30080
              hostPort: 30080
              protocol: TCP
        '';
      };

      ".local/bin/github-runner-kind-manage" = {
        text = ''
#!/usr/bin/env bash
set -euo pipefail
          
          CLUSTER_NAME="${cfg.clusterName}"
          CONTROLLER_NAMESPACE="${cfg.controllerNamespace}"
          RUNNERS_NAMESPACE="${cfg.runnersNamespace}"
          CONFIG_DIR="${config.home.homeDirectory}/.config/github-runner-kind"
          
            declare -A REPOS
            declare -A INSTALLATION_NAMES
            declare -A MIN_RUNNERS
            declare -A MAX_RUNNERS
            declare -A CONTAINER_MODES
            declare -A BUILD_CACHE_SIZES
            declare -A CACHE_PATHS
            declare -A INSTANCE_IDS
            declare -A DIND_SIDECARS
            declare -A DIND_IMAGES
            declare -A DIND_STORAGE_SIZES
            declare -A WORK_VOLUME_CLAIM_TEMPLATES
           
           ${concatStringsSep "\n" (map (instance: 
             let
               instanceKey = "${instance.name}:${toString instance.instanceId}";
             in ''
              REPOS["${instanceKey}"]="${instance.name}"
              INSTALLATION_NAMES["${instanceKey}"]="${instance.installationName}"
              MIN_RUNNERS["${instanceKey}"]="${toString instance.minRunners}"
              MAX_RUNNERS["${instanceKey}"]="${toString instance.maxRunners}"
              CONTAINER_MODES["${instanceKey}"]="${instance.containerMode}"
              BUILD_CACHE_SIZES["${instanceKey}"]="${if instance.buildCacheSize != null then instance.buildCacheSize else ""}"
              CACHE_PATHS["${instanceKey}"]='${builtins.toJSON instance.cachePaths}'
              INSTANCE_IDS["${instanceKey}"]="${toString instance.instanceId}"
              DIND_SIDECARS["${instanceKey}"]="${if instance.dinDSidecar then "true" else "false"}"
              DIND_IMAGES["${instanceKey}"]="${instance.dinDImage}"
              DIND_STORAGE_SIZES["${instanceKey}"]="${if instance.dinDStorageSize != null then instance.dinDStorageSize else ""}"
              WORK_VOLUME_CLAIM_TEMPLATES["${instanceKey}"]='${if instance.workVolumeClaimTemplate != null then builtins.toJSON instance.workVolumeClaimTemplate else ""}'
           '') expandedInstances)}
          
          get_unique_repos() {
            printf '%s\n' "''${REPOS[@]}" | sort -u
          }
          
          get_repo_instances() {
            local repo="$1"
            for key in "''${!REPOS[@]}"; do
              if [[ "''${REPOS[$key]}" == "$repo" ]]; then
                echo "$key"
              fi
            done | sort
          }
          
          parse_repo_instance() {
            local arg="$1"
            local repo instance_num
            
            if [[ "$arg" == *":"* ]]; then
              repo="''${arg%:*}"
              instance_num="''${arg#*:}"
            else
              repo="$arg"
              instance_num="1"
            fi
            
            echo "$repo:$instance_num"
          }
          
          validate_instance() {
            local key="$1"
            if [[ ! ''${REPOS["$key"]+_} ]]; then
              echo "Error: Instance '$key' not configured"
              echo "Available instances:"
              printf '%s\n' "''${!REPOS[@]}" | sort
              exit 1
            fi
          }
          
          check_docker_ready() {
            if ! command -v docker >/dev/null 2>&1; then
              echo "Error: Docker command not found"
              exit 1
            fi
            
            if ! docker ps >/dev/null 2>&1; then
              echo "Error: Docker daemon not accessible"
              echo "Ensure Docker is running and your user has permissions"
              exit 1
            fi
          }
          
          check_cluster_exists() {
            kind get clusters 2>/dev/null | grep -q "^$CLUSTER_NAME$"
          }
          
          create_cluster() {
            echo "Creating kind cluster: $CLUSTER_NAME"
            check_docker_ready
            
            if check_cluster_exists; then
              echo "Cluster $CLUSTER_NAME already exists"
              return 0
            fi
            
            kind create cluster --config "$CONFIG_DIR/kind-config.yaml"
            echo "Cluster created successfully"
          }
          
          delete_cluster() {
            echo "Deleting kind cluster: $CLUSTER_NAME"
            
            if ! check_cluster_exists; then
              echo "Cluster $CLUSTER_NAME does not exist"
              return 0
            fi
            
            kind delete cluster --name "$CLUSTER_NAME"
            echo "Cluster deleted successfully"
          }
          
          install_controller() {
            echo "Installing Actions Runner Controller"
            
            if ! check_cluster_exists; then
              echo "Error: Cluster $CLUSTER_NAME does not exist. Run 'create-cluster' first."
              exit 1
            fi
            
            kubectl config use-context "kind-$CLUSTER_NAME"
            
            echo "Installing ARC controller in namespace: $CONTROLLER_NAMESPACE"
            helm install arc \
              --namespace "$CONTROLLER_NAMESPACE" \
              --create-namespace \
              oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set-controller
            
            echo "Waiting for controller to be ready..."
            kubectl wait --for=condition=available --timeout=300s \
              deployment/arc-gha-runner-scale-set-controller \
              -n "$CONTROLLER_NAMESPACE" || true
            
            echo "ARC controller installed successfully"
          }
          
          uninstall_controller() {
            echo "Uninstalling Actions Runner Controller"
            
            if ! check_cluster_exists; then
              echo "Cluster $CLUSTER_NAME does not exist"
              return 0
            fi
            
            kubectl config use-context "kind-$CLUSTER_NAME"
            
            helm uninstall arc -n "$CONTROLLER_NAMESPACE" || echo "Controller not installed"
            kubectl delete namespace "$CONTROLLER_NAMESPACE" --ignore-not-found=true
            
            echo "ARC controller uninstalled"
          }
          
             deploy_runner_set() {
               local arg="$1"
               local instance_key
               instance_key=$(parse_repo_instance "$arg")
               validate_instance "$instance_key"
               
               local repo="''${REPOS[$instance_key]}"
               local installation_name="''${INSTALLATION_NAMES[$instance_key]}"
               local min_runners="''${MIN_RUNNERS[$instance_key]}"
               local max_runners="''${MAX_RUNNERS[$instance_key]}"
                local container_mode="''${CONTAINER_MODES[$instance_key]}"
                local build_cache_size="''${BUILD_CACHE_SIZES[$instance_key]}"
                local cache_paths="''${CACHE_PATHS[$instance_key]}"
                local instance_id="''${INSTANCE_IDS[$instance_key]}"
                local dind_sidecar="''${DIND_SIDECARS[$instance_key]}"
                local dind_image="''${DIND_IMAGES[$instance_key]}"
                local dind_storage_size="''${DIND_STORAGE_SIZES[$instance_key]}"
                local work_volume_claim_template="''${WORK_VOLUME_CLAIM_TEMPLATES[$instance_key]}"
               
               echo "Deploying runner scale set for: $repo (instance $instance_id)"
               echo "Installation name: $installation_name"
               if [ "$dind_sidecar" = "true" ]; then
                 echo "DinD sidecar enabled: $dind_image"
                 if [ -n "$dind_storage_size" ]; then
                   echo "DinD storage size: $dind_storage_size"
                 fi
               fi
               
               if ! check_cluster_exists; then
                 echo "Error: Cluster $CLUSTER_NAME does not exist. Run 'create-cluster' first."
                 exit 1
               fi
               
               kubectl config use-context "kind-$CLUSTER_NAME"
               
               if ! command -v gh >/dev/null 2>&1; then
                 echo "Error: GitHub CLI (gh) not found"
                 exit 1
               fi
               
               if ! gh auth status >/dev/null 2>&1; then
                 echo "Error: GitHub CLI not authenticated. Run: gh auth login"
                 exit 1
               fi
               
               echo "Getting GitHub PAT..."
               GITHUB_PAT=$(gh auth token)
               
               if [ -z "$GITHUB_PAT" ]; then
                 echo "Error: Failed to get GitHub PAT"
                 exit 1
               fi
               
               echo "Installing runner scale set with Helm..."
               
                 # Build helm command with base parameters
                 HELM_CMD=(
                   helm upgrade --install "$installation_name"
                   --namespace "$RUNNERS_NAMESPACE"
                   --create-namespace
                   --set githubConfigUrl="https://github.com/$repo"
                   --set githubConfigSecret.github_token="$GITHUB_PAT"
                   --set controllerServiceAccount.name="arc-gha-rs-controller"
                   --set minRunners="$min_runners"
                   --set maxRunners="$max_runners"
                 )
                    # Configure container mode
                    if [ "$container_mode" = "kubernetes" ]; then
                      echo "Configuring Kubernetes mode with privileged capabilities"
                      HELM_CMD+=(
                        --set containerMode.type="kubernetes"
                      )
                      
                      # Add workVolumeClaimTemplate if specified
                      if [ -n "$work_volume_claim_template" ] && [ "$work_volume_claim_template" != "" ]; then
                        echo "Configuring work volume claim template for job containers"
                        
                        # Parse the JSON template
                        storage_class=$(echo "$work_volume_claim_template" | jq -r '.storageClassName')
                        access_modes=$(echo "$work_volume_claim_template" | jq -r '.accessModes | join(",")')
                        storage=$(echo "$work_volume_claim_template" | jq -r '.storage')
                        
                        # Add kubernetesModeWorkVolumeClaim configuration to Helm 
                        HELM_CMD+=(
                          --set containerMode.kubernetesModeWorkVolumeClaim.storageClassName="$storage_class"
                          --set-json containerMode.kubernetesModeWorkVolumeClaim.accessModes="$(echo "$work_volume_claim_template" | jq '.accessModes')"
                          --set containerMode.kubernetesModeWorkVolumeClaim.resources.requests.storage="$storage"
                        )
                      fi
                      
                      # Add privileged template values for OpenCode workflows
                      TEMP_PRIVILEGED_VALUES=$(mktemp)
                      cat > "$TEMP_PRIVILEGED_VALUES" <<EOF
template:
  spec:
    securityContext:
      runAsUser: 0
      runAsGroup: 0
      fsGroup: 0
    containers:
    - name: "\$job"
      securityContext:
        privileged: true
        runAsUser: 0
        runAsGroup: 0
        allowPrivilegeEscalation: true
        readOnlyRootFilesystem: false
        capabilities:
          add:
            - SYS_ADMIN
            - NET_ADMIN
            - SYS_PTRACE
            - SYS_CHROOT
            - SETFCAP
            - SETPCAP
            - NET_RAW
            - IPC_LOCK
            - SYS_RESOURCE
            - MKNOD
            - AUDIT_WRITE
            - AUDIT_CONTROL
      volumeMounts:
        - name: cgroup
          mountPath: /sys/fs/cgroup
          readOnly: false
        - name: proc
          mountPath: /proc
          readOnly: false
        - name: dev
          mountPath: /dev
          readOnly: false
      env:
        - name: SYSTEMD_IGNORE_CHROOT
          value: "1"
    volumes:
      - name: cgroup
        hostPath:
          path: /sys/fs/cgroup
          type: Directory
      - name: proc
        hostPath:
          path: /proc
          type: Directory
      - name: dev
        hostPath:
          path: /dev
          type: Directory
EOF
                      HELM_CMD+=(--values "$TEMP_PRIVILEGED_VALUES")
                      
                      # Add simple cache volume configuration for kubernetes mode
                      if [ -n "$cache_paths" ] && [ "$cache_paths" != "[]" ]; then
                        echo "Configuring cache volumes for instance $instance_id"
                        
                        # Create temporary values file for cache volumes
                        TEMP_CACHE_VALUES=$(mktemp)
                        cat > "$TEMP_CACHE_VALUES" <<EOF
template:
  spec:
    volumes:
EOF
                        
                        # Add cache volumes
                        TEMP_JSON=$(mktemp)
                        printf '%s\n' "$cache_paths" > "$TEMP_JSON"
                        cache_count=$(jq length < "$TEMP_JSON")
                        for i in $(seq 0 $((cache_count-1))); do
                          cache_name=$(jq -r ".[$i].name" < "$TEMP_JSON")
                          cache_path=$(jq -r ".[$i].path" < "$TEMP_JSON")
                          # Each instance gets its own dedicated cache directory
                          host_cache_path="/tmp/github-runner-cache/$installation_name/$cache_name"
                          cat >> "$TEMP_CACHE_VALUES" <<EOF
    - name: cache-$cache_name
      hostPath:
        path: $host_cache_path
        type: DirectoryOrCreate
EOF
                        done
                        rm -f "$TEMP_JSON"
                        
                        # Add cache volume mounts to job container
                        cat >> "$TEMP_CACHE_VALUES" <<EOF
    containers:
    - name: "\$job"
      volumeMounts:
EOF
                        
                        # Add cache volume mounts
                        TEMP_JSON=$(mktemp)
                        printf '%s\n' "$cache_paths" > "$TEMP_JSON"
                        cache_count=$(jq length < "$TEMP_JSON")
                        for i in $(seq 0 $((cache_count-1))); do
                          cache_name=$(jq -r ".[$i].name" < "$TEMP_JSON")
                          cache_path=$(jq -r ".[$i].path" < "$TEMP_JSON")
                          cat >> "$TEMP_CACHE_VALUES" <<EOF
      - name: cache-$cache_name
        mountPath: $cache_path
EOF
                        done
                        rm -f "$TEMP_JSON"
                        
                        HELM_CMD+=(--values "$TEMP_CACHE_VALUES")
                      fi
                   elif [ "$container_mode" = "kubernetes-novolume" ]; then
                    echo "Configuring Kubernetes no-volume mode (uses lifecycle hooks)"
                    HELM_CMD+=(
                      --set containerMode.type="kubernetes-novolume"
                    )
                   elif [ "$container_mode" = "privileged-kubernetes" ]; then
                     echo "Configuring privileged Kubernetes mode with workVolumeClaimTemplate support"
                     # Don't set containerMode.type to avoid automatic template generation
                     
                     # Add workVolumeClaimTemplate support for privileged mode
                     if [ -n "$work_volume_claim_template" ] && [ "$work_volume_claim_template" != "" ]; then
                       echo "Configuring work volume claim template for privileged job containers"
                     fi
                     
                     # Create enhanced RBAC permissions for privileged-kubernetes mode
                     echo "Creating enhanced RBAC permissions for privileged container operations..."
                     cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $installation_name-privileged-manager
  namespace: $RUNNERS_NAMESPACE
  labels:
    actions.github.com/scale-set-name: $installation_name
    app.kubernetes.io/instance: $installation_name
    app.kubernetes.io/component: privileged-manager-role
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["create", "delete", "get", "list"]
- apiGroups: [""]
  resources: ["pods/status"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["get", "create"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["create", "delete", "get", "list", "patch", "update"]
- apiGroups: [""]
  resources: ["serviceaccounts"]
  verbs: ["create", "delete", "get", "list", "patch", "update"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["rolebindings"]
  verbs: ["create", "delete", "get", "patch", "update"]
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles"]
  verbs: ["create", "delete", "get", "patch", "update"]
- apiGroups: ["batch"]
  resources: ["jobs"]
  verbs: ["get", "list", "create", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $installation_name-privileged-pod-manager
  namespace: $RUNNERS_NAMESPACE
  labels:
    actions.github.com/scale-set-name: $installation_name
    app.kubernetes.io/instance: $installation_name
    app.kubernetes.io/component: privileged-pod-manager-binding
subjects:
- kind: ServiceAccount
  name: $installation_name-gha-rs-no-permission
  namespace: $RUNNERS_NAMESPACE
roleRef:
  kind: Role
  name: $installation_name-privileged-manager
  apiGroup: rbac.authorization.k8s.io
EOF
                     
                      # Create ConfigMap for privileged hook extension with workVolumeClaimTemplate support
                      echo "Creating ConfigMap for privileged container hook extension..."
                      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: privileged-hook-extension-$installation_name
  namespace: $RUNNERS_NAMESPACE
data:
  content: |
     metadata:
       annotations:
         privileged-containers.actions.github.com/enabled: "true"
     spec:
       securityContext:
         runAsUser: 0
         runAsGroup: 0
         fsGroup: 0
       containers:
         - name: "\$job"
           securityContext:
             privileged: true
             runAsUser: 0
             runAsGroup: 0
             allowPrivilegeEscalation: true
             readOnlyRootFilesystem: false
             capabilities:
               add:
                 - SYS_ADMIN
                 - NET_ADMIN
                 - SYS_PTRACE
                 - SYS_CHROOT
                 - SETFCAP
                 - SETPCAP
                 - NET_RAW
                 - IPC_LOCK
                 - SYS_RESOURCE
                 - MKNOD
                 - AUDIT_WRITE
                 - AUDIT_CONTROL
           volumeMounts:
             - name: cgroup
               mountPath: /sys/fs/cgroup
               readOnly: false
               mountPropagation: Bidirectional
             - name: proc
               mountPath: /proc
               readOnly: false
             - name: dev
               mountPath: /dev
               readOnly: false
           env:
             - name: SYSTEMD_IGNORE_CHROOT
               value: "1"
       volumes:
EOF
                     
                      # Add system volumes for privileged containers
                      cat <<EOF | kubectl patch configmap privileged-hook-extension-$installation_name -n $RUNNERS_NAMESPACE --type merge -p '
data:
  content: |
     metadata:
       annotations:
         privileged-containers.actions.github.com/enabled: "true"
     spec:
       securityContext:
         runAsUser: 0
         runAsGroup: 0
         fsGroup: 0
       containers:
         - name: "\$job"
           securityContext:
             privileged: true
             runAsUser: 0
             runAsGroup: 0
             allowPrivilegeEscalation: true
             readOnlyRootFilesystem: false
             capabilities:
               add:
                 - SYS_ADMIN
                 - NET_ADMIN
                 - SYS_PTRACE
                 - SYS_CHROOT
                 - SETFCAP
                 - SETPCAP
                 - NET_RAW
                 - IPC_LOCK
                 - SYS_RESOURCE
                 - MKNOD
                 - AUDIT_WRITE
                 - AUDIT_CONTROL
           volumeMounts:
             - name: cgroup
               mountPath: /sys/fs/cgroup
               readOnly: false
               mountPropagation: Bidirectional
             - name: proc
               mountPath: /proc
               readOnly: false
             - name: dev
               mountPath: /dev
               readOnly: false
           env:
             - name: SYSTEMD_IGNORE_CHROOT
               value: "1"
       volumes:
         - name: cgroup
           hostPath:
             path: /sys/fs/cgroup
             type: Directory
         - name: proc
           hostPath:
             path: /proc
             type: Directory
         - name: dev
           hostPath:
             path: /dev
             type: Directory
'
EOF
                     
                     # Create simplified template for privileged mode with dedicated cache per instance
                     TEMP_PRIVILEGED_VALUES=$(mktemp)
                     cat > "$TEMP_PRIVILEGED_VALUES" <<EOF
template:
  spec:
    containers:
    - name: runner
      image: ghcr.io/actions/actions-runner:latest
      command: ["/home/runner/run.sh"]
      env:
      - name: ACTIONS_RUNNER_CONTAINER_HOOKS
        value: /home/runner/k8s/index.js
      - name: ACTIONS_RUNNER_POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
      - name: ACTIONS_RUNNER_REQUIRE_JOB_CONTAINER
        value: "false"
      - name: ACTIONS_RUNNER_CONTAINER_HOOK_TEMPLATE
        value: "/etc/hooks/content"
      volumeMounts:
      - name: work
        mountPath: /home/runner/_work
      - name: privileged-hook-extension
        mountPath: /etc/hooks
        readOnly: true
EOF

                     # Add cache volume mounts - each instance gets dedicated cache (no partitioning needed)
                     if [ -n "$cache_paths" ] && [ "$cache_paths" != "[]" ]; then
                       TEMP_JSON=$(mktemp)
                       printf '%s\n' "$cache_paths" > "$TEMP_JSON"
                       cache_count=$(jq length < "$TEMP_JSON")
                       for i in $(seq 0 $((cache_count-1))); do
                         cache_name=$(jq -r ".[$i].name" < "$TEMP_JSON")
                         cache_path=$(jq -r ".[$i].path" < "$TEMP_JSON")
                         cat >> "$TEMP_PRIVILEGED_VALUES" <<EOF
      - name: cache-$cache_name
        mountPath: $cache_path
EOF
                       done
                       rm -f "$TEMP_JSON"
                     fi
                     
                     # Add volumes section
                     cat >> "$TEMP_PRIVILEGED_VALUES" <<EOF
    volumes:
    - name: work
      emptyDir: {}
    - name: privileged-hook-extension
      configMap:
        name: privileged-hook-extension-$installation_name
EOF

                     # Add cache volumes - dedicated directory per instance (no partitioning complexity)
                     if [ -n "$cache_paths" ] && [ "$cache_paths" != "[]" ]; then
                       TEMP_JSON=$(mktemp)
                       printf '%s\n' "$cache_paths" > "$TEMP_JSON"
                       cache_count=$(jq length < "$TEMP_JSON")
                       for i in $(seq 0 $((cache_count-1))); do
                         cache_name=$(jq -r ".[$i].name" < "$TEMP_JSON")
                         # Each instance gets dedicated cache directory - no partitioning needed
                         host_cache_path="/tmp/github-runner-cache/$installation_name/$cache_name"
                         cat >> "$TEMP_PRIVILEGED_VALUES" <<EOF
    - name: cache-$cache_name
      hostPath:
        path: $host_cache_path
        type: DirectoryOrCreate
EOF
                       done
                       rm -f "$TEMP_JSON"
                     fi
                     
                     HELM_CMD+=(--values "$TEMP_PRIVILEGED_VALUES")
                   else
                     echo "Configuring DIND mode"
                     HELM_CMD+=(
                       --set containerMode.type="dind"
                     )
                   fi
                
                  # Add DinD sidecar configuration if enabled
                  if [ "$dind_sidecar" = "true" ]; then
                    echo "Adding DinD sidecar container for Docker access via TCP"
                    
                    # Create temporary values file with proper YAML structure
                    TEMP_VALUES=$(mktemp)
                    
                    # Configure DinD storage volume first
                    if [ -n "$dind_storage_size" ]; then
                      echo "Configuring persistent DinD storage: $dind_storage_size"
                      
                      # Create PVC for DinD storage
                      echo "Creating persistent volume claim for DinD storage..."
                      cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: dind-storage-$installation_name
  namespace: $RUNNERS_NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $dind_storage_size
  storageClassName: standard
EOF
                      
                      # Write Helm values with persistent volume
                      cat > "\$TEMP_VALUES" <<'EOF'
template:
  spec:
    env:
    - name: DOCKER_HOST
      value: tcp://localhost:2375
    containers:
    - name: runner
      image: ghcr.io/actions/actions-runner:latest
      env:
      - name: DOCKER_HOST
        value: tcp://localhost:2375
    - name: dind
      image: DIND_IMAGE_PLACEHOLDER
      securityContext:
        privileged: true
      env:
      - name: DOCKER_TLS_CERTDIR
        value: ""
      ports:
      - containerPort: 2375
        name: docker
        protocol: TCP
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "1"
          memory: "2Gi"
      volumeMounts:
      - name: docker-storage
        mountPath: /var/lib/docker
    volumes:
    - name: docker-storage
      persistentVolumeClaim:
        claimName: STORAGE_CLAIM_PLACEHOLDER
EOF
                    else
                      echo "Using emptyDir for DinD storage (temporary)"
                      
                      # Write Helm values with emptyDir volume
                      cat > "\$TEMP_VALUES" <<'EOF'
template:
  spec:
    env:
    - name: DOCKER_HOST
      value: tcp://localhost:2375
    containers:
    - name: runner
      image: ghcr.io/actions/actions-runner:latest
      env:
      - name: DOCKER_HOST
        value: tcp://localhost:2375
    - name: dind
      image: DIND_IMAGE_PLACEHOLDER
      securityContext:
        privileged: true
      env:
      - name: DOCKER_TLS_CERTDIR
        value: ""
      ports:
      - containerPort: 2375
        name: docker
        protocol: TCP
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "1"
          memory: "2Gi"
      volumeMounts:
      - name: docker-storage
        mountPath: /var/lib/docker
    volumes:
    - name: docker-storage
      emptyDir: {}
EOF
                    fi
                    
                    # Replace placeholders with actual values
                    sed -i "s|DIND_IMAGE_PLACEHOLDER|$dind_image|g" "\$TEMP_VALUES"
                    if [ -n "$dind_storage_size" ]; then
                      sed -i "s|STORAGE_CLAIM_PLACEHOLDER|dind-storage-$installation_name|g" "\$TEMP_VALUES"
                    fi
                    
                    # Add values file to helm command
                    HELM_CMD+=(--values "\$TEMP_VALUES")
                  fi
               
               # Add chart URL and execute command
               HELM_CMD+=(oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set)
               
                  # Execute the helm command
                  "''${HELM_CMD[@]}"
               
               echo "Waiting for listener pod to be ready..."
               kubectl wait --for=condition=ready --timeout=300s \
                 pod -l app.kubernetes.io/instance="$installation_name" \
                 -n "$RUNNERS_NAMESPACE" || true
               
                 echo "Runner scale set deployed successfully"
                 if [ -n "$cache_paths" ] && [ "$cache_paths" != "[]" ]; then
                   echo "Deterministic cache partitions configured (workers reuse cache slots):"
                   # Write JSON to temp file to avoid shell expansion issues
                   TEMP_JSON=$(mktemp)
                   printf '%s\n' "$cache_paths" > "$TEMP_JSON"
                   cache_count=$(jq length < "$TEMP_JSON")
                   for i in $(seq 0 $((cache_count-1))); do
                     cache_name=$(jq -r ".[$i].name" < "$TEMP_JSON")
                     cache_path=$(jq -r ".[$i].path" < "$TEMP_JSON")
                     echo "  - $cache_path: partitioned into $max_runners slots (hostPath: /tmp/github-runner-cache/$installation_name/$cache_name/{0..$((max_runners-1))})"
                   done
                   rm -f "$TEMP_JSON"
                   echo "  Total cache paths: $cache_count"
                   echo "  Cache partitions: 0 to $((max_runners-1)) (reused across job runs)"
                   echo "  Prevents Nix store conflicts and maximizes cache hits"
                 fi
                if [ -n "$build_cache_size" ]; then
                  echo "Build artifacts cache enabled with size: $build_cache_size"
                  echo "Cache available at: /runner/_work/_cache"
                fi
                if [ "$dind_sidecar" = "true" ]; then
                  echo "DinD sidecar enabled - Docker available at tcp://localhost:2375"
                  echo "OpenCode workspace action will automatically detect and use Docker"
                fi
               echo "Use this in your workflow:"
               echo "  runs-on: $installation_name"
             }
          
           remove_runner_set() {
             local arg="$1"
             local instance_key
             instance_key=$(parse_repo_instance "$arg")
             validate_instance "$instance_key"
             
              local installation_name="''${INSTALLATION_NAMES[$instance_key]}"
              local instance_id="''${INSTANCE_IDS[$instance_key]}"
              local repo="''${REPOS[$instance_key]}"
              local max_runners="''${MAX_RUNNERS[$instance_key]}"
             
             echo "Removing runner scale set: $installation_name (instance $instance_id for $repo)"
             
             if ! check_cluster_exists; then
               echo "Cluster $CLUSTER_NAME does not exist"
               return 0
             fi
             
             kubectl config use-context "kind-$CLUSTER_NAME"
             
                helm uninstall "$installation_name" -n "$RUNNERS_NAMESPACE" || echo "Runner set not installed"
                
                # Clean up DinD storage PVC if it exists
                kubectl delete pvc "dind-storage-$installation_name" -n "$RUNNERS_NAMESPACE" --ignore-not-found=true
                
                # Clean up cache partition locks
                rm -rf "/tmp/github-runner-cache-locks/$installation_name" 2>/dev/null || true
                
                # Note: hostPath cache directories are not cleaned up automatically
                echo "Note: Cache partitions persist at /tmp/github-runner-cache/$installation_name/{cache-name}/{0..$((max_runners-1))} on kind host"
                echo "Note: Cache locks cleaned up from /tmp/github-runner-cache-locks/$installation_name/"
               
               # Clean up privileged hook extension ConfigMap if it exists
               kubectl delete configmap "privileged-hook-extension-$installation_name" -n "$RUNNERS_NAMESPACE" --ignore-not-found=true
               
               # Clean up privileged-kubernetes RBAC resources if they exist
               kubectl delete rolebinding "$installation_name-privileged-pod-manager" -n "$RUNNERS_NAMESPACE" --ignore-not-found=true
               kubectl delete role "$installation_name-privileged-manager" -n "$RUNNERS_NAMESPACE" --ignore-not-found=true
             
             echo "Runner scale set removed"
           }
          
          deploy_all() {
            echo "Deploying all runner scale sets..."
            for instance_key in "''${!REPOS[@]}"; do
              repo="''${REPOS[$instance_key]}"
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Deploying $repo:$instance_id ==="
              deploy_runner_set "$instance_key"
            done
          }
          
          remove_all() {
            echo "Removing all runner scale sets..."
            for instance_key in "''${!REPOS[@]}"; do
              repo="''${REPOS[$instance_key]}"
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Removing $repo:$instance_id ==="
              remove_runner_set "$instance_key"
            done
          }
          
          deploy_repo_all() {
            local repo="$1"
            echo "Deploying all instances for repository: $repo"
            for instance_key in $(get_repo_instances "$repo"); do
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Deploying $repo:$instance_id ==="
              deploy_runner_set "$instance_key"
            done
          }
          
          remove_repo_all() {
            local repo="$1"
            echo "Removing all instances for repository: $repo"
            for instance_key in $(get_repo_instances "$repo"); do
              instance_id="''${INSTANCE_IDS[$instance_key]}"
              echo ""
              echo "=== Removing $repo:$instance_id ==="
              remove_runner_set "$instance_key"
            done
          }
          
          show_status() {
            local arg="''${1:-}"
            
            if ! check_cluster_exists; then
              echo "Cluster $CLUSTER_NAME does not exist"
              echo "Run 'github-runner-kind-manage create-cluster' to create it"
              return
            fi
            
            kubectl config use-context "kind-$CLUSTER_NAME"
            
            if [ -n "$arg" ]; then
              local instance_key
              instance_key=$(parse_repo_instance "$arg")
              validate_instance "$instance_key"
              
              local repo="''${REPOS[$instance_key]}"
              local installation_name="''${INSTALLATION_NAMES[$instance_key]}"
              local instance_id="''${INSTANCE_IDS[$instance_key]}"
              
              echo "=== Status for $repo (instance $instance_id) ==="
              echo "Installation name: $installation_name"
              echo ""
              echo "Listener Pod:"
              kubectl get pods -n "$RUNNERS_NAMESPACE" -l app.kubernetes.io/instance="$installation_name"
              echo ""
              echo "Runner Pods:"
              kubectl get pods -n "$RUNNERS_NAMESPACE" -l actions.github.com/scale-set-name="$installation_name"
              return
            fi
            
            echo "=== Cluster Status ==="
            kubectl cluster-info --context "kind-$CLUSTER_NAME"
            echo ""
            
            echo "=== ARC Controller Status ==="
            if kubectl get namespace "$CONTROLLER_NAMESPACE" >/dev/null 2>&1; then
              kubectl get pods -n "$CONTROLLER_NAMESPACE"
            else
              echo "Controller namespace not found"
            fi
            echo ""
            
            echo "=== Runner Scale Sets ==="
            if kubectl get namespace "$RUNNERS_NAMESPACE" >/dev/null 2>&1; then
              for repo in $(get_unique_repos); do
                echo ""
                echo "--- Repository: $repo ---"
                for instance_key in $(get_repo_instances "$repo"); do
                  installation_name="''${INSTALLATION_NAMES[$instance_key]}"
                  instance_id="''${INSTANCE_IDS[$instance_key]}"
                  echo "  Instance $instance_id ($installation_name):"
                  kubectl get pods -n "$RUNNERS_NAMESPACE" -l app.kubernetes.io/instance="$installation_name" --no-headers 2>/dev/null | awk '{print "    " $0}' || echo "    No pods"
                done
              done
              echo ""
              echo "Helm Releases:"
              helm list -n "$RUNNERS_NAMESPACE"
            else
              echo "Runners namespace not found"
            fi
          }
          
          show_logs() {
            local component="''${1:-controller}"
            
            if ! check_cluster_exists; then
              echo "Cluster $CLUSTER_NAME does not exist"
              exit 1
            fi
            
            kubectl config use-context "kind-$CLUSTER_NAME"
            
            case "$component" in
              controller)
                echo "=== ARC Controller Logs ==="
                kubectl logs -n "$CONTROLLER_NAMESPACE" \
                  -l app.kubernetes.io/name=gha-runner-scale-set-controller \
                  --tail=100 -f
                ;;
              listener)
                echo "=== Listener Pods Logs ==="
                kubectl logs -n "$RUNNERS_NAMESPACE" \
                  -l app.kubernetes.io/component=runner-scale-set-listener \
                  --tail=100 -f
                ;;
              runners)
                echo "=== Runner Pods Logs ==="
                kubectl logs -n "$RUNNERS_NAMESPACE" \
                  -l actions.github.com/scale-set-name \
                  --tail=100 -f
                ;;
              *)
                echo "Error: Unknown component '$component'"
                echo "Valid components: controller, listener, runners"
                exit 1
                ;;
            esac
          }
          
          setup() {
            echo "=== Setting up GitHub Actions Runner Controller ==="
            echo ""
            echo "Step 1: Creating kind cluster..."
            create_cluster
            echo ""
            echo "Step 2: Installing ARC controller..."
            install_controller
            echo ""
            echo "Step 3: Deploying runner scale sets..."
            deploy_all
            echo ""
            echo "=== Setup Complete ==="
            echo ""
            show_status
          }
          
          teardown() {
            echo "=== Tearing down GitHub Actions Runner Controller ==="
            echo ""
            echo "Step 1: Removing runner scale sets..."
            remove_all || true
            echo ""
            echo "Step 2: Uninstalling ARC controller..."
            uninstall_controller || true
            echo ""
            echo "Step 3: Deleting kind cluster..."
            delete_cluster
            echo ""
            echo "=== Teardown Complete ==="
          }
          
          show_usage() {
            echo "Usage: $0 <command> [args]"
            echo ""
            echo "Shared Cluster: $CLUSTER_NAME"
            echo ""
            echo "Cluster Management:"
            echo "  create-cluster          - Create shared kind cluster"
            echo "  delete-cluster          - Delete shared kind cluster"
            echo "  install-controller      - Install ARC controller"
            echo "  uninstall-controller    - Uninstall ARC controller"
            echo ""
            echo "Runner Scale Set Management:"
            echo "  deploy <repo[:inst]>    - Deploy runner scale set for repository instance"
            echo "  deploy-all              - Deploy all configured runner scale sets"
            echo "  deploy-repo-all <repo>  - Deploy all instances for a repository"
            echo "  remove <repo[:inst]>    - Remove runner scale set for repository instance"
            echo "  remove-all              - Remove all runner scale sets"
            echo "  remove-repo-all <repo>  - Remove all instances for a repository"
            echo ""
            echo "Monitoring:"
            echo "  status [repo[:inst]]    - Show cluster/runner status (all or specific)"
            echo "  logs [component]        - Show logs (controller|listener|runners)"
            echo ""
            echo "Convenience:"
            echo "  setup                   - Complete setup (cluster + controller + runners)"
            echo "  teardown                - Complete teardown (runners + controller + cluster)"
            echo ""
            echo "Available repository instances:"
            if [ ''${#REPOS[@]} -eq 0 ]; then
              echo "  None configured"
            else
              for repo in $(get_unique_repos); do
                echo "  $repo:"
                for instance_key in $(get_repo_instances "$repo"); do
                  installation_name="''${INSTALLATION_NAMES[$instance_key]}"
                  instance_id="''${INSTANCE_IDS[$instance_key]}"
                  echo "    Instance $instance_id: runs-on: $installation_name"
                done
              done
            fi
            echo ""
            echo "Examples:"
            echo "  $0 setup                         # Complete setup"
            echo "  $0 deploy myorg/myproject        # Deploy instance 1 (default)"
            echo "  $0 deploy myorg/myproject:2      # Deploy instance 2"
            echo "  $0 deploy-repo-all myorg/myproject  # Deploy all instances for repo"
            echo "  $0 status                        # Show all status"
            echo "  $0 status myorg/myproject:2      # Show specific instance status"
            echo "  $0 logs controller               # View controller logs"
            echo "  $0 teardown                      # Complete teardown"
            echo ""
            echo "Note: If no instance number is specified, defaults to instance 1"
          }
          
          case "''${1:-}" in
            create-cluster)
              create_cluster
              ;;
            delete-cluster)
              delete_cluster
              ;;
            install-controller)
              install_controller
              ;;
            uninstall-controller)
              uninstall_controller
              ;;
            deploy)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository required"
                show_usage
                exit 1
              fi
              deploy_runner_set "$2"
              ;;
            deploy-all)
              deploy_all
              ;;
            remove)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository required"
                show_usage
                exit 1
              fi
              remove_runner_set "$2"
              ;;
            remove-all)
              remove_all
              ;;
            deploy-repo-all)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository required"
                show_usage
                exit 1
              fi
              deploy_repo_all "$2"
              ;;
            remove-repo-all)
              if [ -z "''${2:-}" ]; then
                echo "Error: Repository required"
                show_usage
                exit 1
              fi
              remove_repo_all "$2"
              ;;
            status)
              show_status "''${2:-}"
              ;;
            logs)
              show_logs "''${2:-controller}"
              ;;
            setup)
              setup
              ;;
            teardown)
              teardown
              ;;
            *)
              show_usage
              exit 1
              ;;
          esac
        '';
        executable = true;
      };
    };
  };
}
