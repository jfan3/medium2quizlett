import os
import uuid
import aiofiles
from typing import Dict, Any, Optional
from fastapi import UploadFile, HTTPException
from pathlib import Path
from app.core.config import settings
from app.services.pdf_processor import PDFProcessor
from app.services.text_processor import TextProcessor

class FileHandler:
    """Service for handling file uploads and processing"""
    
    def __init__(self):
        self.pdf_processor = PDFProcessor()
        self.text_processor = TextProcessor()
        self.upload_dir = Path(settings.upload_dir)
        self.upload_dir.mkdir(exist_ok=True)
    
    async def process_uploaded_file(self, file: UploadFile, user_id: str) -> Dict[str, Any]:
        """Process an uploaded file and extract content"""
        
        # Validate file
        self._validate_file(file)
        
        # Generate unique filename
        file_id = str(uuid.uuid4())
        file_extension = Path(file.filename).suffix.lower()
        safe_filename = f"{file_id}{file_extension}"
        file_path = self.upload_dir / safe_filename
        
        try:
            # Save file to disk
            file_content = await file.read()
            async with aiofiles.open(file_path, 'wb') as f:
                await f.write(file_content)
            
            # Process based on file type
            if file_extension == '.pdf':
                processing_result = await self._process_pdf(file_content, file.filename)
            elif file_extension in ['.txt', '.md']:
                text_content = file_content.decode('utf-8')
                processing_result = await self._process_text(text_content, file.filename)
            else:
                raise HTTPException(status_code=400, detail=f"Unsupported file type: {file_extension}")
            
            # Add file metadata
            processing_result.update({
                "file_id": file_id,
                "original_filename": file.filename,
                "file_path": str(file_path),
                "file_size": len(file_content),
                "content_type": file.content_type,
                "user_id": user_id
            })
            
            return processing_result
            
        except Exception as e:
            # Clean up file on error
            if file_path.exists():
                file_path.unlink()
            raise HTTPException(status_code=500, detail=f"File processing failed: {str(e)}")
    
    def _validate_file(self, file: UploadFile):
        """Validate uploaded file"""
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        file_extension = Path(file.filename).suffix.lower()
        if file_extension not in settings.allowed_file_types:
            raise HTTPException(
                status_code=400, 
                detail=f"File type {file_extension} not allowed. Allowed types: {settings.allowed_file_types}"
            )
        
        if file.size and file.size > settings.max_file_size:
            raise HTTPException(
                status_code=400, 
                detail=f"File too large. Maximum size: {settings.max_file_size} bytes"
            )
    
    async def _process_pdf(self, pdf_content: bytes, filename: str) -> Dict[str, Any]:
        """Process PDF file"""
        try:
            # Extract text and metadata
            text_data = self.pdf_processor.extract_text_and_metadata(pdf_content)
            
            # Analyze document structure
            structure = self.pdf_processor.analyze_document_structure(text_data)
            
            # Extract images and visual elements
            visual_elements = self.pdf_processor.detect_visual_elements(pdf_content)
            
            return {
                "document_type": "pdf",
                "text_content": text_data["text"],
                "metadata": {
                    **text_data["metadata"],
                    "total_words": text_data["total_words"],
                    "num_pages": text_data["metadata"]["num_pages"],
                    "structure": structure,
                    "visual_elements_count": len(visual_elements)
                },
                "pages": text_data["pages"],
                "visual_elements": visual_elements,
                "processing_status": "completed"
            }
            
        except Exception as e:
            return {
                "document_type": "pdf",
                "processing_status": "failed",
                "error": str(e)
            }
    
    async def _process_text(self, text_content: str, filename: str) -> Dict[str, Any]:
        """Process plain text file"""
        try:
            # Analyze text structure
            structure = self.text_processor.analyze_text_structure(text_content)
            
            # Extract key concepts
            concepts = self.text_processor.extract_key_concepts(text_content)
            
            return {
                "document_type": "text",
                "text_content": text_content,
                "metadata": {
                    "word_count": structure["word_count"],
                    "character_count": structure["character_count"],
                    "content_type": structure["content_type"],
                    "has_structure": structure["has_structure"],
                    "sections_count": len(structure["sections"])
                },
                "structure": structure,
                "extracted_concepts": concepts,
                "processing_status": "completed"
            }
            
        except Exception as e:
            return {
                "document_type": "text",
                "processing_status": "failed",
                "error": str(e)
            }
    
    def get_file_path(self, file_id: str, extension: str) -> Path:
        """Get file path by ID"""
        return self.upload_dir / f"{file_id}{extension}"
    
    def delete_file(self, file_path: str) -> bool:
        """Delete a file from storage"""
        try:
            path = Path(file_path)
            if path.exists():
                path.unlink()
                return True
            return False
        except Exception:
            return False