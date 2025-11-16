/**
 * TypeScript System Prompts Manager for Claude Agent SDK
 *
 * Provides utilities for loading, managing, and switching between different
 * system prompts based on context and user requirements.
 */

import * as fs from 'fs';
import * as path from 'path';

export interface SystemPrompt {
  name: string;
  content: string;
  category: string;
  description: string;
  variables: string[];
  tags: string[];
}

export class SystemPromptManager {
  private prompts: Map<string, SystemPrompt> = new Map();
  private promptsDir: string;

  constructor(promptsDir?: string) {
    // Default to the package's prompts directory
    this.promptsDir = promptsDir || path.join(__dirname, '..', 'sdk-system-prompts');
    this.loadPrompts();
  }

  /**
   * Load all system prompts from markdown files
   */
  private loadPrompts(): void {
    if (!fs.existsSync(this.promptsDir)) {
      throw new Error(`Prompts directory not found: ${this.promptsDir}`);
    }

    // Load prompts from different categories
    const categories = ['shared', 'claude-code-cli', 'python-sdk', 'typescript-sdk'];

    for (const category of categories) {
      const categoryDir = path.join(this.promptsDir, category);
      if (fs.existsSync(categoryDir)) {
        this.loadCategoryPrompts(categoryDir, category);
      }
    }
  }

  /**
   * Load prompts from a specific category directory
   */
  private loadCategoryPrompts(categoryDir: string, category: string): void {
    const files = fs.readdirSync(categoryDir);

    for (const file of files) {
      if (file.endsWith('.md')) {
        const filePath = path.join(categoryDir, file);
        const prompt = this.parsePromptFile(filePath, category);
        if (prompt) {
          this.prompts.set(prompt.name, prompt);
        }
      }
    }
  }

  /**
   * Parse a markdown file into a SystemPrompt object
   */
  private parsePromptFile(filePath: string, category: string): SystemPrompt | null {
    try {
      const content = fs.readFileSync(filePath, 'utf-8');
      const name = path.basename(filePath, '.md');
      const description = this.extractDescription(content);
      const variables = this.extractVariables(content);
      const tags = this.extractTags(content);

      return {
        name,
        content,
        category,
        description,
        variables,
        tags
      };
    } catch (error) {
      console.error(`Error parsing prompt file ${filePath}:`, error);
      return null;
    }
  }

  /**
   * Extract description from markdown content
   */
  private extractDescription(content: string): string {
    const lines = content.split('\n');
    for (const line of lines) {
      if (line.trim().startsWith('# ')) {
        return line.trim().substring(2).trim();
      }
    }
    return 'No description available';
  }

  /**
   * Extract variable placeholders from content
   */
  private extractVariables(content: string): string[] {
    const variableRegex = /\{\{(\w+)\}\}/g;
    const matches = content.match(variableRegex);
    if (!matches) return [];

    const variables = matches.map(match => match.slice(2, -2));
    return [...new Set(variables)];
  }

  /**
   * Extract tags from content
   */
  private extractTags(content: string): string[] {
    const lines = content.split('\n');
    for (const line of lines) {
      if (line.trim().startsWith('Tags:')) {
        return line.replace('Tags:', '').split(',').map(tag => tag.trim());
      }
    }
    return [];
  }

  /**
   * Get a system prompt by name with variable substitution
   */
  getPrompt(name: string, variables?: Record<string, string>): string {
    const prompt = this.prompts.get(name);
    if (!prompt) {
      throw new Error(`Prompt '${name}' not found`);
    }

    let content = prompt.content;

    // Substitute variables if provided
    if (variables) {
      for (const [varName, varValue] of Object.entries(variables)) {
        content = content.replace(new RegExp(`\\{\\{${varName}\\}\\}`, 'g'), varValue);
      }
    }

    return content;
  }

  /**
   * List available prompts, optionally filtered by category
   */
  listPrompts(category?: string): SystemPrompt[] {
    let prompts = Array.from(this.prompts.values());

    if (category) {
      prompts = prompts.filter(p => p.category === category);
    }

    return prompts.sort((a, b) => {
      const categoryCompare = a.category.localeCompare(b.category);
      if (categoryCompare !== 0) return categoryCompare;
      return a.name.localeCompare(b.name);
    });
  }

  /**
   * Search prompts by name, description, or tags
   */
  searchPrompts(query: string): SystemPrompt[] {
    const queryLower = query.toLowerCase();
    return Array.from(this.prompts.values()).filter(prompt =>
      prompt.name.toLowerCase().includes(queryLower) ||
      prompt.description.toLowerCase().includes(queryLower) ||
      prompt.tags.some(tag => tag.toLowerCase().includes(queryLower))
    );
  }

  /**
   * Get all prompts from a specific category
   */
  getPromptsByCategory(category: string): Record<string, SystemPrompt> {
    const result: Record<string, SystemPrompt> = {};
    for (const [name, prompt] of this.prompts) {
      if (prompt.category === category) {
        result[name] = prompt;
      }
    }
    return result;
  }
}

/**
 * Predefined system prompts for TypeScript SDK
 */
export class TypeScriptPrompts {
  static readonly BASE_PERSONALITY = 'shared/base-personality';
  static readonly CODE_ANALYSIS = 'shared/code-analysis';
  static readonly NODEJS_WORKFLOW = 'typescript-sdk/nodejs-workflow';

  /**
   * Load all predefined prompts
   */
  static loadAll(manager: SystemPromptManager): Record<string, string> {
    return {
      base: manager.getPrompt(TypeScriptPrompts.BASE_PERSONALITY),
      analysis: manager.getPrompt(TypeScriptPrompts.CODE_ANALYSIS),
      nodejs: manager.getPrompt(TypeScriptPrompts.NODEJS_WORKFLOW),
    };
  }
}

/**
 * Utility function for quick prompt loading
 */
export function loadPrompt(promptName: string, variables?: Record<string, string>): string {
  const manager = new SystemPromptManager();
  return manager.getPrompt(promptName, variables);
}

/**
 * Enhanced Claude Agent with System Prompt Management
 */
export class EnhancedClaudeAgent {
  private promptManager: SystemPromptManager;
  private currentPrompt?: string;

  constructor(
    private anthropic: any, // Anthropic SDK instance
    private apiKey: string,
    promptsDir?: string
  ) {
    this.promptManager = new SystemPromptManager(promptsDir);
  }

  /**
   * Set the active system prompt
   */
  setSystemPrompt(promptName: string, variables?: Record<string, string>): void {
    this.currentPrompt = this.promptManager.getPrompt(promptName, variables);
  }

  /**
   * Get available prompts
   */
  getAvailablePrompts(): SystemPrompt[] {
    return this.promptManager.listPrompts();
  }

  /**
   * Search for prompts
   */
  searchPrompts(query: string): SystemPrompt[] {
    return this.promptManager.searchPrompts(query);
  }

  /**
   * Process a request with the current system prompt
   */
  async processRequest(message: string, overridePrompt?: string): Promise<string> {
    const systemPrompt = overridePrompt || this.currentPrompt || TypeScriptPrompts.BASE_PERSONALITY;

    try {
      const response = await this.anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 1000,
        system: systemPrompt,
        messages: [
          { role: 'user', content: message }
        ]
      });

      return response.content[0].type === 'text'
        ? response.content[0].text
        : 'No text response received.';
    } catch (error) {
      throw new Error(`Claude API error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }

  /**
   * Stream a response for long-form content
   */
  async *streamResponse(message: string, overridePrompt?: string): AsyncGenerator<string> {
    const systemPrompt = overridePrompt || this.currentPrompt || TypeScriptPrompts.BASE_PERSONALITY;

    try {
      const stream = await this.anthropic.messages.create({
        model: 'claude-3-5-sonnet-20241022',
        max_tokens: 4000,
        system: systemPrompt,
        messages: [
          { role: 'user', content: message }
        ],
        stream: true
      });

      for await (const chunk of stream) {
        if (chunk.type === 'content_block_delta' && chunk.delta.type === 'text_delta') {
          yield chunk.delta.text;
        }
      }
    } catch (error) {
      throw new Error(`Claude API streaming error: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }
}

// Example usage
if (require.main === module) {
  // Initialize the manager
  const manager = new SystemPromptManager();

  // List all available prompts
  console.log('Available prompts:');
  for (const prompt of manager.listPrompts()) {
    console.log(`  - ${prompt.name} (${prompt.category}): ${prompt.description}`);
  }

  // Load a specific prompt
  try {
    const basePrompt = manager.getPrompt('base-personality');
    console.log(`\nBase prompt loaded: ${basePrompt.length} characters`);
  } catch (error) {
    console.error(`Error: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}