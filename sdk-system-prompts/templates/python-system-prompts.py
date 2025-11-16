#!/usr/bin/env python3
"""
Python System Prompts Manager for Claude Agent SDK

Provides utilities for loading, managing, and switching between different
system prompts based on context and user requirements.
"""

import os
import json
from pathlib import Path
from typing import Dict, Optional, List
from dataclasses import dataclass

@dataclass
class SystemPrompt:
    """Represents a system prompt with metadata"""
    name: str
    content: str
    category: str
    description: str
    variables: List[str]
    tags: List[str]

class SystemPromptManager:
    """Manages system prompts for Claude Python Agent"""

    def __init__(self, prompts_dir: Optional[str] = None):
        """
        Initialize the system prompt manager.

        Args:
            prompts_dir: Directory containing prompt markdown files
        """
        if prompts_dir is None:
            # Default to the package's prompts directory
            prompts_dir = Path(__file__).parent.parent / "sdk-system-prompts"

        self.prompts_dir = Path(prompts_dir)
        self._prompts: Dict[str, SystemPrompt] = {}
        self._load_prompts()

    def _load_prompts(self):
        """Load all system prompts from markdown files"""
        if not self.prompts_dir.exists():
            raise FileNotFoundError(f"Prompts directory not found: {self.prompts_dir}")

        # Load prompts from different categories
        categories = ["shared", "claude-code-cli", "python-sdk", "typescript-sdk"]

        for category in categories:
            category_dir = self.prompts_dir / category
            if category_dir.exists():
                self._load_category_prompts(category_dir, category)

    def _load_category_prompts(self, category_dir: Path, category: str):
        """Load prompts from a specific category directory"""
        for prompt_file in category_dir.glob("*.md"):
            prompt = self._parse_prompt_file(prompt_file, category)
            if prompt:
                self._prompts[prompt.name] = prompt

    def _parse_prompt_file(self, file_path: Path, category: str) -> Optional[SystemPrompt]:
        """Parse a markdown file into a SystemPrompt object"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()

            # Extract metadata from frontmatter or comments
            name = file_path.stem
            description = self._extract_description(content)
            variables = self._extract_variables(content)
            tags = self._extract_tags(content)

            return SystemPrompt(
                name=name,
                content=content,
                category=category,
                description=description,
                variables=variables,
                tags=tags
            )
        except Exception as e:
            print(f"Error parsing prompt file {file_path}: {e}")
            return None

    def _extract_description(self, content: str) -> str:
        """Extract description from markdown content"""
        lines = content.split('\n')
        for line in lines:
            if line.strip().startswith('# '):
                return line.strip().lstrip('# ').strip()
        return "No description available"

    def _extract_variables(self, content: str) -> List[str]:
        """Extract variable placeholders from content"""
        import re
        # Find {{variable}} patterns
        variables = re.findall(r'\{\{(\w+)\}\}', content)
        return list(set(variables))

    def _extract_tags(self, content: str) -> List[str]:
        """Extract tags from content"""
        tags = []
        lines = content.split('\n')
        for line in lines:
            if line.strip().startswith('Tags:'):
                tags = [tag.strip() for tag in line.replace('Tags:', '').split(',')]
                break
        return tags

    def get_prompt(self, name: str, variables: Optional[Dict[str, str]] = None) -> str:
        """
        Get a system prompt by name with variable substitution.

        Args:
            name: Name of the prompt
            variables: Dictionary of variable values for substitution

        Returns:
            The prompt content with variables substituted
        """
        if name not in self._prompts:
            raise ValueError(f"Prompt '{name}' not found")

        prompt = self._prompts[name]
        content = prompt.content

        # Substitute variables if provided
        if variables:
            for var_name, var_value in variables.items():
                content = content.replace(f"{{{{{var_name}}}}}", var_value)

        return content

    def list_prompts(self, category: Optional[str] = None) -> List[SystemPrompt]:
        """
        List available prompts, optionally filtered by category.

        Args:
            category: Filter by category (optional)

        Returns:
            List of SystemPrompt objects
        """
        prompts = list(self._prompts.values())

        if category:
            prompts = [p for p in prompts if p.category == category]

        return sorted(prompts, key=lambda p: (p.category, p.name))

    def search_prompts(self, query: str) -> List[SystemPrompt]:
        """
        Search prompts by name, description, or tags.

        Args:
            query: Search query

        Returns:
            List of matching SystemPrompt objects
        """
        query_lower = query.lower()
        matches = []

        for prompt in self._prompts.values():
            if (query_lower in prompt.name.lower() or
                query_lower in prompt.description.lower() or
                any(query_lower in tag.lower() for tag in prompt.tags)):
                matches.append(prompt)

        return matches

    def get_prompt_by_category(self, category: str) -> Dict[str, SystemPrompt]:
        """Get all prompts from a specific category"""
        return {
            name: prompt for name, prompt in self._prompts.items()
            if prompt.category == category
        }

# Predefined prompt constants for easy access
class PythonPrompts:
    """Predefined system prompts for Python SDK"""

    BASE_PERSONALITY = "shared/base-personality"
    CODE_ANALYSIS = "shared/code-analysis"
    AGENT_WORKFLOW = "python-sdk/agent-workflow"

    @staticmethod
    def load_all(manager: SystemPromptManager) -> Dict[str, str]:
        """Load all predefined prompts"""
        return {
            "base": manager.get_prompt(PythonPrompts.BASE_PERSONALITY),
            "analysis": manager.get_prompt(PythonPrompts.CODE_ANALYSIS),
            "workflow": manager.get_prompt(PythonPrompts.AGENT_WORKFLOW),
        }

# Utility function for quick prompt loading
def load_prompt(prompt_name: str, variables: Optional[Dict[str, str]] = None) -> str:
    """
    Quick function to load a prompt by name.

    Args:
        prompt_name: Name of the prompt to load
        variables: Optional variable substitutions

    Returns:
        The prompt content
    """
    manager = SystemPromptManager()
    return manager.get_prompt(prompt_name, variables)

# Example usage
if __name__ == "__main__":
    # Initialize the manager
    manager = SystemPromptManager()

    # List all available prompts
    print("Available prompts:")
    for prompt in manager.list_prompts():
        print(f"  - {prompt.name} ({prompt.category}): {prompt.description}")

    # Load a specific prompt
    try:
        base_prompt = manager.get_prompt("base-personality")
        print(f"\nBase prompt loaded: {len(base_prompt)} characters")
    except ValueError as e:
        print(f"Error: {e}")