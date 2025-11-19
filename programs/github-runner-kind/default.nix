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
        description = "Maximum number of runners to scale to. Note: When instances > 1, this is automatically set to 1 per instance for cache isolation.";
      };
      
      type = mkOption {
        type = types.enum [ "dind" "cached-privileged-kubernetes" "kubernetes" ];
        default = "kubernetes";
        description = "Runner type (dind, cached-privileged-kubernetes, kubernetes)";
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
        description = "Number of runner scale set instances to create for this repository. When > 1, maxRunners is automatically set to 1 per instance for cache isolation.";
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
        description = "List of paths to cache with hostPath volumes shared between workers (only for cached-privileged-kubernetes type)";
        example = literalExpression ''
          [
            { path = "/nix/store"; name = "nix-store"; }
            { path = "/var/lib/docker"; name = "docker-daemon"; }
            { path = "/root/.cache/nix"; name = "nix-cache"; }
          ]
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
          maxRunners = 1;  # Force maxRunners = 1 for cache isolation when using instances
        }
      ) (builtins.genList (x: x + 1) repo.instances))
    else
      [ (repo // { instanceId = 1; }) ]
  ) processedRepos);

  # Template and script files installed in the Nix store
  templateDir = pkgs.runCommand "github-runner-kind-templates" {} ''
    mkdir -p $out
    
    # Install template files
    cp ${./templates/cached-privileged-values.yaml} $out/cached-privileged-values.yaml
    cp ${./templates/dind-sidecar-values.yaml} $out/dind-sidecar-values.yaml
    cp ${./templates/dind-pvc.yaml} $out/dind-pvc.yaml
  '';

  scriptDir = pkgs.runCommand "github-runner-kind-scripts" {} ''
    mkdir -p $out
    
    # Install script files
    cp ${./scripts/utils.sh} $out/utils.sh
    cp ${./scripts/template-utils.sh} $out/template-utils.sh
    cp ${./scripts/cluster-management.sh} $out/cluster-management.sh
    cp ${./scripts/runner-deployment.sh} $out/runner-deployment.sh
    
    # Make scripts executable
    chmod +x $out/*.sh
  '';

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
            type = "cached-privileged-kubernetes";
            cachePaths = [
              { path = "/nix/store"; name = "nix-store"; }
              { path = "/var/lib/docker"; name = "docker-daemon"; }
            ];
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
      # Validate cachePaths only used with cached-privileged-kubernetes type
      (let
        invalidCachePathRepos = filter (repo: 
          repo.cachePaths != [] && repo.type != "cached-privileged-kubernetes"
        ) cfg.repositories;
      in {
        assertion = invalidCachePathRepos == [];
        message = "cachePaths can only be used with type = \"cached-privileged-kubernetes\". Invalid repos: ${toString (map (r: r.name) invalidCachePathRepos)}";
      })
      # Validate instances and maxRunners not used together
      (let
        conflictingRepos = filter (repo:
          repo.instances > 1 && repo.maxRunners != 5  # 5 is the default value
        ) cfg.repositories;
      in {
        assertion = conflictingRepos == [];
        message = "Cannot specify both 'instances' and 'maxRunners'. When using instances > 1, maxRunners is automatically set to 1 per instance for cache isolation. Conflicting repos: ${toString (map (r: r.name) conflictingRepos)}";
      })
    ];

    home.packages = with pkgs; [
      kind
      kubectl
      kubernetes-helm
      docker
    ];

    home.file = {
      # Kind cluster configuration
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

      # Main management script
      ".local/bin/github-runner-kind-manage" = {
        source = pkgs.writeShellScript "github-runner-kind-manage" ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          # Configuration variables
          CLUSTER_NAME="${cfg.clusterName}"
          CONTROLLER_NAMESPACE="${cfg.controllerNamespace}"
          RUNNERS_NAMESPACE="${cfg.runnersNamespace}"
          CONFIG_DIR="${config.home.homeDirectory}/.config/github-runner-kind"
          TEMPLATE_DIR="${templateDir}"
          SCRIPT_DIR="${scriptDir}"
          
          # Repository and instance configuration arrays
          declare -A REPOS
          declare -A INSTALLATION_NAMES
          declare -A MIN_RUNNERS
          declare -A MAX_RUNNERS
          declare -A TYPES
          declare -A BUILD_CACHE_SIZES
          declare -A CACHE_PATHS
          declare -A INSTANCE_IDS
          declare -A DIND_SIDECARS
          declare -A DIND_IMAGES
          declare -A DIND_STORAGE_SIZES
          
          # Load repository configurations
          ${concatStringsSep "\n" (map (instance: 
            let
              instanceKey = "${instance.name}:${toString instance.instanceId}";
            in ''
            REPOS["${instanceKey}"]="${instance.name}"
            INSTALLATION_NAMES["${instanceKey}"]="${instance.installationName}"
            MIN_RUNNERS["${instanceKey}"]="${toString instance.minRunners}"
            MAX_RUNNERS["${instanceKey}"]="${toString instance.maxRunners}"
            TYPES["${instanceKey}"]="${instance.type}"
            BUILD_CACHE_SIZES["${instanceKey}"]="${if instance.buildCacheSize != null then instance.buildCacheSize else ""}"
            CACHE_PATHS["${instanceKey}"]='${builtins.toJSON instance.cachePaths}'
            INSTANCE_IDS["${instanceKey}"]="${toString instance.instanceId}"
            DIND_SIDECARS["${instanceKey}"]="${if instance.dinDSidecar then "true" else "false"}"
            DIND_IMAGES["${instanceKey}"]="${instance.dinDImage}"
            DIND_STORAGE_SIZES["${instanceKey}"]="${if instance.dinDStorageSize != null then instance.dinDStorageSize else ""}"
            '') expandedInstances)}
          
          # Source utility functions
          source "$SCRIPT_DIR/utils.sh"
          source "$SCRIPT_DIR/cluster-management.sh"
          source "$SCRIPT_DIR/runner-deployment.sh"
          
          # Additional management functions
          
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
            
            echo "Note: Cache partitions persist at /tmp/github-runner-cache/$installation_name/ on kind host"
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