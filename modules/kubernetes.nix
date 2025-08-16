{ config, lib, pkgs, hasNvidia ? false, ... }:
{
  environment.systemPackages = with pkgs; [
    docker
    runc
    k3s 
    kubernetes-helm
    multus-cni  # Make multus-cni available system-wide
    cni-plugins  # Include additional CNI plugins like vlan, macvlan, etc.
  ] ++ lib.optionals hasNvidia [
    nvidia-container-toolkit
    libnvidia-container
  ];

  services.k3s = {
    enable = true;
    role = "server";
    token = "532a3cf6ea";
    clusterInit = (config.networking.hostName == "gremlin-1");
    serverAddr = lib.mkIf (config.networking.hostName != "gremlin-1") "https://10.1.1.12:6443";
    extraFlags = toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
      "--tls-san 127.0.0.1"
      "--tls-san localhost"
      "--tls-san 10.1.1.12"
      "--tls-san 10.1.1.13" 
      "--tls-san 10.1.1.14"
      "--tls-san 10.43.0.1"
      "--tls-san kubernetes.default.svc.cluster.local"
      "--advertise-address 10.1.1.12"
      "--bind-address 0.0.0.0"
    ]; 
  };

  # Create a proper CNI directory with all needed binaries and configuration
  systemd.tmpfiles.rules = [
    "d /var/lib/rancher/k3s/data/cni 0755 root root -"
    "L+ /var/lib/rancher/k3s/data/cni/multus - - - - ${pkgs.multus-cni}/bin/multus"
    "L+ /var/lib/rancher/k3s/data/cni/multus-daemon - - - - ${pkgs.multus-cni}/bin/multus-daemon"
    "L+ /var/lib/rancher/k3s/data/cni/multus-shim - - - - ${pkgs.multus-cni}/bin/multus-shim"
    "L+ /var/lib/rancher/k3s/data/cni/thin_entrypoint - - - - ${pkgs.multus-cni}/bin/thin_entrypoint"
    "L+ /var/lib/rancher/k3s/data/cni/vlan - - - - ${pkgs.cni-plugins}/bin/vlan"
    "L+ /var/lib/rancher/k3s/data/cni/macvlan - - - - ${pkgs.cni-plugins}/bin/macvlan"
    "L+ /var/lib/rancher/k3s/data/cni/ipvlan - - - - ${pkgs.cni-plugins}/bin/ipvlan"
    
    # Create Multus CNI configuration directory
    "d /var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d 0755 root root -"
    
    # Create proper Multus CNI configuration with CORRECT kubeconfig path
    "f /var/lib/rancher/k3s/agent/etc/cni/net.d/00-multus.conflist 0644 root root - {\"cniVersion\":\"1.0.0\",\"name\":\"multus-cni-network\",\"plugins\":[{\"type\":\"multus\",\"capabilities\":{\"bandwidth\":true,\"portMappings\":true},\"kubeconfig\":\"/var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d/multus.kubeconfig\",\"server\":\"https://127.0.0.1:6443\",\"delegates\":[{\"cniVersion\":\"1.0.0\",\"name\":\"cbr0\",\"plugins\":[{\"delegate\":{\"forceAddress\":true,\"hairpinMode\":true,\"isDefaultGateway\":true},\"type\":\"flannel\"},{\"capabilities\":{\"portMappings\":true},\"type\":\"portmap\"},{\"capabilities\":{\"bandwidth\":true},\"type\":\"bandwidth\"}]}]}]}"
  ];

  # Create Multus kubeconfig service - minimal kubectl usage for ServiceAccount token
  systemd.services.multus-kubeconfig = {
    description = "Generate Multus kubeconfig with proper ServiceAccount token";
    wantedBy = [ "k3s.service" ];
    after = [ "k3s.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Wait for K3s to be ready
      while ! ${pkgs.k3s}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get nodes >/dev/null 2>&1; do
        echo "Waiting for K3s to be ready..."
        sleep 5
      done

      # Create minimal ServiceAccount for Multus (this is infrastructure, not application logic)
      ${pkgs.k3s}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml apply -f - <<YAML
apiVersion: v1
kind: ServiceAccount
metadata:
  name: multus
  namespace: kube-system
YAML

      # Create token secret for the ServiceAccount
      ${pkgs.k3s}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml apply -f - <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: multus-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: multus
type: kubernetes.io/service-account-token
YAML

      # Wait for token to be available
      while ! ${pkgs.k3s}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get secret multus-token -n kube-system >/dev/null 2>&1; do
        echo "Waiting for service account token..."
        sleep 2
      done

      TOKEN=$(${pkgs.k3s}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get secret multus-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)
      CA_DATA=$(${pkgs.k3s}/bin/kubectl --kubeconfig=/etc/rancher/k3s/k3s.yaml get secret multus-token -n kube-system -o jsonpath='{.data.ca\.crt}')

      # Create the multus kubeconfig directory
      mkdir -p /var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d

      # Generate proper kubeconfig with ServiceAccount token
      cat > /var/lib/rancher/k3s/agent/etc/cni/net.d/multus.d/multus.kubeconfig <<KUBECONFIG
# Kubeconfig file for Multus CNI plugin.
apiVersion: v1
kind: Config
clusters:
- name: local
  cluster:
    server: https://127.0.0.1:6443
    certificate-authority-data: $CA_DATA
users:
- name: multus
  user:
    token: $TOKEN
contexts:
- name: multus-context
  context:
    cluster: local
    user: multus
current-context: multus-context
KUBECONFIG

      echo "Multus kubeconfig generated successfully with ServiceAccount token"
    '';
  };

  virtualisation = {
    docker = {
      enable = true;
      package = pkgs.docker;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
    containerd = {
      enable = true;
      settings = {
        plugins."io.containerd.grpc.v1.cri" = {
          cni = {
            bin_dir = "/var/lib/rancher/k3s/data/cni";
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
          };
          containerd = {
            default_runtime_name = "runc";
            runtimes.runc = {
              runtime_type = "io.containerd.runc.v2";
            };
          };
        };
      };
    };
  };

  security.pam.loginLimits = [
    {domain = "*"; item = "memlock"; type = "-"; value = "unlimited";}
  ];
}
