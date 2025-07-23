import re
from typing import Dict, Any, List, Tuple
from dataclasses import dataclass
from app.models.document import DocumentType

@dataclass
class ClassificationFeatures:
    word_count: int
    page_count: int
    has_toc: bool
    has_bibliography: bool
    has_chapters: bool
    has_abstract: bool
    section_count: int
    academic_keywords: int
    textbook_keywords: int
    technical_keywords: int
    blog_tutorial_keywords: int
    average_sentence_length: float
    citation_count: int
    figure_table_count: int

class DocumentClassifier:
    """Intelligent document type classifier"""
    
    def __init__(self):
        # Define keyword sets for different document types
        self.academic_keywords = {
            'abstract', 'introduction', 'methodology', 'method', 'results', 
            'discussion', 'conclusion', 'literature review', 'hypothesis',
            'experiment', 'analysis', 'findings', 'research', 'study',
            'investigation', 'survey', 'data', 'statistical', 'empirical'
        }
        
        self.textbook_keywords = {
            'chapter', 'lesson', 'unit', 'exercise', 'problem', 'solution',
            'homework', 'assignment', 'quiz', 'exam', 'review questions',
            'learning objectives', 'summary', 'key terms', 'glossary',
            'practice', 'examples', 'case study', 'textbook', 'coursework'
        }
        
        self.blog_tutorial_keywords = {
            'tutorial', 'guide', 'walkthrough', 'step-by-step', 'how to',
            'getting started', 'beginner', 'basics', 'introduction to',
            'building', 'creating', 'setup', 'install', 'configure',
            'blog', 'post', 'article', 'published'
        }
        
        self.technical_keywords = {
            'function', 'class', 'method', 'parameter', 'return', 'variable',
            'algorithm', 'implementation', 'code', 'syntax', 'library',
            'framework', 'api', 'documentation', 'tutorial', 'guide'
        }
    
    def classify_document(self, processing_result: Dict[str, Any]) -> Tuple[DocumentType, float, Dict[str, Any]]:
        """
        Classify document type based on extracted content and metadata
        Returns: (document_type, confidence_score, classification_details)
        """
        
        # Extract features
        features = self._extract_features(processing_result)
        
        # Calculate scores for each document type
        textbook_score = self._calculate_textbook_score(features, processing_result)
        paper_score = self._calculate_paper_score(features, processing_result)
        tech_score = self._calculate_technical_score(features)
        short_text_score = self._calculate_short_text_score(features)
        
        # Determine the best classification
        scores = {
            DocumentType.TEXTBOOK: textbook_score,
            DocumentType.PAPER: paper_score,
            DocumentType.SHORT_TEXT: short_text_score,
            DocumentType.UNKNOWN: tech_score  # Technical docs, blogs, tutorials
        }
        
        best_type = max(scores, key=scores.get)
        confidence = scores[best_type]
        
        # If confidence is too low, mark as unknown
        if confidence < 0.3:
            best_type = DocumentType.UNKNOWN
            confidence = 0.5
        
        classification_details = {
            "features": features.__dict__,
            "scores": {str(k): v for k, v in scores.items()},
            "reasoning": self._get_classification_reasoning(features, best_type)
        }
        
        return best_type, confidence, classification_details
    
    def _extract_features(self, processing_result: Dict[str, Any]) -> ClassificationFeatures:
        """Extract classification features from processing result"""
        
        text_content = processing_result.get("text_content", "")
        metadata = processing_result.get("metadata", {})
        
        # Basic metrics
        word_count = len(text_content.split()) if text_content else 0
        page_count = metadata.get("num_pages", 1)
        
        # Structure indicators
        has_toc = self._detect_table_of_contents(text_content)
        has_bibliography = self._detect_bibliography(text_content)
        has_chapters = self._detect_chapters(text_content)
        has_abstract = self._detect_abstract(text_content)
        
        # Count sections
        section_count = self._count_sections(text_content)
        
        # Keyword analysis
        text_lower = text_content.lower()
        academic_keywords = sum(1 for keyword in self.academic_keywords if keyword in text_lower)
        textbook_keywords = sum(1 for keyword in self.textbook_keywords if keyword in text_lower)
        technical_keywords = sum(1 for keyword in self.technical_keywords if keyword in text_lower)
        blog_tutorial_keywords = sum(1 for keyword in self.blog_tutorial_keywords if keyword in text_lower)
        
        # Text analysis
        sentences = re.split(r'[.!?]+', text_content)
        avg_sentence_length = sum(len(s.split()) for s in sentences) / max(len(sentences), 1)
        
        # Citation analysis removed - citations can't be reliably detected from PDF files alone
        citation_count = 0
        
        # Visual elements
        visual_elements = processing_result.get("visual_elements", [])
        figure_table_count = len(visual_elements)
        
        return ClassificationFeatures(
            word_count=word_count,
            page_count=page_count,
            has_toc=has_toc,
            has_bibliography=has_bibliography,
            has_chapters=has_chapters,
            has_abstract=has_abstract,
            section_count=section_count,
            academic_keywords=academic_keywords,
            textbook_keywords=textbook_keywords,
            technical_keywords=technical_keywords,
            blog_tutorial_keywords=blog_tutorial_keywords,
            average_sentence_length=avg_sentence_length,
            citation_count=citation_count,
            figure_table_count=figure_table_count
        )
    
    def _calculate_textbook_score(self, features: ClassificationFeatures, processing_result: Dict[str, Any]) -> float:
        """Calculate probability that document is a textbook"""
        score = 0.0
        text_content = processing_result.get("text_content", "").lower()
        
        # Length indicators (textbooks are typically very long)
        if features.word_count > 100000:  # Very long - strong textbook indicator
            score += 0.5
        elif features.word_count > 50000:
            score += 0.4
        elif features.word_count > 20000:
            score += 0.3
        
        # Strong structure indicators (critical for textbooks)
        if features.has_chapters:
            score += 0.4  # Very strong indicator
        if features.has_toc and features.section_count > 50:
            score += 0.3  # Very structured academic content
        elif features.has_toc and features.section_count > 20:
            score += 0.2
        
        # Keyword indicators
        if features.textbook_keywords > 8:
            score += 0.3
        elif features.textbook_keywords > 5:
            score += 0.2
        elif features.textbook_keywords > 2:
            score += 0.1
        
        # Academic rigor indicators
        if features.has_bibliography and features.section_count > 100:
            score += 0.2
        
        # Now apply penalties for non-textbook content
        if features.blog_tutorial_keywords > 5:
            score -= 0.2  # Reduced penalty
        
        # Check for blog/web indicators
        web_indicators = ['published', 'blog', 'github']
        if any(indicator in text_content for indicator in web_indicators):
            score -= 0.15  # Reduced penalty
        
        return max(0.0, min(score, 1.0))
    
    def _calculate_paper_score(self, features: ClassificationFeatures, processing_result: Dict[str, Any]) -> float:
        """Calculate probability that document is an academic paper"""
        score = 0.0
        text_content = processing_result.get("text_content", "").lower()
        
        # Strong negative indicators for blogs/tutorials
        if features.blog_tutorial_keywords > 2:
            score -= 0.4  # Strong penalty for tutorial language
        
        # Check for blog/web indicators
        web_indicators = ['https://', 'http://', 'published', 'blog', 'github', 'website']
        if any(indicator in text_content for indicator in web_indicators):
            score -= 0.3  # Academic papers don't have web links
        
        # Length indicators (papers are typically medium length)
        if 3000 <= features.word_count <= 15000:
            score += 0.3
        elif 1500 <= features.word_count <= 25000:
            score += 0.15
        
        # Academic structure indicators (critical for papers)
        if features.has_abstract:
            score += 0.35  # Strong indicator
        if features.has_bibliography:
            score += 0.25
        # Citation scoring removed since citation detection was disabled
        # if features.citation_count > 10:
        #     score += 0.2
        # elif features.citation_count > 5:
        #     score += 0.1
        
        # Academic keyword indicators
        if features.academic_keywords > 8:
            score += 0.3
        elif features.academic_keywords > 4:
            score += 0.2
        elif features.academic_keywords > 2:
            score += 0.1
        
        # Research paper structure (focused sections)
        if 4 <= features.section_count <= 12:
            score += 0.15
        
        # Penalty for textbook indicators
        if features.has_chapters:
            score -= 0.2
        
        return max(0.0, min(score, 1.0))
    
    def _calculate_technical_score(self, features: ClassificationFeatures) -> float:
        """Calculate probability that document is technical documentation, blog, or tutorial"""
        score = 0.0
        
        # Blog/tutorial indicators
        if features.blog_tutorial_keywords > 5:
            score += 0.5  # Strong indicator for tutorials/blogs
        elif features.blog_tutorial_keywords > 3:
            score += 0.3
        elif features.blog_tutorial_keywords > 1:
            score += 0.2
        
        # Technical keyword indicators
        if features.technical_keywords > 8:
            score += 0.3
        elif features.technical_keywords > 5:
            score += 0.2
        elif features.technical_keywords > 2:
            score += 0.1
        
        # Medium length technical content (blogs/tutorials)
        if 3000 <= features.word_count <= 8000:
            score += 0.2
        elif 1000 <= features.word_count <= 15000:
            score += 0.1
        
        # Simple structure (not academic rigor) - typical of blogs/tutorials
        if features.section_count <= 15 and not features.has_chapters:
            score += 0.15
        
        # Mix of technical and tutorial content
        if features.technical_keywords > 3 and features.blog_tutorial_keywords > 3:
            score += 0.2
        
        # Penalty for strong academic indicators
        if features.has_chapters or features.section_count > 100:
            score -= 0.3
        
        return max(0.0, min(score, 1.0))
    
    def _calculate_short_text_score(self, features: ClassificationFeatures) -> float:
        """Calculate probability that document is short text"""
        score = 0.0
        
        # Length indicators
        if features.word_count < 1000:
            score += 0.4
        elif features.word_count < 2000:
            score += 0.2
        
        # Page count
        if features.page_count <= 3:
            score += 0.2
        
        # Simple structure
        if features.section_count <= 3:
            score += 0.15
        
        # Lack of complex structure
        if not features.has_toc and not features.has_bibliography:
            score += 0.1
        
        return min(score, 1.0)
    
    def _detect_table_of_contents(self, text: str) -> bool:
        """Detect presence of table of contents"""
        toc_patterns = [
            r'table\s+of\s+contents',
            r'contents',
            r'chapter\s+\d+.*\.\.\.',
            r'section\s+\d+.*\.\.\.'
        ]
        text_lower = text.lower()
        return any(re.search(pattern, text_lower) for pattern in toc_patterns)
    
    def _detect_bibliography(self, text: str) -> bool:
        """Detect presence of bibliography or references"""
        bib_patterns = [
            r'bibliography',
            r'references',
            r'works\s+cited',
            r'further\s+reading'
        ]
        text_lower = text.lower()
        return any(re.search(pattern, text_lower) for pattern in bib_patterns)
    
    def _detect_chapters(self, text: str) -> bool:
        """Detect presence of chapters"""
        chapter_patterns = [
            r'chapter\s+\d+',
            r'chapter\s+[ivx]+',
            r'chapter\s+[a-z]+'
        ]
        text_lower = text.lower()
        return any(re.search(pattern, text_lower) for pattern in chapter_patterns)
    
    def _detect_abstract(self, text: str) -> bool:
        """Detect presence of abstract"""
        # Look for "abstract" at the beginning of document
        first_500_chars = text[:500].lower()
        return 'abstract' in first_500_chars
    
    def _count_sections(self, text: str) -> int:
        """Count the number of sections in the document"""
        # Simple heuristic: count lines that look like headers
        lines = text.split('\n')
        section_count = 0
        
        for line in lines:
            line_stripped = line.strip()
            if not line_stripped:
                continue
            
            # Check various header patterns
            if (line_stripped.isupper() and len(line_stripped.split()) <= 6 or
                re.match(r'^\d+\.?\s+[A-Z]', line_stripped) or
                re.match(r'^[A-Z][^.!?]*:$', line_stripped) or
                line_stripped.startswith('#')):
                section_count += 1
        
        return section_count
    
    def _count_citations(self, text: str) -> int:
        """Count citations in the text - DISABLED as citations can't be reliably detected from PDF files"""
        # Citation detection disabled per user feedback - citations can't be reliably detected from PDF files alone
        # since references like [1] or (Smith, 2020) could be anything in the extracted text
        return 0
    
    def _get_classification_reasoning(self, features: ClassificationFeatures, doc_type: DocumentType) -> str:
        """Generate human-readable reasoning for classification"""
        reasoning_parts = []
        
        if doc_type == DocumentType.TEXTBOOK:
            reasoning_parts.append(f"Long document ({features.word_count} words)")
            if features.has_chapters:
                reasoning_parts.append("Contains chapters")
            if features.textbook_keywords > 2:
                reasoning_parts.append(f"Contains educational keywords ({features.textbook_keywords})")
        
        elif doc_type == DocumentType.PAPER:
            if features.has_abstract:
                reasoning_parts.append("Contains abstract")
            if features.academic_keywords > 2:
                reasoning_parts.append(f"Contains academic keywords ({features.academic_keywords})")
            # Citation reasoning removed since citation detection was disabled
            # if features.citation_count > 5:
            #     reasoning_parts.append(f"Contains citations ({features.citation_count})")
        
        elif doc_type == DocumentType.SHORT_TEXT:
            reasoning_parts.append(f"Short document ({features.word_count} words)")
            reasoning_parts.append("Simple structure")
        
        return "; ".join(reasoning_parts) if reasoning_parts else "Classification based on overall features"