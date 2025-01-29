#!/bin/bash

echo "Setting up Apex ApexDocGenServer..."

# Ensure Node.js is installed
if ! command -v node &> /dev/null
then
    echo "Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Install dependencies from package.json
echo "Installing dependencies..."
npm install

# Start the documentation generator in the background
echo "Starting documentation generator..."
nohup node server.js > server.log 2>&1 &

# Wait for the server to start (adjust sleep time if necessary)
sleep 3

# Open the generated documentation in the default web browser
echo "Opening documentation..."
if [[ "$OSTYPE" == "darwin"* ]]; then
    open "http://localhost:3500"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    xdg-open "http://localhost:3500"
else
    echo "Unsupported OS. Please open http://localhost:3500 manually."
fi

echo "Setup complete. Documentation should be open in your default browser."

# Prevent script from closing immediately (optional)
read -p "Press Enter to exit..."
