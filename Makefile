# Hetzner Kubernetes Cluster Management Platform
# Makefile for common operations

.PHONY: help init plan apply destroy setup deploy status clean

# Default target
help:
	@echo "Hetzner Kubernetes Cluster Management Platform"
	@echo "=============================================="
	@echo ""
	@echo "Available targets:"
	@echo "  init        - Initialize Terraform"
	@echo "  plan        - Plan Terraform changes"
	@echo "  apply       - Apply Terraform changes"
	@echo "  destroy     - Destroy infrastructure"
	@echo "  setup       - Setup Kubernetes cluster"
	@echo "  deploy      - Deploy all components"
	@echo "  status      - Show cluster status"
	@echo "  clean       - Clean up temporary files"
	@echo "  dev-tools   - Install development tools"
	@echo "  backup      - Backup cluster configuration"
	@echo "  restore     - Restore cluster configuration"
	@echo ""

# Terraform operations
init:
	@echo "🚀 Initializing Terraform..."
	cd terraform && terraform init

plan:
	@echo "📋 Planning Terraform changes..."
	cd terraform && terraform plan

apply:
	@echo "🏗️  Applying Terraform changes..."
	cd terraform && terraform apply -auto-approve

destroy:
	@echo "💥 Destroying infrastructure..."
	cd terraform && terraform destroy -auto-approve

# Ansible operations
setup:
	@echo "⚙️  Setting up Kubernetes cluster..."
	cd ansible && ansible-playbook -i inventory/hosts.yml playbooks/site.yml

# Full deployment
deploy: init apply setup
	@echo "✅ Deployment completed!"

# Status checks
status:
	@echo "📊 Cluster Status"
	@echo "================"
	@kubectl get nodes
	@echo ""
	@kubectl get pods --all-namespaces
	@echo ""
	@kubectl get services --all-namespaces

# Development tools
dev-tools:
	@echo "🛠️  Installing development tools..."
	./scripts/install-dev-tools.sh

# Backup operations
backup:
	@echo "💾 Backing up cluster configuration..."
	@mkdir -p backups/$(shell date +%Y%m%d)
	@kubectl get all --all-namespaces -o yaml > backups/$(shell date +%Y%m%d)/k8s-resources.yaml
	@kubectl get configmaps --all-namespaces -o yaml > backups/$(shell date +%Y%m%d)/configmaps.yaml
	@kubectl get secrets --all-namespaces -o yaml > backups/$(shell date +%Y%m%d)/secrets.yaml
	@echo "Backup completed in backups/$(shell date +%Y%m%d)/"

# Restore operations
restore:
	@echo "🔄 Restoring cluster configuration..."
	@if [ -z "$(BACKUP_DIR)" ]; then \
		echo "Usage: make restore BACKUP_DIR=backups/YYYYMMDD"; \
		exit 1; \
	fi
	@kubectl apply -f $(BACKUP_DIR)/k8s-resources.yaml
	@kubectl apply -f $(BACKUP_DIR)/configmaps.yaml
	@kubectl apply -f $(BACKUP_DIR)/secrets.yaml
	@echo "Restore completed from $(BACKUP_DIR)"

# Cleanup
clean:
	@echo "🧹 Cleaning up temporary files..."
	@rm -rf terraform/.terraform
	@rm -rf terraform/terraform.tfstate*
	@rm -rf ansible/.ansible
	@rm -rf *.retry
	@rm -rf tmp/
	@rm -rf logs/
	@echo "Cleanup completed!"

# Port forwarding shortcuts
port-forward-grafana:
	@echo "📊 Port forwarding Grafana..."
	@kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

port-forward-prometheus:
	@echo "📈 Port forwarding Prometheus..."
	@kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090

port-forward-rancher:
	@echo "🐄 Port forwarding Rancher..."
	@kubectl port-forward -n cattle-system svc/rancher 8080:80

# Monitoring shortcuts
monitor-nodes:
	@echo "🖥️  Monitoring nodes..."
	@kubectl top nodes

monitor-pods:
	@echo "📦 Monitoring pods..."
	@kubectl top pods --all-namespaces

# User management shortcuts
create-user:
	@echo "👤 Creating user..."
	@if [ -z "$(USERNAME)" ] || [ -z "$(NAMESPACE)" ]; then \
		echo "Usage: make create-user USERNAME=username NAMESPACE=namespace"; \
		exit 1; \
	fi
	@kubectl create namespace $(NAMESPACE)
	@kubectl create serviceaccount $(USERNAME) -n $(NAMESPACE)
	@kubectl create rolebinding $(USERNAME)-binding --role=namespace-user --serviceaccount=$(NAMESPACE):$(USERNAME) -n $(NAMESPACE)
	@echo "User $(USERNAME) created in namespace $(NAMESPACE)"

# Resource management shortcuts
set-quota:
	@echo "📊 Setting resource quota..."
	@if [ -z "$(NAMESPACE)" ]; then \
		echo "Usage: make set-quota NAMESPACE=namespace"; \
		exit 1; \
	fi
	@kubectl apply -f - <<EOF
	apiVersion: v1
	kind: ResourceQuota
	metadata:
	  name: $(NAMESPACE)-quota
	  namespace: $(NAMESPACE)
	spec:
	  hard:
	    requests.cpu: "2"
	    requests.memory: 4Gi
	    limits.cpu: "4"
	    limits.memory: 8Gi
	    persistentvolumeclaims: "10"
	    pods: "20"
	EOF
	@echo "Resource quota set for namespace $(NAMESPACE)"

# Security operations
security-scan:
	@echo "🔒 Running security scan..."
	@kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}' | sort | uniq

# Documentation
docs:
	@echo "📚 Opening documentation..."
	@echo "Available documentation:"
	@echo "  - README.md: Project overview"
	@echo "  - docs/SETUP.md: Setup guide"
	@echo "  - docs/ARCHITECTURE.md: Architecture overview"
	@echo "  - docs/USER_GUIDE.md: User guide"

# Quick start
quick-start:
	@echo "🚀 Quick Start Guide"
	@echo "==================="
	@echo "1. Copy terraform.tfvars.example to terraform.tfvars"
	@echo "2. Edit terraform.tfvars with your configuration"
	@echo "3. Run: make deploy"
	@echo "4. Access Rancher at: https://LOAD_BALANCER_IP/rancher"
	@echo "5. Access Grafana at: https://LOAD_BALANCER_IP/grafana"
	@echo "6. Access GUI at: https://LOAD_BALANCER_IP/gui"
	@echo ""
	@echo "For detailed instructions, see docs/SETUP.md"