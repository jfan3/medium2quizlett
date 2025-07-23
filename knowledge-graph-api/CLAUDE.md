# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Common Commands

### Development Server
```bash
# Start development server (recommended)
python run_dev.py

# Alternative: direct uvicorn command
uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

### Testing
```bash
# Run PDF processing tests (limited test coverage exists)
PYTHONPATH=. python test_document_classification.py

# Run specific PDF extraction tests
PYTHONPATH=. python test_caption_extraction.py
PYTHONPATH=. python test_real_pdfs.py
```

### Dependencies
```bash
# Install dependencies
pip install -r requirements.txt

# Virtual environment setup
python -m venv venv
source venv/bin/activate  # Linux/Mac
```

## Architecture Overview

### Core Application Structure
The application is a **FastAPI-based intelligent document processing system** that creates knowledge graphs from documents and generates study materials.

**Main Components:**
- `app/main.py` - FastAPI application entry point with CORS and static file serving
- `run_dev.py` - Development server that runs on localhost:8001 with hot reload

### API Architecture
**Base Path:** `/api/v1/`

**Key Router Groups:**
- `/documents/` - Document upload, classification, and processing pipeline
- `/knowledge-graph/` - Concept extraction and graph operations
- `/study/` - Study card generation and progress tracking

### Document Processing Pipeline

**Multi-Stage AI Processing:**
1. **Classification** (`document_classifier.py`) - Rules-based classification into textbook/paper/short_text
2. **Content Extraction** (`pdf_processor.py`) - Advanced PDF processing with figure extraction
3. **AI Analysis** (`claude_agent.py`) - Specialized Claude agents per document type:
   - Textbook Agent: Chapter-by-chapter processing
   - Paper Agent: Academic analysis with concept expansion  
   - Short Text Agent: Direct concept extraction

**PDF Processing Capabilities:**
- Text and metadata extraction using PyPDF2
- Advanced figure extraction using PyMuPDF with caption-based spatial reasoning
- Support for embedded images and vector graphics
- Multi-line caption detection and bounding box expansion

### Database Architecture
**Backend:** Supabase (PostgreSQL)

**Core Schema:**
- `documents` + `document_content` - Document storage and processing status
- `concepts` + `concept_relationships` - Knowledge graph with importance/difficulty scoring
- `visual_elements` - Extracted images, charts, diagrams
- `study_cards` + `user_progress` + `study_sessions` - Learning system with mastery tracking
- `knowledge_paths` - Computed learning sequences between concepts

**Features:** Row Level Security, full-text search indexes, advanced SQL functions for graph operations

### Service Layer Architecture

**Key Services:**
- `database_service.py` - Supabase integration with mock service for development
- `file_handler.py` - File upload and validation (50MB limit, PDF/TXT/DOCX support)
- `study_card_generator.py` - Contextual study material generation
- `web_search.py` - Supplementary content discovery

### Configuration System
**Environment:** `.env` file with Pydantic settings (`app/core/config.py`)

**Required Keys:**
- `SUPABASE_URL`, `SUPABASE_KEY`, `SUPABASE_SERVICE_KEY`
- `ANTHROPIC_API_KEY`

### Development Patterns

**Service Architecture:** Clear separation with dependency injection for database services

**AI Integration:** Claude API integration with specialized document processors and intelligent concept relationship mapping

**Async Processing:** FastAPI with background tasks for heavy document analysis

**Error Handling:** Comprehensive logging throughout pipeline with detailed debugging

## Important Implementation Details

### PDF Figure Extraction
The system includes sophisticated figure extraction using **caption-based spatial reasoning**:
- Searches for actual figure captions (not in-text citations)
- Uses multi-line caption detection with keyword validation
- Applies asymmetric padding (generous right padding for complete caption capture)
- Renders high-resolution images (2x scaling) with PyMuPDF

### Document Classification Logic
Uses rule-based heuristics to classify documents:
- Word count thresholds and structural indicators
- Chapter/section detection for textbooks
- Abstract/bibliography detection for papers
- Content density analysis for short texts

### Knowledge Graph Generation
SQL-based graph storage with:
- Concept importance and difficulty scoring
- Relationship strength modeling
- Prerequisite and learning path computation
- Full-text search integration

## Testing Notes
- **Limited test coverage** - primarily PDF processing tests
- Most testing done through debug scripts rather than formal test suite
- Use `PYTHONPATH=.` prefix when running test scripts to ensure proper imports