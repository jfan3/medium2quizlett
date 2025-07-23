import asyncio
import aiohttp
from typing import List, Dict, Any, Optional
from urllib.parse import quote_plus
import json

class WebSearchService:
    """Service for web search to expand undefined concepts"""
    
    def __init__(self):
        # You can configure different search providers here
        self.search_providers = {
            "duckduckgo": self._search_duckduckgo,
            "wikipedia": self._search_wikipedia
        }
        self.default_provider = "duckduckgo"
    
    async def search(self, query: str, max_results: int = 3) -> str:
        """Search for information about a query and return summarized results"""
        try:
            # Try primary search provider
            results = await self.search_providers[self.default_provider](query, max_results)
            
            if not results:
                # Fallback to Wikipedia if primary fails
                results = await self._search_wikipedia(query, max_results)
            
            # Format results into readable text
            return self._format_search_results(results)
            
        except Exception as e:
            print(f"Web search failed for query '{query}': {e}")
            return ""
    
    async def _search_duckduckgo(self, query: str, max_results: int = 3) -> List[Dict[str, Any]]:
        """Search using DuckDuckGo Instant Answer API"""
        try:
            encoded_query = quote_plus(query)
            url = f"https://api.duckduckgo.com/?q={encoded_query}&format=json&no_html=1&skip_disambig=1"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(url, timeout=10) as response:
                    if response.status == 200:
                        data = await response.json()
                        
                        results = []
                        
                        # Check for instant answer
                        if data.get("Abstract"):
                            results.append({
                                "title": data.get("AbstractText", ""),
                                "content": data.get("Abstract", ""),
                                "source": data.get("AbstractSource", "DuckDuckGo"),
                                "url": data.get("AbstractURL", "")
                            })
                        
                        # Check for definition
                        if data.get("Definition"):
                            results.append({
                                "title": "Definition",
                                "content": data.get("Definition", ""),
                                "source": data.get("DefinitionSource", ""),
                                "url": data.get("DefinitionURL", "")
                            })
                        
                        # Check related topics
                        for topic in data.get("RelatedTopics", [])[:2]:
                            if isinstance(topic, dict) and topic.get("Text"):
                                results.append({
                                    "title": topic.get("Text", "")[:100],
                                    "content": topic.get("Text", ""),
                                    "source": "DuckDuckGo",
                                    "url": topic.get("FirstURL", "")
                                })
                        
                        return results[:max_results]
            
            return []
            
        except Exception as e:
            print(f"DuckDuckGo search error: {e}")
            return []
    
    async def _search_wikipedia(self, query: str, max_results: int = 2) -> List[Dict[str, Any]]:
        """Search Wikipedia for concept definitions"""
        try:
            # First, search for the page
            search_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{quote_plus(query)}"
            
            async with aiohttp.ClientSession() as session:
                async with session.get(search_url, timeout=10) as response:
                    if response.status == 200:
                        data = await response.json()
                        
                        if data.get("extract"):
                            return [{
                                "title": data.get("title", query),
                                "content": data.get("extract", ""),
                                "source": "Wikipedia",
                                "url": data.get("content_urls", {}).get("desktop", {}).get("page", "")
                            }]
            
            # If direct lookup fails, try search API
            search_api_url = f"https://en.wikipedia.org/api/rest_v1/page/summary/{quote_plus(query)}"
            async with aiohttp.ClientSession() as session:
                async with session.get(search_api_url, timeout=10) as response:
                    if response.status == 200:
                        data = await response.json()
                        if data.get("extract"):
                            return [{
                                "title": data.get("title", query),
                                "content": data.get("extract", ""),
                                "source": "Wikipedia", 
                                "url": data.get("content_urls", {}).get("desktop", {}).get("page", "")
                            }]
            
            return []
            
        except Exception as e:
            print(f"Wikipedia search error: {e}")
            return []
    
    def _format_search_results(self, results: List[Dict[str, Any]]) -> str:
        """Format search results into readable text"""
        if not results:
            return ""
        
        formatted_parts = []
        for i, result in enumerate(results, 1):
            title = result.get("title", "Unknown")
            content = result.get("content", "")
            source = result.get("source", "Unknown")
            
            # Limit content length
            if len(content) > 300:
                content = content[:300] + "..."
            
            formatted_parts.append(f"{i}. {title} ({source}):\n{content}")
        
        return "\n\n".join(formatted_parts)
    
    async def search_academic_concept(self, concept: str, domain: str = "") -> str:
        """Specialized search for academic concepts"""
        # Construct a more targeted query
        if domain:
            query = f"{concept} {domain} definition academic"
        else:
            query = f"{concept} definition academic research"
        
        return await self.search(query, max_results=2)
    
    async def search_acronym(self, acronym: str, context: str = "") -> str:
        """Specialized search for acronym expansion"""
        if context:
            query = f"{acronym} acronym meaning {context}"
        else:
            query = f"{acronym} acronym meaning"
        
        return await self.search(query, max_results=1)
    
    async def search_citation_context(self, citation: str, domain: str = "") -> str:
        """Search for context about cited papers"""
        # This is a simplified implementation
        # In practice, you might use academic APIs like Semantic Scholar
        query = f"{citation} abstract summary {domain}"
        return await self.search(query, max_results=1)