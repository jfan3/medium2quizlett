# Knowledge Graph API

Intelligent document processing system that creates knowledge graphs from PDFs and generates study materials.

## Features

- **Smart Document Analysis**: Automatically classifies documents (textbook, paper, short text)
- **Intelligent Processing**: 
  - Textbooks: Chapter-based processing
  - Papers: Concept expansion and visual extraction
  - Short text: Study-worthy content identification
- **Knowledge Graph Generation**: Creates interconnected concept networks
- **Study Materials**: Generates contextual flashcards and study aids

## Setup

1. Create virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Configure environment:
```bash
cp .env.example .env
# Edit .env with your API keys
```

4. Run the API:
```bash
uvicorn app.main:app --reload
```

## API Documentation

Access the interactive API docs at: `http://localhost:8000/docs`

## Architecture

- **FastAPI**: Web framework
- **Supabase**: Database and storage
- **Claude**: AI processing
- **Knowledge Graph**: SQL-based graph storage