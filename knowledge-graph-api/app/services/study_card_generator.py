from typing import List, Dict, Any, Optional
import anthropic
from app.core.config import settings
from app.services.database_service import DatabaseService

class StudyCardGenerator:
    """Service for generating study cards from knowledge graph concepts"""
    
    def __init__(self):
        self.client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
        self.db_service = DatabaseService()
        
        # System message for study card generation
        self.system_message = """You are an expert educational content creator. Your task is to create effective study cards from knowledge graph concepts.

Guidelines:
- Create bite-sized, digestible content
- Use the knowledge graph structure to create contextual cards
- Make cards that build upon each other logically
- Include different types of cards: definition, example, application, connection
- Ensure cards are appropriate for the difficulty level
- Use active recall principles

Return structured JSON only."""

    async def generate_document_study_cards(
        self, 
        document_id: str, 
        user_id: str, 
        max_cards: int = 20,
        session_type: str = "review"
    ) -> List[Dict[str, Any]]:
        """Generate study cards for an entire document"""
        
        try:
            # Get concepts from the document
            concepts = await self.db_service.get_document_concepts(document_id, user_id)
            
            if not concepts:
                return []
            
            # Get user's progress to personalize cards
            concept_ids = [c["id"] for c in concepts]
            progress_data = await self.db_service.get_user_progress(user_id, concept_ids)
            progress_map = {p["concept_id"]: p for p in progress_data}
            
            # Select concepts based on session type and progress
            selected_concepts = self._select_concepts_for_session(
                concepts, progress_map, session_type, max_cards
            )
            
            # Generate cards for selected concepts
            cards = []
            for concept in selected_concepts:
                concept_cards = await self._generate_concept_cards(concept, session_type)
                cards.extend(concept_cards)
                
                if len(cards) >= max_cards:
                    break
            
            return cards[:max_cards]
            
        except Exception as e:
            print(f"Failed to generate document study cards: {e}")
            return []
    
    async def generate_concept_study_cards(
        self, 
        concept_ids: List[str], 
        user_id: str, 
        session_type: str = "learn",
        card_types: Optional[List[str]] = None
    ) -> List[Dict[str, Any]]:
        """Generate study cards for specific concepts"""
        
        try:
            # This would require a method to get concepts by IDs
            # For now, implement a simplified version
            
            cards = []
            for concept_id in concept_ids:
                # Get related concepts for context
                related_concepts = await self.db_service.get_related_concepts(concept_id)
                
                # Generate cards for this concept
                concept_cards = await self._generate_cards_for_concept_id(
                    concept_id, related_concepts, session_type, card_types
                )
                cards.extend(concept_cards)
            
            return cards
            
        except Exception as e:
            print(f"Failed to generate concept study cards: {e}")
            return []
    
    async def generate_review_session(
        self, 
        user_id: str, 
        max_cards: int = 20
    ) -> List[Dict[str, Any]]:
        """Generate a general review session based on user's progress"""
        
        try:
            # Get user's progress data
            progress_data = await self.db_service.get_user_progress(user_id)
            
            if not progress_data:
                return []
            
            # Prioritize concepts that need review (low mastery, not studied recently)
            concepts_to_review = [
                p for p in progress_data 
                if p["mastery_level"] < 0.7 or not p.get("last_studied_at")
            ]
            
            # Sort by priority (low mastery first, then by last studied)
            concepts_to_review.sort(key=lambda x: (x["mastery_level"], x.get("last_studied_at", "")))
            
            # Generate cards for priority concepts
            cards = []
            for progress in concepts_to_review[:max_cards]:
                concept_cards = await self._generate_cards_for_concept_id(
                    progress["concept_id"], [], "review"
                )
                cards.extend(concept_cards)
                
                if len(cards) >= max_cards:
                    break
            
            return cards[:max_cards]
            
        except Exception as e:
            print(f"Failed to generate review session: {e}")
            return []
    
    def _select_concepts_for_session(
        self,
        concepts: List[Dict[str, Any]],
        progress_map: Dict[str, Dict[str, Any]],
        session_type: str,
        max_concepts: int
    ) -> List[Dict[str, Any]]:
        """Select which concepts to include in the study session"""
        
        if session_type == "learn":
            # For learning, prioritize high-importance concepts user hasn't studied
            unStudied = [c for c in concepts if c["id"] not in progress_map]
            studied_low = [c for c in concepts if c["id"] in progress_map and progress_map[c["id"]]["mastery_level"] < 0.5]
            
            selected = sorted(unStudied, key=lambda x: x["importance_score"], reverse=True)
            selected.extend(sorted(studied_low, key=lambda x: x["importance_score"], reverse=True))
            
        elif session_type == "review":
            # For review, prioritize concepts with low mastery that have been studied
            studied = [c for c in concepts if c["id"] in progress_map]
            selected = sorted(
                studied, 
                key=lambda x: progress_map[x["id"]]["mastery_level"]
            )
            
        elif session_type == "test":
            # For testing, include a mix of concepts
            selected = sorted(concepts, key=lambda x: x["importance_score"], reverse=True)
            
        else:  # browse
            # For browsing, include variety of concepts
            selected = sorted(concepts, key=lambda x: x["importance_score"], reverse=True)
        
        return selected[:max_concepts]
    
    async def _generate_concept_cards(
        self,
        concept: Dict[str, Any],
        session_type: str
    ) -> List[Dict[str, Any]]:
        """Generate study cards for a single concept"""
        
        concept_content = f"""
        Title: {concept['title']}
        Content: {concept['content']}
        Type: {concept['concept_type']}
        Difficulty: {concept['difficulty_level']}
        Section: {concept.get('section_title', 'N/A')}
        """
        
        prompt = f"""Create study cards for this concept based on session type '{session_type}':

{concept_content}

Generate 2-3 different types of study cards. Choose from:
- definition: Front has question, back has definition
- example: Front has concept, back has concrete example  
- application: Front has scenario, back has how concept applies
- connection: Front has concept, back shows relationship to other ideas

Return JSON:
{{
    "cards": [
        {{
            "concept_id": "{concept['id']}",
            "card_type": "definition|example|application|connection",
            "front_content": "Question or prompt",
            "back_content": "Answer or explanation",
            "difficulty": 1-5,
            "tags": ["tag1", "tag2"],
            "metadata": {{"concept_type": "{concept['concept_type']}"}}
        }}
    ]
}}"""

        response = await self._call_claude(prompt)
        parsed_response = self._parse_claude_response(response)
        
        return parsed_response.get("cards", [])
    
    async def _generate_cards_for_concept_id(
        self,
        concept_id: str,
        related_concepts: List[Dict[str, Any]],
        session_type: str,
        card_types: Optional[List[str]] = None
    ) -> List[Dict[str, Any]]:
        """Generate cards for a concept given its ID and related concepts"""
        
        # This is a simplified implementation
        # In practice, you'd fetch the full concept data
        
        related_context = ""
        if related_concepts:
            related_context = "Related concepts: " + ", ".join([
                f"{rc['title']} ({rc['relationship_type']})" 
                for rc in related_concepts[:3]
            ])
        
        prompt = f"""Create study cards for concept ID: {concept_id}

{related_context}

Session type: {session_type}
{'Card types requested: ' + ', '.join(card_types) if card_types else ''}

Generate appropriate study cards that help with {session_type}.

Return JSON:
{{
    "cards": [
        {{
            "concept_id": "{concept_id}",
            "card_type": "type",
            "front_content": "Front",
            "back_content": "Back", 
            "difficulty": 3,
            "tags": [],
            "metadata": {{}}
        }}
    ]
}}"""

        response = await self._call_claude(prompt)
        parsed_response = self._parse_claude_response(response)
        
        return parsed_response.get("cards", [])
    
    async def _call_claude(self, prompt: str) -> str:
        """Make API call to Claude"""
        try:
            if hasattr(self.client, 'messages'):
                response = self.client.messages.create(
                    model="claude-3-5-sonnet-20241022",
                    max_tokens=2000,
                    temperature=0.2,
                    system=self.system_message,
                    messages=[{"role": "user", "content": prompt}]
                )
                return response.content[0].text
            else:
                print("Using mock study card generation")
                return self._mock_study_cards()
        except Exception as e:
            print(f"Claude API error in study card generation: {e}")
            return self._mock_study_cards()
    
    def _mock_study_cards(self) -> str:
        """Mock study card response"""
        return """{
            "cards": [
                {
                    "concept_id": "test_concept",
                    "card_type": "definition",
                    "front_content": "What is a Mixture of Experts?",
                    "back_content": "A machine learning technique that uses multiple specialized models to handle different parts of the input space.",
                    "difficulty": 3,
                    "tags": ["machine learning"],
                    "metadata": {"concept_type": "definition"}
                }
            ]
        }"""
    
    def _parse_claude_response(self, response: str) -> Dict[str, Any]:
        """Parse Claude's JSON response"""
        try:
            import json
            
            # Extract JSON from response if wrapped
            if "```json" in response:
                json_start = response.find("```json") + 7
                json_end = response.find("```", json_start)
                response = response[json_start:json_end]
            elif "```" in response:
                json_start = response.find("```") + 3
                json_end = response.find("```", json_start)
                response = response[json_start:json_end]
            
            result = json.loads(response.strip())
            
            # Ensure cards field exists
            if "cards" not in result:
                result["cards"] = []
            
            return result
            
        except json.JSONDecodeError as e:
            print(f"Failed to parse study card response: {e}")
            print(f"Response was: {response[:500]}")
            return {"cards": []}