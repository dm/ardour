# Ardour Build Makefile
# Simplified build commands for macOS ARM64

# Configuration variables
UV := uv
VENV_DIR := .venv
BOOST_INCLUDE := /opt/homebrew/opt/boost/include
LIBARCHIVE_PREFIX := /opt/homebrew/opt/libarchive
RAPTOR_PREFIX := /opt/homebrew/opt/raptor
FFTW_PREFIX := /opt/homebrew/opt/fftw
OPENSSL_PREFIX := /opt/homebrew/opt/openssl@3
JACK_PREFIX := /opt/homebrew/opt/jack
CAIRO_PREFIX := /opt/homebrew/opt/cairo
LIBSNDFILE_PREFIX := /opt/homebrew/opt/libsndfile
# Add all keg-only libraries to PKG_CONFIG_PATH so waf can discover them
PKG_CONFIG_PATH := $(LIBARCHIVE_PREFIX)/lib/pkgconfig:$(RAPTOR_PREFIX)/lib/pkgconfig:$(FFTW_PREFIX)/lib/pkgconfig:$(OPENSSL_PREFIX)/lib/pkgconfig:$(shell echo $$PKG_CONFIG_PATH)
# Use CPPFLAGS for preprocessor/include flags
# Add /opt/homebrew/include first to catch all Homebrew libraries
# Note: libarchive is keg-only, needs explicit path
# Note: raptor headers are in raptor2 subdirectory (special case)
CPPFLAGS := -I/opt/homebrew/include -I$(LIBARCHIVE_PREFIX)/include -I$(RAPTOR_PREFIX)/include/raptor2
LDFLAGS := -L/opt/homebrew/lib -L$(LIBARCHIVE_PREFIX)/lib
NUM_JOBS := $(shell sysctl -n hw.logicalcpu)
WAF_FLAGS := --no-phone-home
CONFIGURE_FLAGS := $(WAF_FLAGS) --boost-include=$(BOOST_INCLUDE)

# Export variables for subprocesses
export PKG_CONFIG_PATH
export CPPFLAGS
export LDFLAGS

# Activation command for virtual environment
ACTIVATE := . $(VENV_DIR)/bin/activate

WAF_CACHE := build/c4che/_cache.py
ARDOUR_MAJOR = $(shell sed -n 's/.*"\([0-9][0-9]*\)\..*/\1/p' libs/ardour/revision.cc 2>/dev/null | head -1)
APP_NAME = Ardour$(ARDOUR_MAJOR).app
APP_BUNDLE = build/$(APP_NAME)

.PHONY: help
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

.PHONY: deps
deps: ## Install all Homebrew dependencies
	@echo "Installing Homebrew dependencies..."
	brew install boost
	brew unlink glibmm || true
	brew install glibmm@2.66
	brew link glibmm@2.66
	brew install libarchive liblo taglib rubberband vamp-plugin-sdk fftw
	brew install gtk+ gtkmm cairomm@1.14 pangomm@2.46 atkmm
	brew install libusb jack aubio
	brew install lv2 lrdf libwebsockets cppunit
	brew install serd sord lilv suil
	@echo "✅ All dependencies installed"

.PHONY: venv
venv: ## Create Python virtual environment using uv
	@if [ -d "$(VENV_DIR)" ]; then \
		echo "⚠️  Virtual environment already exists at $(VENV_DIR)"; \
		echo "Use 'make venv-clean' to recreate it"; \
	else \
		echo "Creating Python virtual environment with uv..."; \
		$(UV) venv $(VENV_DIR); \
		echo "✅ Virtual environment created at $(VENV_DIR)"; \
		echo "To activate: source $(VENV_DIR)/bin/activate"; \
	fi

.PHONY: venv-clean
venv-clean: ## Recreate Python virtual environment (removes existing)
	@echo "Recreating Python virtual environment with uv..."
	$(UV) venv $(VENV_DIR) --clear
	@echo "✅ Virtual environment recreated at $(VENV_DIR)"
	@echo "To activate: source $(VENV_DIR)/bin/activate"

.PHONY: configure
configure: ## Configure the build (requires venv activation)
	@if [ ! -d "$(VENV_DIR)" ]; then \
		echo "❌ Virtual environment not found. Run 'make venv' first."; \
		exit 1; \
	fi
	@echo "Configuring Ardour build..."
	@bash -c "source $(VENV_DIR)/bin/activate && ./waf configure $(CONFIGURE_FLAGS)"

$(VENV_DIR):
	$(UV) venv $(VENV_DIR)

$(WAF_CACHE): | $(VENV_DIR)
	@$(MAKE) configure

.PHONY: build
build: $(WAF_CACHE) ## Build Ardour (configures first if needed)
	@echo "Building Ardour with $(NUM_JOBS) parallel jobs..."
	@bash -c "source $(VENV_DIR)/bin/activate && ./waf build -j$(NUM_JOBS)"

.PHONY: clean
clean: ## Clean build artifacts (keeps configuration)
	@echo "Cleaning build artifacts..."
	@if [ -f "$(WAF_CACHE)" ]; then \
		bash -c "source $(VENV_DIR)/bin/activate && ./waf clean"; \
	else \
		echo "Nothing to clean (not configured)."; \
	fi
	rm -rf $(APP_BUNDLE)

.PHONY: distclean
distclean: ## Remove all build files and configuration
	@echo "Removing all build files..."
	@bash -c "source $(VENV_DIR)/bin/activate && ./waf distclean"
	rm -rf build/

.PHONY: install
install: ## Install Ardour (requires sudo)
	@echo "Installing Ardour..."
	@bash -c "source $(VENV_DIR)/bin/activate && sudo -E ./waf install"

.PHONY: uninstall
uninstall: ## Uninstall Ardour
	@echo "Uninstalling Ardour..."
	@bash -c "source $(VENV_DIR)/bin/activate && sudo -E ./waf uninstall"

.PHONY: setup
setup: venv deps ## Set up environment (create venv and install dependencies)
	@echo "✅ Environment setup completed!"

.PHONY: full
full: setup configure build ## Complete build from scratch (setup, configure, build)
	@echo "✅ Full build completed successfully!"

.PHONY: rebuild
rebuild: clean configure build ## Clean and rebuild

.PHONY: status
status: ## Show build configuration status
	@if [ -f "build/config.log" ]; then \
		echo "Configuration exists. Last configured:"; \
		stat -f "%Sm" build/config.log; \
	else \
		echo "Not configured yet. Run 'make configure' first."; \
	fi

.PHONY: test
test: ## Run test suite
	@bash -c "source $(VENV_DIR)/bin/activate && ./waf test"

.PHONY: run
run: ## Run Ardour from the build directory
	@if [ ! -f build/gtk2_ardour/ardev_common_waf.sh ] || ! ls build/gtk2_ardour/ardour-* >/dev/null 2>&1; then \
		echo "❌ Ardour binary not found. Run 'make build' first."; \
		exit 1; \
	fi
	@echo "Starting Ardour..."
	@./gtk2_ardour/ardev

.PHONY: app
app: build ## Build a self-contained, ad-hoc signed .app bundle at build/ArdourN.app
	@echo "Packaging $(APP_NAME)..."
	rm -rf $(APP_BUNDLE) tools/osx_packaging/$(APP_NAME)
	cd tools/osx_packaging && ./osx_build --public --stack /opt/homebrew --no-nls --nodmg
	mv tools/osx_packaging/$(APP_NAME) $(APP_BUNDLE)
	@echo "Ad-hoc signing Mach-O files..."
	@find $(APP_BUNDLE)/Contents -type f -exec sh -c 'file -b "$$1" | grep -q Mach-O && codesign --force --sign - "$$1"' _ {} \; 2>&1 | grep -v "replacing existing signature" || true
	@find $(APP_BUNDLE)/Contents/MacOS -type f -exec codesign --force --sign - {} \; 2>&1 | grep -v "replacing existing signature" || true
	codesign --force --sign - $(APP_BUNDLE)
	codesign --verify $(APP_BUNDLE)/Contents/MacOS/$(basename $(APP_NAME))
	@echo "✅ Created $(APP_BUNDLE) (open with: open $(APP_BUNDLE))"

.PHONY: run-app
run-app: ## Launch the packaged .app bundle
	@if [ ! -d "$(APP_BUNDLE)" ]; then \
		echo "❌ $(APP_BUNDLE) not found. Run 'make app' first."; \
		exit 1; \
	fi
	open $(APP_BUNDLE)

.PHONY: check-deps
check-deps: ## Check if all required dependencies are installed
	@echo "Checking dependencies..."
	@command -v brew >/dev/null 2>&1 || { echo "❌ Homebrew not found"; exit 1; }
	@command -v pkg-config >/dev/null 2>&1 || { echo "❌ pkg-config not found"; exit 1; }
	@pkg-config --exists boost || { echo "❌ boost not found"; exit 1; }
	@pkg-config --exists glibmm-2.4 || { echo "❌ glibmm-2.4 not found"; exit 1; }
	@pkg-config --exists jack || { echo "❌ jack not found"; exit 1; }
	@pkg-config --exists lv2 || { echo "❌ lv2 not found"; exit 1; }
	@echo "✅ All key dependencies found"

# Quick development targets
.PHONY: c
c: configure ## Alias for configure

.PHONY: b
b: build ## Alias for build

.PHONY: r
r: run ## Alias for run

.PHONY: cb
cb: configure build ## Configure and build in one step

.PHONY: br
br: build run ## Build and run in one step

.DEFAULT_GOAL := help
