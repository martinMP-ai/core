#!/bin/bash
# Home Assistant Development Environment Startup Script

echo "🏠 Starting Home Assistant Development Environment..."

# Navigate to the core directory
cd /Users/martinpark/core || {
    echo "❌ Error: Could not find the core directory"
    exit 1
}

# Activate the virtual environment
echo "🔄 Activating virtual environment..."
source venv/bin/activate || {
    echo "❌ Error: Could not activate virtual environment"
    echo "Run 'script/setup' first to set up the development environment"
    exit 1
}

# Check if Home Assistant is installed in development mode
if ! python -c "import homeassistant" 2>/dev/null; then
    echo "⚠️  Home Assistant not found in development mode. Running setup..."
    script/setup
fi

echo "✅ Development environment ready!"
echo ""
echo "🚀 Available commands:"
echo "  hass -c config                    # Start Home Assistant"
echo "  pytest tests/                     # Run tests"
echo "  python -m script.hassfest         # Run hassfest validation"
echo "  pre-commit run --all-files        # Run linting"
echo "  hass --script check_config -c config  # Check configuration"
echo ""
echo "📁 Configuration directory: $(pwd)/config"
echo "🌐 Home Assistant URL: http://localhost:8123"
echo ""

# Keep the shell active in the venv
exec "$SHELL"
