import re
from typing import Dict, List, Any
from dataclasses import dataclass

@dataclass
class TextSection:
    title: str
    content: str
    start_position: int
    end_position: int
    level: int  # Header level (1=main section, 2=subsection, etc.)

class TextProcessor:
    """Service for processing and analyzing plain text documents"""
    
    def __init__(self):
        # Common patterns for section detection
        self.section_patterns = [
            r'^#{1,6}\s+(.+)$',  # Markdown headers
            r'^(\d+\.?\s*.+)$',  # Numbered sections
            r'^([A-Z][^.!?]*[:])$',  # Title case followed by colon
            r'^([A-Z\s]+)$',  # ALL CAPS headers
        ]
    
    def analyze_text_structure(self, text: str) -> Dict[str, Any]:
        """Analyze the structure and content of plain text"""
        lines = text.split('\n')
        
        # Basic statistics
        word_count = len(text.split())
        char_count = len(text)
        line_count = len(lines)
        paragraph_count = len([line for line in lines if line.strip()])
        
        # Detect sections
        sections = self._detect_sections(text)
        
        # Estimate content type
        content_type = self._classify_text_type(text, sections)
        
        return {
            "word_count": word_count,
            "character_count": char_count,
            "line_count": line_count,
            "paragraph_count": paragraph_count,
            "sections": [s.__dict__ for s in sections],
            "content_type": content_type,
            "has_structure": len(sections) > 1,
            "average_words_per_section": word_count / max(len(sections), 1)
        }
    
    def _detect_sections(self, text: str) -> List[TextSection]:
        """Detect sections and headers in text"""
        lines = text.split('\n')
        sections = []
        current_position = 0
        
        for i, line in enumerate(lines):
            line_stripped = line.strip()
            if not line_stripped:
                current_position += len(line) + 1
                continue
            
            # Check if line matches section patterns
            section_level = self._get_section_level(line_stripped)
            if section_level > 0:
                sections.append(TextSection(
                    title=line_stripped,
                    content="",  # Will be filled later
                    start_position=current_position,
                    end_position=current_position + len(line),
                    level=section_level
                ))
            
            current_position += len(line) + 1
        
        # Fill content for each section
        self._fill_section_content(text, sections)
        
        # If no sections detected, treat entire text as one section
        if not sections:
            sections.append(TextSection(
                title="Main Content",
                content=text,
                start_position=0,
                end_position=len(text),
                level=1
            ))
        
        return sections
    
    def _get_section_level(self, line: str) -> int:
        """Determine if a line is a section header and its level"""
        # Markdown headers
        if line.startswith('#'):
            return line.count('#')
        
        # Numbered sections (1., 1.1., etc.)
        if re.match(r'^\d+(\.\d+)*\.?\s', line):
            dots = line.split()[0].count('.')
            return min(dots + 1, 6)
        
        # ALL CAPS (likely a header)
        if line.isupper() and len(line.split()) <= 10:
            return 2
        
        # Title case with colon
        if line.endswith(':') and line[0].isupper():
            return 3
        
        return 0
    
    def _fill_section_content(self, text: str, sections: List[TextSection]):
        """Fill the content for each detected section"""
        lines = text.split('\n')
        
        for i, section in enumerate(sections):
            start_line = self._position_to_line(section.start_position, text)
            end_line = self._position_to_line(
                sections[i + 1].start_position if i + 1 < len(sections) else len(text),
                text
            )
            
            # Extract content between this section and the next
            section_content = '\n'.join(lines[start_line + 1:end_line])
            section.content = section_content.strip()
    
    def _position_to_line(self, position: int, text: str) -> int:
        """Convert character position to line number"""
        return text[:position].count('\n')
    
    def _classify_text_type(self, text: str, sections: List[TextSection]) -> str:
        """Classify the type of text document"""
        text_lower = text.lower()
        word_count = len(text.split())
        
        # Academic paper indicators
        academic_keywords = ['abstract', 'introduction', 'methodology', 'results', 
                           'conclusion', 'references', 'bibliography']
        if any(keyword in text_lower for keyword in academic_keywords):
            return "academic_paper"
        
        # Textbook indicators
        textbook_keywords = ['chapter', 'exercise', 'problem', 'solution', 'homework']
        if any(keyword in text_lower for keyword in textbook_keywords) and word_count > 5000:
            return "textbook"
        
        # Technical documentation
        tech_keywords = ['function', 'class', 'method', 'parameter', 'return', 'example']
        if any(keyword in text_lower for keyword in tech_keywords):
            return "technical_documentation"
        
        # Short content
        if word_count < 1000:
            return "short_text"
        
        # Long structured content
        if len(sections) > 5 and word_count > 3000:
            return "structured_document"
        
        return "general_text"
    
    def extract_key_concepts(self, text: str) -> List[Dict[str, Any]]:
        """Extract potential key concepts from text"""
        # Simple concept extraction using patterns
        concepts = []
        
        # Find terms in quotes (often definitions)
        quoted_terms = re.findall(r'"([^"]+)"', text)
        for term in quoted_terms:
            if len(term.split()) <= 4:  # Short phrases only
                concepts.append({
                    "term": term,
                    "type": "quoted_term",
                    "confidence": 0.7
                })
        
        # Find capitalized terms (potential proper nouns/concepts)
        capitalized_terms = re.findall(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b', text)
        for term in capitalized_terms:
            if len(term.split()) <= 3 and len(term) > 3:
                concepts.append({
                    "term": term,
                    "type": "capitalized_term",
                    "confidence": 0.5
                })
        
        # Find terms followed by definition patterns
        definition_patterns = [
            r'([A-Za-z\s]+)\s+is\s+(?:a\s+|an\s+)?([^.!?]+)',
            r'([A-Za-z\s]+)\s+refers\s+to\s+([^.!?]+)',
            r'([A-Za-z\s]+):\s+([^.!?]+)'
        ]
        
        for pattern in definition_patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            for term, definition in matches:
                term = term.strip()
                if len(term.split()) <= 4:
                    concepts.append({
                        "term": term,
                        "definition": definition.strip(),
                        "type": "defined_term",
                        "confidence": 0.8
                    })
        
        # Remove duplicates and sort by confidence
        seen_terms = set()
        unique_concepts = []
        for concept in concepts:
            term_lower = concept["term"].lower()
            if term_lower not in seen_terms:
                seen_terms.add(term_lower)
                unique_concepts.append(concept)
        
        return sorted(unique_concepts, key=lambda x: x["confidence"], reverse=True)[:20]