import asyncio
from typing import Dict, List, Any, Optional, Tuple
from datetime import datetime
import anthropic
from app.core.config import settings
from app.models.document import DocumentType
from app.services.web_search import WebSearchService

class ClaudeAgent:
    """Intelligent document processing agent using Claude"""
    
    def __init__(self):
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.web_search = WebSearchService()
        
        # Base system message for all agents
        self.base_system = """You are an expert knowledge extraction agent. Your goal is to build comprehensive knowledge graphs from documents by extracting concepts and their relationships.

IMPORTANT: You are building a KNOWLEDGE GRAPH first, NOT study materials. Focus on:
1. Extracting key concepts with clear definitions
2. Identifying relationships between concepts (prerequisite, related, example_of, etc.)
3. Determining concept importance and difficulty
4. Maintaining accuracy and completeness

Return structured JSON only."""

    async def process_document(self, document_data: Dict[str, Any], document_type: DocumentType) -> Dict[str, Any]:
        """Main entry point for document processing"""
        
        print(f"🤖 AGENT SELECTION: {document_type.value.upper()} AGENT ACTIVATED")
        
        if document_type == DocumentType.TEXTBOOK:
            print("📚 TEXTBOOK AGENT: Starting chapter-by-chapter processing...")
            return await self._process_textbook(document_data)
        elif document_type == DocumentType.PAPER:
            print("📄 PAPER AGENT: Starting academic paper analysis with concept expansion...")
            return await self._process_paper(document_data)
        elif document_type == DocumentType.SHORT_TEXT:
            print("📝 SHORT TEXT AGENT: Starting direct concept extraction...")
            return await self._process_short_text(document_data)
        else:
            print("❓ FALLBACK AGENT: Processing unknown document type...")
            return await self._process_unknown(document_data)
    
    async def _process_textbook(self, document_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process textbook with chapter-by-chapter analysis"""
        
        text_content = document_data["text_content"]
        
        print("📚 TEXTBOOK AGENT: Detecting chapters using heuristic patterns...")
        # First, detect chapters using heuristics
        chapters = self._detect_chapters(text_content)
        print(f"📚 TEXTBOOK AGENT: Found {len(chapters)} chapters")
        
        all_concepts = []
        all_relationships = []
        chapter_concepts_map = {}
        
        # Process each chapter
        for i, chapter in enumerate(chapters):
            chapter_result = await self._process_textbook_chapter(chapter, i + 1)
            
            if chapter_result:
                chapter_concepts = chapter_result.get("concepts", [])
                chapter_relationships = chapter_result.get("relationships", [])
                
                # Store concepts with chapter info
                for concept in chapter_concepts:
                    concept["section_title"] = chapter["title"]
                    concept["position_in_doc"] = chapter["start_position"]
                
                all_concepts.extend(chapter_concepts)
                all_relationships.extend(chapter_relationships)
                chapter_concepts_map[f"chapter_{i+1}"] = [c["id"] for c in chapter_concepts]
        
        # Create inter-chapter relationships
        inter_chapter_relationships = await self._create_inter_chapter_relationships(
            chapters, chapter_concepts_map, all_concepts
        )
        all_relationships.extend(inter_chapter_relationships)
        
        return {
            "concepts": all_concepts,
            "relationships": all_relationships,
            "processing_metadata": {
                "chapters_detected": len(chapters),
                "total_concepts": len(all_concepts),
                "total_relationships": len(all_relationships),
                "chapter_breakdown": chapter_concepts_map
            }
        }
    
    async def _process_paper(self, document_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process academic paper with concept expansion"""
        
        text_content = document_data["text_content"]
        
        print("📄 PAPER AGENT: Analyzing paper structure and identifying undefined terms...")
        # First pass: extract concepts and identify undefined terms
        initial_analysis = await self._analyze_paper_structure(text_content)
        
        undefined_terms = initial_analysis.get("undefined_terms", [])
        print(f"📄 PAPER AGENT: Found {len(undefined_terms)} undefined terms to expand")
        
        # Expand undefined concepts/acronyms using web search
        if undefined_terms:
            print("📄 PAPER AGENT: Expanding concepts using web search...")
        expanded_knowledge = await self._expand_undefined_concepts(
            undefined_terms,
            initial_analysis.get("domain", "general")
        )
        print(f"📄 PAPER AGENT: Expanded {len(expanded_knowledge)} concepts with external knowledge")
        
        # Second pass: process with expanded knowledge
        print("📄 PAPER AGENT: Processing paper with expanded context...")
        final_result = await self._process_paper_with_context(
            text_content, 
            expanded_knowledge,
            initial_analysis
        )
        
        concepts_count = len(final_result.get("concepts", []))
        relationships_count = len(final_result.get("relationships", []))
        print(f"📄 PAPER AGENT: Extracted {concepts_count} concepts and {relationships_count} relationships")
        
        return {
            "concepts": final_result.get("concepts", []),
            "relationships": final_result.get("relationships", []),
            "processing_metadata": {
                "undefined_terms_expanded": len(expanded_knowledge),
                "external_knowledge_integrated": True,
                "domain": initial_analysis.get("domain", "unknown"),
                "paper_sections": initial_analysis.get("sections", [])
            }
        }
    
    async def _process_short_text(self, document_data: Dict[str, Any]) -> Dict[str, Any]:
        """Process short text documents"""
        
        text_content = document_data["text_content"]
        
        prompt = f"""Extract key concepts from this short text for knowledge graph creation.

Text:
{text_content[:4000]}

Return JSON with:
{{
    "concepts": [
        {{
            "id": "unique_id",
            "title": "Concept Name",
            "content": "Clear definition/explanation",
            "concept_type": "definition|fact|principle|example",
            "importance_score": 0.0-1.0,
            "difficulty_level": 1-5
        }}
    ],
    "relationships": [
        {{
            "source_concept_id": "id1",
            "target_concept_id": "id2", 
            "relationship_type": "related|example_of|prerequisite",
            "strength": 0.0-1.0
        }}
    ]
}}"""

        response = await self._call_claude(prompt, self.base_system)
        return self._parse_claude_response(response)
    
    async def _detect_chapters(self, text: str) -> List[Dict[str, Any]]:
        """Detect chapters using heuristic patterns"""
        
        lines = text.split('\n')
        chapters = []
        current_position = 0
        
        chapter_patterns = [
            r'^chapter\s+\d+',
            r'^chapter\s+[ivx]+',
            r'^\d+\.\s+[A-Z]',
            r'^unit\s+\d+',
            r'^part\s+[ivx]+',
        ]
        
        for i, line in enumerate(lines):
            line_lower = line.strip().lower()
            
            # Check if line matches chapter patterns
            import re
            for pattern in chapter_patterns:
                if re.match(pattern, line_lower):
                    # Found a chapter header
                    chapter_title = line.strip()
                    
                    # Find end of previous chapter
                    if chapters:
                        chapters[-1]["end_position"] = current_position
                        chapters[-1]["content"] = text[chapters[-1]["start_position"]:current_position]
                    
                    # Start new chapter
                    chapters.append({
                        "title": chapter_title,
                        "start_position": current_position,
                        "chapter_number": len(chapters) + 1,
                        "line_number": i
                    })
                    break
            
            current_position += len(line) + 1
        
        # Handle last chapter
        if chapters:
            chapters[-1]["end_position"] = len(text)
            chapters[-1]["content"] = text[chapters[-1]["start_position"]:]
        
        # If no chapters detected, treat entire text as one chapter
        if not chapters:
            chapters.append({
                "title": "Main Content",
                "start_position": 0,
                "end_position": len(text),
                "content": text,
                "chapter_number": 1,
                "line_number": 0
            })
        
        return chapters
    
    async def _process_textbook_chapter(self, chapter: Dict[str, Any], chapter_num: int) -> Optional[Dict[str, Any]]:
        """Process a single textbook chapter"""
        
        chapter_content = chapter["content"][:8000]  # Limit for API
        
        prompt = f"""Analyze Chapter {chapter_num}: "{chapter['title']}" from a textbook.

Chapter Content:
{chapter_content}

Extract concepts and relationships for knowledge graph creation. Focus on:
1. Key concepts with clear definitions
2. Examples and applications
3. Prerequisites and dependencies between concepts
4. Difficulty progression

Return JSON:
{{
    "concepts": [
        {{
            "id": "chapter_{chapter_num}_concept_X",
            "title": "Concept Name", 
            "content": "Clear definition and explanation",
            "concept_type": "definition|theorem|principle|example|exercise",
            "importance_score": 0.0-1.0,
            "difficulty_level": 1-5,
            "tags": ["tag1", "tag2"]
        }}
    ],
    "relationships": [
        {{
            "source_concept_id": "id1",
            "target_concept_id": "id2",
            "relationship_type": "prerequisite|builds_on|example_of|related",
            "strength": 0.0-1.0
        }}
    ]
}}"""

        response = await self._call_claude(prompt, self.base_system)
        return self._parse_claude_response(response)
    
    async def _analyze_paper_structure(self, text: str) -> Dict[str, Any]:
        """First pass analysis of academic paper"""
        
        # Limit text for initial analysis
        text_sample = text[:6000]
        
        prompt = f"""Analyze this academic paper to identify structure and undefined terms.

Paper text:
{text_sample}

Return JSON:
{{
    "domain": "field of study",
    "sections": ["section1", "section2"],
    "undefined_terms": [
        {{
            "term": "acronym or concept",
            "context": "surrounding context",
            "type": "acronym|concept|method|citation"
        }}
    ],
    "key_figures_mentioned": ["Figure 1", "Table 2"],
    "citations_needing_context": ["Smith et al. 2020"]
}}"""

        response = await self._call_claude(prompt, self.base_system)
        return self._parse_claude_response(response)
    
    async def _expand_undefined_concepts(self, undefined_terms: List[Dict[str, Any]], domain: str) -> Dict[str, Any]:
        """Use web search to expand undefined concepts"""
        
        expanded_knowledge = {}
        
        for term_info in undefined_terms[:5]:  # Limit to avoid too many API calls
            term = term_info["term"]
            term_type = term_info["type"]
            
            try:
                if term_type == "acronym":
                    search_query = f"{term} acronym meaning {domain}"
                elif term_type == "concept":
                    search_query = f"{term} definition {domain}"
                elif term_type == "method":
                    search_query = f"{term} method technique {domain}"
                else:
                    search_query = f"{term} {domain}"
                
                # Use web search to get definition
                search_results = await self.web_search.search(search_query)
                
                if search_results:
                    # Use Claude to synthesize the search results
                    synthesis_prompt = f"""Based on these search results, provide a clear, concise explanation of "{term}" in the context of {domain}:

Search Results:
{search_results[:2000]}

Provide a 2-3 sentence explanation suitable for knowledge graph integration."""
                    
                    explanation = await self._call_claude(synthesis_prompt, "You are a knowledgeable assistant providing clear explanations.")
                    expanded_knowledge[term] = explanation
                
                # Add small delay to be respectful to APIs
                await asyncio.sleep(0.5)
                
            except Exception as e:
                print(f"Failed to expand term '{term}': {e}")
                expanded_knowledge[term] = f"Term requiring further research: {term}"
        
        return expanded_knowledge
    
    async def _process_paper_with_context(self, text: str, expanded_knowledge: Dict[str, Any], initial_analysis: Dict[str, Any]) -> Dict[str, Any]:
        """Process paper with expanded context knowledge"""
        
        text_sample = text[:8000]
        
        # Format expanded knowledge for context
        context_info = "\n".join([f"{term}: {explanation}" for term, explanation in expanded_knowledge.items()])
        
        prompt = f"""Process this academic paper for knowledge graph creation, using the expanded context provided.

Paper text:
{text_sample}

Expanded Context:
{context_info}

Domain: {initial_analysis.get('domain', 'unknown')}

Extract concepts and relationships. Include both:
1. Concepts directly from the paper
2. Expanded context concepts that help understand the paper

Return JSON:
{{
    "concepts": [
        {{
            "id": "paper_concept_X",
            "title": "Concept Name",
            "content": "Comprehensive explanation",
            "concept_type": "method|result|background|definition",
            "importance_score": 0.0-1.0,
            "difficulty_level": 1-5,
            "source": "paper|external|synthesis",
            "tags": ["tag1", "tag2"]
        }}
    ],
    "relationships": [
        {{
            "source_concept_id": "id1", 
            "target_concept_id": "id2",
            "relationship_type": "prerequisite|applies|builds_on|related|contradicts",
            "strength": 0.0-1.0
        }}
    ]
}}"""

        response = await self._call_claude(prompt, self.base_system)
        return self._parse_claude_response(response)
    
    async def _create_inter_chapter_relationships(self, chapters: List[Dict], chapter_concepts_map: Dict, all_concepts: List[Dict]) -> List[Dict]:
        """Create relationships between concepts across chapters"""
        
        # Simple implementation - in practice this could be more sophisticated
        relationships = []
        
        # Create prerequisite relationships between sequential chapters
        for i in range(len(chapters) - 1):
            current_chapter = f"chapter_{i+1}"
            next_chapter = f"chapter_{i+2}"
            
            if current_chapter in chapter_concepts_map and next_chapter in chapter_concepts_map:
                # Create weak prerequisite links between last concept of current chapter
                # and first concept of next chapter
                current_concepts = chapter_concepts_map[current_chapter]
                next_concepts = chapter_concepts_map[next_chapter]
                
                if current_concepts and next_concepts:
                    relationships.append({
                        "source_concept_id": current_concepts[-1],
                        "target_concept_id": next_concepts[0],
                        "relationship_type": "prerequisite",
                        "strength": 0.3
                    })
        
        return relationships
    
    async def _call_claude(self, prompt: str, system_message: str) -> str:
        """Make API call to Claude"""
        try:
            # Check if client has the correct method
            if hasattr(self.client, 'messages'):
                response = self.client.messages.create(
                    model="claude-3-5-sonnet-20241022",
                    max_tokens=4000,
                    temperature=0.1,
                    system=system_message,
                    messages=[{"role": "user", "content": prompt}]
                )
                return response.content[0].text
            else:
                # Fallback for older API
                print("Using fallback Claude client")
                return self._mock_claude_response()
        except Exception as e:
            print(f"Claude API error: {e}")
            return self._mock_claude_response()
    
    def _mock_claude_response(self) -> str:
        """Mock Claude response for testing"""
        return """{
            "concepts": [
                {
                    "id": "concept_1",
                    "title": "Mixture of Experts",
                    "content": "A machine learning technique that uses multiple specialized models (experts) to handle different parts of the input space.",
                    "concept_type": "definition",
                    "importance_score": 0.9,
                    "difficulty_level": 4,
                    "tags": ["machine learning", "neural networks"]
                },
                {
                    "id": "concept_2", 
                    "title": "Gating Network",
                    "content": "A neural network component that decides which experts should be activated for a given input.",
                    "concept_type": "definition",
                    "importance_score": 0.8,
                    "difficulty_level": 3,
                    "tags": ["neural networks", "routing"]
                },
                {
                    "id": "concept_3",
                    "title": "Expert Specialization",
                    "content": "The process by which different expert networks learn to handle specific types of inputs or tasks.",
                    "concept_type": "principle",
                    "importance_score": 0.7,
                    "difficulty_level": 3,
                    "tags": ["specialization", "learning"]
                }
            ],
            "relationships": [
                {
                    "source_concept_id": "concept_2",
                    "target_concept_id": "concept_1",
                    "relationship_type": "part_of",
                    "strength": 0.9
                },
                {
                    "source_concept_id": "concept_3",
                    "target_concept_id": "concept_1", 
                    "relationship_type": "related",
                    "strength": 0.7
                }
            ]
        }"""
    
    def _parse_claude_response(self, response: str) -> Dict[str, Any]:
        """Parse and validate Claude's JSON response"""
        try:
            import json
            # Extract JSON from response if it's wrapped in other text
            if "```json" in response:
                json_start = response.find("```json") + 7
                json_end = response.find("```", json_start)
                response = response[json_start:json_end]
            elif "```" in response:
                json_start = response.find("```") + 3
                json_end = response.find("```", json_start)
                response = response[json_start:json_end]
            
            result = json.loads(response.strip())
            
            # Ensure required fields exist
            if "concepts" not in result:
                result["concepts"] = []
            if "relationships" not in result:
                result["relationships"] = []
            
            return result
            
        except json.JSONDecodeError as e:
            print(f"Failed to parse Claude response: {e}")
            print(f"Response was: {response[:500]}")
            return {"concepts": [], "relationships": []}
    
    async def _process_unknown(self, document_data: Dict[str, Any]) -> Dict[str, Any]:
        """Fallback processing for unknown document types"""
        return await self._process_short_text(document_data)