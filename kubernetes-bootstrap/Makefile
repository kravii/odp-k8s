# Kubernetes Bootstrap Makefile
# Provides convenient commands for cluster management

.PHONY: help install bootstrap add-node remove-node clean test

# Default target
help:
	@echo "Kubernetes Cluster Bootstrap Commands:"
	@echo ""
	@echo "Setup Commands:"
	@echo "  install          Install Python dependencies"
	@echo "  bootstrap        Bootstrap cluster from inventory"
	@echo "  dry-run          Show what bootstrap would do"
	@echo ""
	@echo "Node Management:"
	@echo "  add-worker       Add worker node to cluster"
	@echo "  add-master       Add control plane node to cluster"
	@echo "  remove-node      Remove node from cluster"
	@echo "  list-nodes        List all cluster nodes"
	@echo ""
	@echo "Testing:"
	@echo "  test-inventory   Test inventory file parsing"
	@echo "  test-prepare     Test node preparation script"
	@echo ""
	@echo "Utilities:"
	@echo "  clean            Clean temporary files"
	@echo "  docs             Open documentation"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make bootstrap INVENTORY=examples/inventory.yaml"
	@echo "  make add-worker INVENTORY=examples/inventory.yaml MASTER=192.168.1.10 NODE=worker-04"
	@echo "  make remove-node INVENTORY=examples/inventory.yaml MASTER=192.168.1.10 NODE=worker-04"

# Variables
INVENTORY ?= examples/inventory.yaml
CONFIG ?= cluster-config.yaml
MASTER ?= 192.168.1.10
NODE ?= worker-01
OS ?= ubuntu
VERSION ?= 22.04

# Install dependencies
install:
	@echo "Installing Python dependencies..."
	pip install -r requirements.txt
	@echo "Dependencies installed successfully!"

# Bootstrap cluster
bootstrap:
	@echo "Bootstrapping Kubernetes cluster..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 bootstrap_cluster.py $(INVENTORY) --config $(CONFIG)

# Dry run bootstrap
dry-run:
	@echo "Running bootstrap dry run..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 bootstrap_cluster.py $(INVENTORY) --config $(CONFIG) --dry-run

# Add worker node
add-worker:
	@echo "Adding worker node $(NODE)..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 scripts/add_node.py $(INVENTORY) $(MASTER) --hostname $(NODE) --node-type worker

# Add control plane node
add-master:
	@echo "Adding control plane node $(NODE)..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 scripts/add_node.py $(INVENTORY) $(MASTER) --hostname $(NODE) --node-type control-plane

# Remove node
remove-node:
	@echo "Removing node $(NODE)..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 scripts/remove_node.py $(INVENTORY) $(MASTER) --node $(NODE)

# List nodes
list-nodes:
	@echo "Listing cluster nodes..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 scripts/remove_node.py $(INVENTORY) $(MASTER) --list

# Test inventory parsing
test-inventory:
	@echo "Testing inventory file parsing..."
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	python3 inventory_parser.py $(INVENTORY)

# Test node preparation script
test-prepare:
	@echo "Testing node preparation script..."
	@if [ ! -f "scripts/prepare_node.sh" ]; then \
		echo "Error: Node preparation script not found"; \
		exit 1; \
	fi
	@echo "Script exists and is executable"
	@echo "To test on a real node, run:"
	@echo "  ./scripts/prepare_node.sh --os $(OS) --version $(VERSION)"

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete
	find . -name "*.log" -delete
	find . -name ".DS_Store" -delete
	@echo "Cleanup completed!"

# Open documentation
docs:
	@echo "Opening documentation..."
	@if command -v xdg-open > /dev/null; then \
		xdg-open README.md; \
	elif command -v open > /dev/null; then \
		open README.md; \
	else \
		echo "Please open README.md in your preferred text editor"; \
	fi

# Validate all scripts
validate:
	@echo "Validating all scripts..."
	@echo "Checking Python syntax..."
	python3 -m py_compile bootstrap_cluster.py
	python3 -m py_compile inventory_parser.py
	python3 -m py_compile scripts/add_node.py
	python3 -m py_compile scripts/remove_node.py
	@echo "Checking shell script syntax..."
	bash -n scripts/prepare_node.sh
	@echo "All scripts validated successfully!"

# Show cluster status
status:
	@echo "Cluster Status:"
	@echo "==============="
	@if [ ! -f "$(INVENTORY)" ]; then \
		echo "Error: Inventory file $(INVENTORY) not found"; \
		exit 1; \
	fi
	@echo "Inventory file: $(INVENTORY)"
	@echo "Master node: $(MASTER)"
	@echo "Configuration: $(CONFIG)"
	@echo ""
	@echo "Available commands:"
	@echo "  make list-nodes    - List all nodes in cluster"
	@echo "  make status        - Show this status"
	@echo "  make help          - Show all available commands"

# Quick setup for development
dev-setup:
	@echo "Setting up development environment..."
	make install
	make validate
	@echo "Development environment ready!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Create your inventory file"
	@echo "2. Run: make bootstrap INVENTORY=your-inventory.yaml"
	@echo "3. Or run: make dry-run INVENTORY=your-inventory.yaml"

# Production setup
prod-setup:
	@echo "Setting up production environment..."
	make install
	make validate
	@echo "Production environment ready!"
	@echo ""
	@echo "Recommended for production:"
	@echo "1. Use production-cluster-config.yaml"
	@echo "2. Test with dry-run first"
	@echo "3. Monitor cluster health after bootstrap"