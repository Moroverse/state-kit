# Makefile for project setup and generation
APP_NAME ?= StateKitDemo

# Default target
.PHONY: all
all: upgrade install tuist

# Upgrade mise
.PHONY: upgrade
upgrade:
	@echo "Upgrading mise..."
	@mise upgrade

# Install dependencies with mise
.PHONY: install
install:
	@echo "Installing dependencies with mise..."
	@mise install

# Install Tuist
.PHONY: tuist-install
tuist-install:
	@echo "Installing Tuist..."
	@tuist install

# Install Tuist
.PHONY: doc
doc:
	@echo "Generate documentation..."
	@sh ./scripts/package_docc.sh

# Generate project with Tuist
.PHONY: generate
generate:
	@echo "Generating project with Tuist..."
	@tuist generate -p $(APP_NAME)

# Combined target for Tuist operations
.PHONY: tuist
tuist: tuist-install generate

# Clean target
.PHONY: clean
clean:
	@echo "Cleaning up..."
	@echo "Running tuist clean..."
	@tuist clean
	@echo "Running git clean..."
	@git clean -x -f -d

# Help target
.PHONY: help
help:
	@echo "Available targets:"
	@echo "  all                       - Run upgrade, install, and generate"
	@echo "  upgrade                   - Upgrade mise"
	@echo "  install                   - Install dependencies with mise"
	@echo "  tuist-install             - Install Tuist"
	@echo "  generate APP_NAME=<path>      - Generate project with Tuist"
	@echo "  tuist                     - Run both tuist-install and generate"
	@echo "  clean                     - Run tuist clean and git clean"
	@echo "  doc                       - Generate documentation"
	@echo "  help                      - Show this help message"
