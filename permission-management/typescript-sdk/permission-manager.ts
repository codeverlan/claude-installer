/**
 * TypeScript SDK Permission Manager
 *
 * Handles permission escalation and privileged operations for Claude TypeScript Agent.
 * Provides safe, auditable, and user-controlled privilege management.
 */

import * as fs from 'fs';
import * as path from 'path';
import { spawn, ChildProcess } from 'child_process';
import { promisify } from 'util';

// Types and enums
export enum PermissionLevel {
  BASIC = 'basic',
  ELEVATED = 'elevated',
  ADMINISTRATIVE = 'administrative'
}

export enum OperationResult {
  SUCCESS = 'success',
  PERMISSION_DENIED = 'permission_denied',
  ESCALATION_FAILED = 'escalation_failed',
  OPERATION_FAILED = 'operation_failed',
  USER_CANCELLED = 'user_cancelled'
}

export interface PrivilegedOperation {
  command: string[];
  description: string;
  permissionLevel: PermissionLevel;
  requiresUserApproval?: boolean;
  timeout?: number;
  workingDirectory?: string;
  environment?: Record<string, string>;
}

export interface AuditEntry {
  timestamp: Date;
  operation: string;
  permissionLevel: string;
  result: string;
  user: string;
  details: Record<string, any>;
}

export interface AuditSummary {
  totalEntries: number;
  successCount: number;
  failureCount: number;
  elevatedOperations: number;
  recentOperations: AuditEntry[];
}

// Utility functions
const execAsync = promisify(require('child_process').exec);

export class PermissionManager {
  private logFile: string;
  private currentUser: string;
  private isPrivileged: boolean;
  private sessionOperations: AuditEntry[] = [];

  constructor(logFile?: string) {
    this.logFile = logFile || path.join(this.getHomeDir(), '.claude-typescript', 'audit.log');
    this.currentUser = process.env.USER || process.env.USERNAME || 'unknown';
    this.isPrivileged = this.checkPrivilegedStatus();
    this.ensureLogDirectory();
  }

  private getHomeDir(): string {
    return process.env.HOME || process.env.USERPROFILE || '/tmp';
  }

  private checkPrivilegedStatus(): boolean {
    try {
      if (process.platform === 'win32') {
        // Windows admin check would go here
        return false; // Simplified for cross-platform compatibility
      } else {
        // Unix-like systems: check if running as root
        return process.getuid && process.getuid() === 0;
      }
    } catch {
      return false;
    }
  }

  private ensureLogDirectory(): void {
    const logDir = path.dirname(this.logFile);
    if (!fs.existsSync(logDir)) {
      fs.mkdirSync(logDir, { recursive: true });
    }
  }

  /**
   * Analyze a command to determine required permission level
   */
  analyzeCommandPermissions(command: string[]): PermissionLevel {
    if (!command || command.length === 0) {
      return PermissionLevel.BASIC;
    }

    const elevatedCommands = new Set([
      'sudo', 'doas', 'su', 'apt', 'apt-get', 'yum', 'dnf', 'pacman',
      'systemctl', 'service', 'mount', 'umount', 'fdisk', 'mkfs',
      'useradd', 'usermod', 'userdel', 'chmod', 'chown', 'visudo',
      'npm', 'yarn', 'pnpm'  // Node.js package managers
    ]);

    const adminCommands = new Set([
      'crontab', 'iptables', 'ufw', 'firewall-cmd', 'sysctl',
      'hostnamectl', 'timedatectl', 'localectl'
    ]);

    const firstCmd = command[0].toLowerCase();

    if (adminCommands.has(firstCmd)) {
      return PermissionLevel.ADMINISTRATIVE;
    } else if (elevatedCommands.has(firstCmd)) {
      return PermissionLevel.ELEVATED;
    }

    // Check for privileged file paths
    const privilegedPaths = ['/etc', '/usr/local', '/opt', '/var', '/root'];
    const hasPrivilegedPath = command.some(arg =>
      privilegedPaths.some(privPath => arg.startsWith(privPath))
    );

    return hasPrivilegedPath ? PermissionLevel.ELEVATED : PermissionLevel.BASIC;
  }

  /**
   * Check if an operation requires elevated permissions
   */
  checkPermissionRequired(operation: PrivilegedOperation): boolean {
    if (operation.permissionLevel === PermissionLevel.BASIC) {
      return false;
    }

    if (this.isPrivileged) {
      return false;
    }

    return true;
  }

  /**
   * Request user permission for a privileged operation
   */
  async requestPermission(operation: PrivilegedOperation): Promise<boolean> {
    if (!operation.requiresUserApproval) {
      return true;
    }

    console.log('\n🔒 Privileged Operation Required');
    console.log(`Description: ${operation.description}`);
    console.log(`Command: ${operation.command.join(' ')}`);
    console.log(`Permission Level: ${operation.permissionLevel}`);

    if (operation.permissionLevel === PermissionLevel.ADMINISTRATIVE) {
      console.log('⚠️  This operation makes system-level changes');
    } else if (operation.permissionLevel === PermissionLevel.ELEVATED) {
      console.log('⚠️  This operation requires elevated privileges');
    }

    // In a real implementation, you would use a proper CLI prompt library
    // For now, we'll use a simple approach
    return this.promptUser('Do you want to proceed? (y/N): ');
  }

  private async promptUser(question: string): Promise<boolean> {
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout
    });

    return new Promise((resolve) => {
      readline.question(question, (answer: string) => {
        readline.close();
        const response = answer.trim().toLowerCase();
        resolve(response === 'y' || response === 'yes');
      });
    });
  }

  /**
   * Execute an operation with automatic privilege escalation
   */
  async executeWithEscalation(operation: PrivilegedOperation): Promise<[OperationResult, string]> {
    const startTime = new Date();

    // Log the operation attempt
    console.log(`Attempting privileged operation: ${operation.description}`);
    console.log(`Command: ${operation.command.join(' ')}`);

    // Check if escalation is needed
    const needsEscalation = this.checkPermissionRequired(operation);

    // Request user permission if needed
    if (needsEscalation && !await this.requestPermission(operation)) {
      const result = OperationResult.USER_CANCELLED;
      const message = 'User cancelled the operation';
      this.logOperation(operation, result, message, startTime);
      return [result, message];
    }

    // Prepare the command
    let command = [...operation.command];
    if (needsEscalation && !this.isPrivileged && process.platform !== 'win32') {
      // Prefix with sudo for elevation on Unix systems
      command = ['sudo', ...command];
    }

    // Set up environment
    const env = { ...process.env };
    if (operation.environment) {
      Object.assign(env, operation.environment);
    }

    try {
      // Execute the command
      const { stdout, stderr } = await this.executeCommand(
        command,
        operation.timeout || 300,
        operation.workingDirectory,
        env
      );

      const result = OperationResult.SUCCESS;
      const message = stdout || 'Operation completed successfully';
      this.logOperation(operation, result, message, startTime);
      return [result, message];

    } catch (error: any) {
      let result: OperationResult;
      let message: string;

      if (error.code === 'EACCES' || error.code === 'EPERM') {
        result = OperationResult.PERMISSION_DENIED;
        message = 'Permission denied - unable to execute command';
      } else if (error.signal === 'SIGTERM' || error.message.includes('timeout')) {
        result = OperationResult.OPERATION_FAILED;
        message = `Operation timed out after ${operation.timeout || 300} seconds`;
      } else {
        result = OperationResult.OPERATION_FAILED;
        message = `Command failed: ${error.message}`;
      }

      this.logOperation(operation, result, message, startTime);
      return [result, message];
    }
  }

  private async executeCommand(
    command: string[],
    timeout: number,
    cwd?: string,
    env?: Record<string, string>
  ): Promise<{ stdout: string; stderr: string }> {
    return new Promise((resolve, reject) => {
      const child = spawn(command[0], command.slice(1), {
        cwd,
        env,
        stdio: ['pipe', 'pipe', 'pipe']
      });

      let stdout = '';
      let stderr = '';

      child.stdout?.on('data', (data) => {
        stdout += data.toString();
      });

      child.stderr?.on('data', (data) => {
        stderr += data.toString();
      });

      const timeoutId = setTimeout(() => {
        child.kill('SIGTERM');
        reject(new Error(`Command timed out after ${timeout} seconds`));
      }, timeout * 1000);

      child.on('close', (code) => {
        clearTimeout(timeoutId);
        if (code === 0) {
          resolve({ stdout, stderr });
        } else {
          reject(new Error(`Command exited with code ${code}: ${stderr}`));
        }
      });

      child.on('error', (error) => {
        clearTimeout(timeoutId);
        reject(error);
      });
    });
  }

  /**
   * Log an operation to the audit trail
   */
  private logOperation(
    operation: PrivilegedOperation,
    result: OperationResult,
    message: string,
    startTime: Date
  ): void {
    const auditEntry: AuditEntry = {
      timestamp: startTime,
      operation: operation.command.join(' '),
      permissionLevel: operation.permissionLevel,
      result: result,
      user: this.currentUser,
      details: {
        description: operation.description,
        durationSeconds: (new Date().getTime() - startTime.getTime()) / 1000,
        message: message,
        workingDirectory: operation.workingDirectory
      }
    };

    // Add to session history
    this.sessionOperations.push(auditEntry);

    // Write to log file
    const logEntry = {
      timestamp: auditEntry.timestamp.toISOString(),
      operation: auditEntry.operation,
      permissionLevel: auditEntry.permissionLevel,
      result: auditEntry.result,
      user: auditEntry.user,
      details: auditEntry.details
    };

    try {
      fs.appendFileSync(this.logFile, JSON.stringify(logEntry) + '\n');
    } catch (error) {
      console.error(`Failed to write audit log: ${error}`);
    }
  }

  /**
   * Install an npm package with appropriate permissions
   */
  async installNpmPackage(packageName: string, global = false): Promise<[OperationResult, string]> {
    const command = global ? ['npm', 'install', '-g', packageName] : ['npm', 'install', packageName];
    const description = `Install npm package '${packageName}' ${global ? 'globally' : 'locally'}`;

    const operation: PrivilegedOperation = {
      command,
      description,
      permissionLevel: global ? PermissionLevel.ELEVATED : PermissionLevel.BASIC,
      timeout: 600 // 10 minutes for package installation
    };

    return this.executeWithEscalation(operation);
  }

  /**
   * Manage file permissions
   */
  async manageFilePermissions(
    filePath: string,
    permissions: string,
    owner?: string
  ): Promise<[OperationResult, string]> {
    if (process.platform === 'win32') {
      // Windows permission management would go here
      return [OperationResult.OPERATION_FAILED, 'Permission management not supported on Windows'];
    }

    const commands: string[][] = [];

    // Change permissions
    if (permissions) {
      commands.push(['chmod', permissions, filePath]);
    }

    // Change ownership if specified
    if (owner) {
      commands.push(['chown', owner, filePath]);
    }

    for (const cmd of commands) {
      const operation: PrivilegedOperation = {
        command: cmd,
        description: `Change permissions/ownership for ${filePath}`,
        permissionLevel: PermissionLevel.ELEVATED
      };

      const [result, message] = await this.executeWithEscalation(operation);
      if (result !== OperationResult.SUCCESS) {
        return [result, message];
      }
    }

    return [OperationResult.SUCCESS, 'Permissions updated successfully'];
  }

  /**
   * Execute a TypeScript/JavaScript file
   */
  async executeScript(
    scriptPath: string,
    arguments: string[] = [],
    interpreter = 'node'
  ): Promise<[OperationResult, string]> {
    const command = [interpreter, scriptPath, ...arguments];

    // Check script permissions first
    if (!fs.existsSync(scriptPath)) {
      return [OperationResult.OPERATION_FAILED, `Script file not found: ${scriptPath}`];
    }

    if (!fs.accessSync(scriptPath, fs.constants.R_OK)) {
      return [OperationResult.PERMISSION_DENIED, `Cannot read script file: ${scriptPath}`];
    }

    const operation: PrivilegedOperation = {
      command,
      description: `Execute script: ${scriptPath}`,
      permissionLevel: this.analyzeCommandPermissions(command),
      timeout: 300
    };

    return this.executeWithEscalation(operation);
  }

  /**
   * Get session history
   */
  getSessionHistory(): AuditEntry[] {
    return [...this.sessionOperations];
  }

  /**
   * Get audit summary
   */
  async getAuditSummary(limit = 50): Promise<AuditSummary | { error: string }> {
    try {
      if (!fs.existsSync(this.logFile)) {
        return { totalEntries: 0, successCount: 0, failureCount: 0, elevatedOperations: 0, recentOperations: [] };
      }

      const content = fs.readFileSync(this.logFile, 'utf-8');
      const lines = content.trim().split('\n').filter(line => line.length > 0);

      const entries: AuditEntry[] = [];
      for (const line of lines) {
        try {
          const entry = JSON.parse(line);
          entries.push({
            ...entry,
            timestamp: new Date(entry.timestamp)
          });
        } catch {
          continue;
        }
      }

      // Take the most recent entries
      const recentEntries = entries.length > limit ? entries.slice(-limit) : entries;

      // Calculate statistics
      const summary: AuditSummary = {
        totalEntries: recentEntries.length,
        successCount: recentEntries.filter(e => e.result === 'success').length,
        failureCount: recentEntries.filter(e => e.result !== 'success').length,
        elevatedOperations: recentEntries.filter(e =>
          e.permissionLevel === 'elevated' || e.permissionLevel === 'administrative'
        ).length,
        recentOperations: recentEntries.slice(-10) // Last 10 operations
      };

      return summary;

    } catch (error: any) {
      return { error: `Failed to read audit log: ${error.message}` };
    }
  }
}

/**
 * High-level privilege operations for TypeScript SDK
 */
export class TypeScriptPrivileges {
  private manager: PermissionManager;

  constructor(logFile?: string) {
    this.manager = new PermissionManager(logFile);
  }

  /**
   * Install npm package globally
   */
  async installGlobalPackage(packageName: string): Promise<boolean> {
    const [result, message] = await this.manager.installNpmPackage(packageName, true);
    console.log(`Package installation: ${message}`);
    return result === OperationResult.SUCCESS;
  }

  /**
   * Setup development environment from package.json
   */
  async setupDevelopmentEnvironment(projectPath: string): Promise<boolean> {
    const packageJsonPath = path.join(projectPath, 'package.json');
    if (!fs.existsSync(packageJsonPath)) {
      console.log(`package.json not found: ${packageJsonPath}`);
      return false;
    }

    const operation: PrivilegedOperation = {
      command: ['npm', 'install'],
      description: 'Install project dependencies',
      permissionLevel: PermissionLevel.BASIC,
      timeout: 600,
      workingDirectory: projectPath
    };

    const [result, message] = await this.manager.executeWithEscalation(operation);
    console.log(`Environment setup: ${message}`);
    return result === OperationResult.SUCCESS;
  }

  /**
   * Create a systemd service (Linux only)
   */
  async createSystemService(serviceName: string, scriptPath: string): Promise<boolean> {
    if (process.platform === 'win32') {
      console.log('Service creation not supported on Windows');
      return false;
    }

    const serviceContent = `[Unit]
Description=Claude TypeScript Agent Service
After=network.target

[Service]
Type=simple
User=${process.env.USER || 'claude'}
WorkingDirectory=${path.dirname(scriptPath)}
ExecStart=/usr/bin/node ${scriptPath}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
`;

    // Write service file to temp location first
    const tempFile = path.join(require('os').tmpdir(), `${serviceName}.service`);
    fs.writeFileSync(tempFile, serviceContent);

    const serviceFile = `/etc/systemd/system/${serviceName}.service`;

    // Move service file to system location
    const operation: PrivilegedOperation = {
      command: ['cp', tempFile, serviceFile],
      description: `Create systemd service: ${serviceName}`,
      permissionLevel: PermissionLevel.ADMINISTRATIVE
    };

    const [result, message] = await this.manager.executeWithEscalation(operation);

    // Clean up temp file
    fs.unlinkSync(tempFile);

    if (result === OperationResult.SUCCESS) {
      // Reload systemd and enable service
      const commands = [
        ['systemctl', 'daemon-reload'],
        ['systemctl', 'enable', serviceName]
      ];

      for (const cmd of commands) {
        const op: PrivilegedOperation = {
          command: cmd,
          description: `Setup service ${serviceName}`,
          permissionLevel: PermissionLevel.ADMINISTRATIVE
        };
        await this.manager.executeWithEscalation(op);
      }
    }

    console.log(`Service creation: ${message}`);
    return result === OperationResult.SUCCESS;
  }
}

// Example usage
if (require.main === module) {
  async function main() {
    // Initialize permission manager
    const manager = new PermissionManager();

    // Example: Install an npm package globally
    const [result, message] = await manager.installNpmPackage('typescript', true);
    console.log(`Installation result: ${result}`);
    console.log(`Message: ${message}`);

    // Example: Check audit summary
    const summary = await manager.getAuditSummary();
    console.log('Audit summary:', summary);
  }

  main().catch(console.error);
}