# Puma configuration for Fly.io deployment
# Optimized for low memory usage on shared-cpu-1x (256MB RAM)

# Use the PORT environment variable, default to 8080
port ENV.fetch("PORT", 8080)

# Single worker process (no forking) to save memory
workers 0

# Minimal threads for light MCP traffic
threads 2, 2

# Preload application for faster startup and lower memory footprint
preload_app!

# Bind to all interfaces
bind "tcp://0.0.0.0:#{ENV.fetch("PORT", 8080)}"

# Disable stats since we're running a single worker
activate_control_app false
