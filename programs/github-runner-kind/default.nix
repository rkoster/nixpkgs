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
        type = types.enum [ "dind" "kubernetes" ];
        default = "dind";
        description = "Container mode for runner (dind or kubernetes)";
      };
      
      instances = mkOption {
        type = types.int;
        default = 1;
        description = "Number of runner scale set instances to create for this repository";
      };
      
      cacheSize = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Cache size for runners (e.g., '10Gi', '5Gi'). When set, enables cache overlay.";
        example = "10Gi";
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
             cacheSize = "5Gi";
           }
           {
             name = "myorg/project2";
             maxRunners = 10;
             instances = 3;
             containerMode = "kubernetes";
             cacheSize = "10Gi";
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
          #!/bin/bash
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
           declare -A CACHE_SIZES
           declare -A INSTANCE_IDS
           
           ${concatStringsSep "\n" (map (instance: 
             let
               instanceKey = "${instance.name}:${toString instance.instanceId}";
             in ''
             REPOS["${instanceKey}"]="${instance.name}"
             INSTALLATION_NAMES["${instanceKey}"]="${instance.installationName}"
             MIN_RUNNERS["${instanceKey}"]="${toString instance.minRunners}"
             MAX_RUNNERS["${instanceKey}"]="${toString instance.maxRunners}"
             CONTAINER_MODES["${instanceKey}"]="${instance.containerMode}"
             CACHE_SIZES["${instanceKey}"]="${if instance.cacheSize != null then instance.cacheSize else ""}"
             INSTANCE_IDS["${instanceKey}"]="${toString instance.instanceId}"
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
             local cache_size="''${CACHE_SIZES[$instance_key]}"
             local instance_id="''${INSTANCE_IDS[$instance_key]}"
             
             echo "Deploying runner scale set for: $repo (instance $instance_id)"
             echo "Installation name: $installation_name"
             
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
               --set minRunners="$min_runners"
               --set maxRunners="$max_runners"
               --set containerMode.type="$container_mode"
             )
             
             # Add cache overlay configuration if cache size is specified
             if [ -n "$cache_size" ]; then
               echo "Enabling cache overlay with size: $cache_size"
               HELM_CMD+=(
                 --set template.spec.overlays.cache.enabled=true
                 --set template.spec.overlays.cache.size="$cache_size"
               )
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
             if [ -n "$cache_size" ]; then
               echo "Cache enabled with size: $cache_size"
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
            
            echo "Removing runner scale set: $installation_name (instance $instance_id for $repo)"
            
            if ! check_cluster_exists; then
              echo "Cluster $CLUSTER_NAME does not exist"
              return 0
            fi
            
            kubectl config use-context "kind-$CLUSTER_NAME"
            
            helm uninstall "$installation_name" -n "$RUNNERS_NAMESPACE" || echo "Runner set not installed"
            
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
