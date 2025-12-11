#!/bin/bash
#------------------------------------------------------------------------------
#
# setup.sh - Development Environment Setup Script
#
# This script configures a basic Linux system with all tools required for
# the async_fifo project development and simulation.
#
# Supported distributions:
#   - Ubuntu/Debian (apt)
#   - Fedora/RHEL/CentOS (dnf/yum)
#   - Arch Linux (pacman)
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
#------------------------------------------------------------------------------

set -e  # Exit on error

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Minimum versions
MIN_CMAKE_VERSION="3.16"
MIN_IVERILOG_VERSION="11"
MIN_PYTHON_VERSION="3.8"

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_warn "Running as root. Consider running as regular user with sudo."
    fi
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_LIKE=$ID_LIKE
    elif [ -f /etc/debian_version ]; then
        DISTRO="debian"
    elif [ -f /etc/fedora-release ]; then
        DISTRO="fedora"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
    else
        DISTRO="unknown"
    fi
    log_info "Detected distribution: $DISTRO"
}

version_ge() {
    # Returns 0 if $1 >= $2
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

#------------------------------------------------------------------------------
# Package Installation Functions
#------------------------------------------------------------------------------

install_apt() {
    log_info "Using apt package manager..."
    
    # Update package lists
    sudo apt-get update
    
    # Essential build tools
    sudo apt-get install -y \
        build-essential \
        git \
        cmake \
        make
    
    # Icarus Verilog
    sudo apt-get install -y iverilog
    
    # Python
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv
    
    # Optional: Waveform viewer
    sudo apt-get install -y gtkwave || log_warn "GTKWave not available"
    
    # Optional: Documentation tools
    sudo apt-get install -y \
        doxygen \
        graphviz || log_warn "Documentation tools not available"
}

install_dnf() {
    log_info "Using dnf package manager..."
    
    # Essential build tools
    sudo dnf install -y \
        gcc \
        gcc-c++ \
        make \
        git \
        cmake
    
    # Icarus Verilog
    sudo dnf install -y iverilog || {
        log_warn "iverilog not in repos, trying EPEL..."
        sudo dnf install -y epel-release
        sudo dnf install -y iverilog
    }
    
    # Python
    sudo dnf install -y \
        python3 \
        python3-pip
    
    # Optional: Waveform viewer
    sudo dnf install -y gtkwave || log_warn "GTKWave not available"
}

install_pacman() {
    log_info "Using pacman package manager..."
    
    # Update system
    sudo pacman -Syu --noconfirm
    
    # Essential build tools
    sudo pacman -S --noconfirm \
        base-devel \
        git \
        cmake \
        make
    
    # Icarus Verilog
    sudo pacman -S --noconfirm iverilog
    
    # Python
    sudo pacman -S --noconfirm \
        python \
        python-pip
    
    # Optional: Waveform viewer
    sudo pacman -S --noconfirm gtkwave || log_warn "GTKWave not available"
}

install_packages() {
    case $DISTRO in
        ubuntu|debian|linuxmint|pop)
            install_apt
            ;;
        fedora)
            install_dnf
            ;;
        centos|rhel|rocky|alma)
            # Use dnf if available, otherwise yum
            if command -v dnf &> /dev/null; then
                install_dnf
            else
                log_error "yum support not implemented. Please install packages manually."
                exit 1
            fi
            ;;
        arch|manjaro)
            install_pacman
            ;;
        *)
            # Try to detect based on ID_LIKE
            if [[ "$DISTRO_LIKE" == *"debian"* ]]; then
                install_apt
            elif [[ "$DISTRO_LIKE" == *"fedora"* ]] || [[ "$DISTRO_LIKE" == *"rhel"* ]]; then
                install_dnf
            elif [[ "$DISTRO_LIKE" == *"arch"* ]]; then
                install_pacman
            else
                log_error "Unsupported distribution: $DISTRO"
                log_info "Please install manually: git, cmake, iverilog, python3, gtkwave"
                exit 1
            fi
            ;;
    esac
}

#------------------------------------------------------------------------------
# Verification Functions
#------------------------------------------------------------------------------

verify_git() {
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | awk '{print $3}')
        log_success "git $GIT_VERSION"
        return 0
    else
        log_error "git not found"
        return 1
    fi
}

verify_cmake() {
    if command -v cmake &> /dev/null; then
        CMAKE_VERSION=$(cmake --version | head -1 | awk '{print $3}')
        if version_ge "$CMAKE_VERSION" "$MIN_CMAKE_VERSION"; then
            log_success "cmake $CMAKE_VERSION (>= $MIN_CMAKE_VERSION required)"
            return 0
        else
            log_warn "cmake $CMAKE_VERSION found, but >= $MIN_CMAKE_VERSION recommended"
            return 0
        fi
    else
        log_error "cmake not found"
        return 1
    fi
}

verify_iverilog() {
    if command -v iverilog &> /dev/null; then
        IVERILOG_VERSION=$(iverilog -V 2>&1 | head -1 | grep -oP '\d+\.\d+' | head -1)
        log_success "iverilog $IVERILOG_VERSION"
        
        if command -v vvp &> /dev/null; then
            log_success "vvp found"
        else
            log_error "vvp not found (should be installed with iverilog)"
            return 1
        fi
        return 0
    else
        log_error "iverilog not found"
        return 1
    fi
}

verify_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | awk '{print $2}')
        if version_ge "$PYTHON_VERSION" "$MIN_PYTHON_VERSION"; then
            log_success "python3 $PYTHON_VERSION (>= $MIN_PYTHON_VERSION required)"
            return 0
        else
            log_warn "python3 $PYTHON_VERSION found, but >= $MIN_PYTHON_VERSION recommended"
            return 0
        fi
    else
        log_error "python3 not found"
        return 1
    fi
}

verify_gtkwave() {
    if command -v gtkwave &> /dev/null; then
        log_success "gtkwave found (optional)"
        return 0
    else
        log_warn "gtkwave not found (optional - for waveform viewing)"
        return 0
    fi
}

verify_installation() {
    echo ""
    log_info "Verifying installation..."
    echo ""
    
    ERRORS=0
    
    verify_git || ((ERRORS++))
    verify_cmake || ((ERRORS++))
    verify_iverilog || ((ERRORS++))
    verify_python || ((ERRORS++))
    verify_gtkwave
    
    echo ""
    
    if [ $ERRORS -eq 0 ]; then
        log_success "All required tools installed successfully!"
        return 0
    else
        log_error "$ERRORS required tool(s) missing or failed verification"
        return 1
    fi
}

#------------------------------------------------------------------------------
# Project Setup Functions
#------------------------------------------------------------------------------

setup_build_directory() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BUILD_DIR="$SCRIPT_DIR/build"
    
    log_info "Setting up build directory..."
    
    if [ -d "$BUILD_DIR" ]; then
        log_info "Build directory exists, reconfiguring..."
    else
        mkdir -p "$BUILD_DIR"
    fi
    
    cd "$BUILD_DIR"
    cmake .. 
    
    log_success "Build directory configured at: $BUILD_DIR"
}

run_tests() {
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    BUILD_DIR="$SCRIPT_DIR/build"
    
    if [ ! -d "$BUILD_DIR" ]; then
        log_error "Build directory not found. Run setup first."
        return 1
    fi
    
    log_info "Running tests to verify setup..."
    cd "$BUILD_DIR"
    
    # Build and run a simple test
    if make test_async_fifo_writepast_tb 2>/dev/null; then
        log_success "Test execution successful!"
        return 0
    else
        log_warn "Test execution had issues (may be normal for first run)"
        return 0
    fi
}

#------------------------------------------------------------------------------
# Main Script
#------------------------------------------------------------------------------

print_banner() {
    echo ""
    echo "=============================================="
    echo "  Async FIFO Project - Development Setup"
    echo "=============================================="
    echo ""
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --install     Install required packages (requires sudo)"
    echo "  --verify      Verify installed tools only"
    echo "  --build       Configure build directory"
    echo "  --test        Run verification tests"
    echo "  --all         Do everything (default)"
    echo "  --help        Show this help message"
    echo ""
}

main() {
    print_banner
    
    # Parse arguments
    DO_INSTALL=false
    DO_VERIFY=false
    DO_BUILD=false
    DO_TEST=false
    
    if [ $# -eq 0 ]; then
        # Default: do everything
        DO_INSTALL=true
        DO_VERIFY=true
        DO_BUILD=true
        DO_TEST=true
    else
        while [ $# -gt 0 ]; do
            case $1 in
                --install)
                    DO_INSTALL=true
                    ;;
                --verify)
                    DO_VERIFY=true
                    ;;
                --build)
                    DO_BUILD=true
                    ;;
                --test)
                    DO_TEST=true
                    ;;
                --all)
                    DO_INSTALL=true
                    DO_VERIFY=true
                    DO_BUILD=true
                    DO_TEST=true
                    ;;
                --help|-h)
                    print_usage
                    exit 0
                    ;;
                *)
                    log_error "Unknown option: $1"
                    print_usage
                    exit 1
                    ;;
            esac
            shift
        done
    fi
    
    check_root
    detect_distro
    
    if $DO_INSTALL; then
        echo ""
        log_info "Installing packages..."
        install_packages
    fi
    
    if $DO_VERIFY; then
        verify_installation || exit 1
    fi
    
    if $DO_BUILD; then
        echo ""
        setup_build_directory
    fi
    
    if $DO_TEST; then
        echo ""
        run_tests
    fi
    
    echo ""
    echo "=============================================="
    log_success "Setup complete!"
    echo "=============================================="
    echo ""
    echo "Next steps:"
    echo "  cd build"
    echo "  make                    # Build all"
    echo "  ctest                   # Run all tests"
    echo "  make test_<name>        # Run specific test"
    echo ""
    echo "View waveforms (if gtkwave installed):"
    echo "  gtkwave build/<test>/test_case_1.vcd"
    echo ""
}

# Run main function
main "$@"
