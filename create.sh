#!/bin/bash

# This script creates the basic directory structure for the Aura project.

# Create root directories for frontend and backend
mkdir -p aura_frontend
mkdir -p aura_backend

# Frontend subdirectories (example, can be adjusted by Vue/Vite setup)
mkdir -p aura_frontend/src
mkdir -p aura_frontend/src/assets
mkdir -p aura_frontend/src/components
mkdir -p aura_frontend/src/views
mkdir -p aura_frontend/public

# Backend subdirectories (example)
mkdir -p aura_backend/app
mkdir -p aura_backend/app/api
mkdir -p aura_backend/app/services
mkdir -p aura_backend/data # For storing audio, transcripts, PDFs
mkdir -p aura_backend/data/audio_files
mkdir -p aura_backend/data/transcripts
mkdir -p aura_backend/data/pdfs
mkdir -p aura_backend/models # For Whisper.cpp and LLM models

echo "Aura project structure created successfully:"
echo "  aura_frontend/"
echo "  aura_backend/"
echo ""
echo "Next steps:"
echo "1. Run this script in your desired project location."
echo "2. For aura_frontend: cd aura_frontend && npm init vue@latest (or yarn create vite)"
echo "3. For aura_backend: Set up your Python virtual environment and install FastAPI, etc."
