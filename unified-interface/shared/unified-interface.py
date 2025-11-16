#!/usr/bin/env python3
"""
Unified Claude Interface - Python Implementation

Provides a consistent interface across all Claude SDK implementations while
preserving their unique capabilities.
"""

import os
import json
import asyncio
import logging
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Dict, List, Optional, Any, Union, AsyncIterable
from dataclasses import dataclass
from enum import Enum

# Import SDK-specific adapters
try:
    from .python_adapter import PythonAdapter
except ImportError:
    PythonAdapter = None

try:
    from .cli_adapter import CliAdapter
except ImportError:
    CliAdapter = None

class SDKType(Enum):
    CLAUDE_CODE_CLI = "claude-code-cli"
    PYTHON_SDK = "python-sdk"
    TYPESCRIPT_SDK = "typescript-sdk"

@dataclass
class ChatMessage:
    role: str
    content: str
    timestamp: Optional[str] = None

@dataclass
class AnalysisResult:
    file_path: str
    analysis: str
    suggestions: List[str]
    issues: List[str]
    confidence: float

@dataclass
class ProjectTemplate:
    name: str
    type: str
    sdk: SDKType
    description: str
    files: Dict[str, str]
    dependencies: List[str]

class ClaudeInterface(ABC):
    """Abstract base class for Claude SDK adapters"""

    @abstractmethod
    async def chat(self, message: str, system_prompt: Optional[str] = None) -> str:
        """Send a chat message to Claude"""
        pass

    @abstractmethod
    async def stream_chat(self, message: str, system_prompt: Optional[str] = None) -> AsyncIterable[str]:
        """Stream a chat response"""
        pass

    @abstractmethod
    async def analyze_file(self, file_path: str) -> AnalysisResult:
        """Analyze a file and return structured results"""
        pass

    @abstractmethod
    async def create_project(self, template: ProjectTemplate, project_name: str) -> bool:
        """Create a new project from template"""
        pass

    @abstractmethod
    def get_configuration(self) -> Dict[str, Any]:
        """Get current configuration"""
        pass

    @abstractmethod
    def set_configuration(self, config: Dict[str, Any]) -> bool:
        """Set configuration"""
        pass

class UnifiedClaudeInterface:
    """Main unified interface that manages SDK adapters"""

    def __init__(self, config_file: Optional[str] = None):
        """
        Initialize the unified interface.

        Args:
            config_file: Path to configuration file
        """
        self.config_file = config_file or self._get_default_config_file()
        self.config = self._load_config()
        self.logger = self._setup_logging()
        self.adapters: Dict[SDKType, ClaudeInterface] = {}
        self.current_adapter: Optional[ClaudeInterface] = None

        # Initialize available adapters
        self._initialize_adapters()

    def _get_default_config_file(self) -> str:
        """Get default configuration file path"""
        return str(Path.home() / ".claude-universal" / "config.json")

    def _load_config(self) -> Dict[str, Any]:
        """Load configuration from file"""
        default_config = {
            "defaultSdk": "claude-code-cli",
            "apiToken": os.getenv("ANTHROPIC_API_KEY", ""),
            "model": "claude-3-5-sonnet-20241022",
            "systemPrompts": {
                "base": "professional",
                "codeAnalysis": "detailed"
            },
            "permissions": {
                "autoEscalate": False,
                "auditLogging": True
            },
            "features": {
                "streaming": True,
                "contextManagement": True,
                "customCommands": True
            }
        }

        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    config = json.load(f)
                    # Merge with defaults
                    return {**default_config, **config}
            except Exception as e:
                logging.warning(f"Failed to load config file: {e}")

        return default_config

    def _save_config(self) -> bool:
        """Save configuration to file"""
        try:
            os.makedirs(os.path.dirname(self.config_file), exist_ok=True)
            with open(self.config_file, 'w') as f:
                json.dump(self.config, f, indent=2)
            return True
        except Exception as e:
            self.logger.error(f"Failed to save config: {e}")
            return False

    def _setup_logging(self) -> logging.Logger:
        """Set up logging"""
        logger = logging.getLogger("claude-unified")
        logger.setLevel(logging.INFO)

        if not logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
            )
            handler.setFormatter(formatter)
            logger.addHandler(handler)

        return logger

    def _initialize_adapters(self):
        """Initialize available SDK adapters"""
        # Initialize Python adapter if available
        if PythonAdapter:
            try:
                self.adapters[SDKType.PYTHON_SDK] = PythonAdapter(
                    api_key=self.config["apiToken"],
                    system_prompts_dir=self._get_system_prompts_dir()
                )
                self.logger.info("Python SDK adapter initialized")
            except Exception as e:
                self.logger.warning(f"Failed to initialize Python adapter: {e}")

        # Initialize CLI adapter if available
        if CliAdapter:
            try:
                self.adapters[SDKType.CLAUDE_CODE_CLI] = CliAdapter(
                    system_prompts_dir=self._get_system_prompts_dir()
                )
                self.logger.info("Claude Code CLI adapter initialized")
            except Exception as e:
                self.logger.warning(f"Failed to initialize CLI adapter: {e}")

        # Set default adapter
        default_sdk = SDKType(self.config["defaultSdk"])
        if default_sdk in self.adapters:
            self.current_adapter = self.adapters[default_sdk]
        elif self.adapters:
            self.current_adapter = list(self.adapters.values())[0]
            self.logger.warning(f"Default SDK {default_sdk} not available, using {self.current_adapter}")
        else:
            raise RuntimeError("No Claude SDK adapters available")

    def _get_system_prompts_dir(self) -> str:
        """Get system prompts directory"""
        # Look in common locations
        possible_dirs = [
            Path(__file__).parent.parent.parent / "sdk-system-prompts",
            Path.home() / ".claude-universal" / "system-prompts",
            Path.cwd() / "system-prompts"
        ]

        for dir_path in possible_dirs:
            if dir_path.exists():
                return str(dir_path)

        # Return default path even if it doesn't exist
        return str(Path.home() / ".claude-universal" / "system-prompts")

    def switch_sdk(self, sdk_type: SDKType) -> bool:
        """
        Switch to a different SDK.

        Args:
            sdk_type: The SDK type to switch to

        Returns:
            True if switch was successful
        """
        if sdk_type not in self.adapters:
            self.logger.error(f"SDK {sdk_type} not available")
            return False

        self.current_adapter = self.adapters[sdk_type]
        self.config["defaultSdk"] = sdk_type.value
        self._save_config()

        self.logger.info(f"Switched to {sdk_type.value}")
        return True

    def get_available_sdks(self) -> List[SDKType]:
        """Get list of available SDKs"""
        return list(self.adapters.keys())

    def get_current_sdk(self) -> Optional[SDKType]:
        """Get current SDK type"""
        if not self.current_adapter:
            return None

        for sdk_type, adapter in self.adapters.items():
            if adapter == self.current_adapter:
                return sdk_type
        return None

    # Unified interface methods
    async def chat(self, message: str, system_prompt: Optional[str] = None) -> str:
        """Send a chat message using the current SDK"""
        if not self.current_adapter:
            raise RuntimeError("No SDK adapter available")

        return await self.current_adapter.chat(message, system_prompt)

    async def stream_chat(self, message: str, system_prompt: Optional[str] = None) -> AsyncIterable[str]:
        """Stream a chat response using the current SDK"""
        if not self.current_adapter:
            raise RuntimeError("No SDK adapter available")

        async for chunk in self.current_adapter.stream_chat(message, system_prompt):
            yield chunk

    async def analyze_file(self, file_path: str) -> AnalysisResult:
        """Analyze a file using the current SDK"""
        if not self.current_adapter:
            raise RuntimeError("No SDK adapter available")

        return await self.current_adapter.analyze_file(file_path)

    async def create_project(self, template_name: str, project_name: str,
                           sdk_type: Optional[SDKType] = None) -> bool:
        """Create a new project using specified or current SDK"""
        adapter = self.current_adapter
        if sdk_type:
            if sdk_type not in self.adapters:
                raise ValueError(f"SDK {sdk_type} not available")
            adapter = self.adapters[sdk_type]

        if not adapter:
            raise RuntimeError("No SDK adapter available")

        # Load template
        template = self._load_template(template_name)
        if not template:
            raise ValueError(f"Template {template_name} not found")

        return await adapter.create_project(template, project_name)

    def _load_template(self, template_name: str) -> Optional[ProjectTemplate]:
        """Load a project template"""
        template_dir = Path(__file__).parent.parent / "templates"
        template_file = template_dir / f"{template_name}.json"

        if not template_file.exists():
            return None

        try:
            with open(template_file, 'r') as f:
                data = json.load(f)
                return ProjectTemplate(**data)
        except Exception as e:
            self.logger.error(f"Failed to load template {template_name}: {e}")
            return None

    def get_configuration(self) -> Dict[str, Any]:
        """Get current configuration"""
        config = self.config.copy()
        config["currentSdk"] = self.get_current_sdk()
        config["availableSdks"] = [sdk.value for sdk in self.get_available_sdks()]
        return config

    def set_configuration(self, **kwargs) -> bool:
        """Set configuration values"""
        for key, value in kwargs.items():
            if key in self.config:
                self.config[key] = value
            else:
                self.logger.warning(f"Unknown configuration key: {key}")

        return self._save_config()

    async def execute_command(self, command: str, sdk_type: Optional[SDKType] = None) -> str:
        """Execute a command using specified or current SDK"""
        adapter = self.current_adapter
        if sdk_type and sdk_type in self.adapters:
            adapter = self.adapters[sdk_type]

        if not adapter:
            raise RuntimeError("No SDK adapter available")

        # This would be implemented by each adapter
        if hasattr(adapter, 'execute_command'):
            return await adapter.execute_command(command)
        else:
            raise NotImplementedError("Command execution not supported by current SDK")

    def list_system_prompts(self) -> List[str]:
        """List available system prompts"""
        prompts_dir = Path(self._get_system_prompts_dir())
        if not prompts_dir.exists():
            return []

        prompts = []
        for prompt_file in prompts_dir.rglob("*.md"):
            relative_path = prompt_file.relative_to(prompts_dir)
            prompts.append(str(relative_path).replace('/', '.'))

        return sorted(prompts)

    def get_system_prompt(self, prompt_name: str) -> Optional[str]:
        """Get a system prompt by name"""
        prompts_dir = Path(self._get_system_prompts_dir())
        prompt_file = prompts_dir / f"{prompt_name.replace('.', '/')}.md"

        if not prompt_file.exists():
            return None

        try:
            with open(prompt_file, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            self.logger.error(f"Failed to read prompt {prompt_name}: {e}")
            return None

# Convenience functions for easy usage
async def chat(message: str, sdk: Optional[str] = None, system_prompt: Optional[str] = None) -> str:
    """Quick chat function"""
    interface = UnifiedClaudeInterface()
    if sdk:
        interface.switch_sdk(SDKType(sdk))
    return await interface.chat(message, system_prompt)

async def analyze_file(file_path: str, sdk: Optional[str] = None) -> AnalysisResult:
    """Quick file analysis function"""
    interface = UnifiedClaudeInterface()
    if sdk:
        interface.switch_sdk(SDKType(sdk))
    return await interface.analyze_file(file_path)

# CLI interface
def main():
    """Command-line interface for the unified Claude interface"""
    import argparse
    import asyncio

    parser = argparse.ArgumentParser(description="Unified Claude Interface")
    parser.add_argument("command", choices=["chat", "analyze", "create", "status", "config"])
    parser.add_argument("--sdk", choices=[sdk.value for sdk in SDKType])
    parser.add_argument("--message", help="Message for chat command")
    parser.add_argument("--file", help="File path for analyze command")
    parser.add_argument("--template", help="Template name for create command")
    parser.add_argument("--project", help="Project name for create command")

    args = parser.parse_args()

    async def run_command():
        interface = UnifiedClaudeInterface()

        if args.sdk:
            interface.switch_sdk(SDKType(args.sdk))

        if args.command == "chat":
            if not args.message:
                message = input("Enter your message: ")
            else:
                message = args.message

            response = await interface.chat(message)
            print(response)

        elif args.command == "analyze":
            if not args.file:
                print("Error: --file required for analyze command")
                return

            result = await interface.analyze_file(args.file)
            print(f"Analysis for {result.file_path}:")
            print(result.analysis)
            if result.suggestions:
                print("\nSuggestions:")
                for suggestion in result.suggestions:
                    print(f"  - {suggestion}")

        elif args.command == "status":
            config = interface.get_configuration()
            print("Claude Unified Interface Status:")
            print(f"  Current SDK: {config['currentSdk']}")
            print(f"  Available SDKs: {', '.join(config['availableSdks'])}")
            print(f"  Model: {config['model']}")
            print(f"  Streaming: {config['features']['streaming']}")

        elif args.command == "config":
            print("Current configuration:")
            print(json.dumps(interface.get_configuration(), indent=2))

    asyncio.run(run_command())

if __name__ == "__main__":
    main()