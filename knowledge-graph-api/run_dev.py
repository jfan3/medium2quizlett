#!/usr/bin/env python3
"""
Development server runner - starts the API without requiring full Supabase setup
"""

import uvicorn
import os
import sys
import logging

# Add the current directory to Python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Configure logging to reduce noise
logging.getLogger("uvicorn.access").setLevel(logging.WARNING)

if __name__ == "__main__":
    # Start the server
    uvicorn.run(
        "app.main:app",
        host="127.0.0.1",
        port=8001,
        reload=True,
        reload_dirs=["."],
        log_level="info",
        access_log=False  # Disable access logs
    )