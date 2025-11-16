#!/usr/bin/env python3
"""
Python SDK Permission Manager

Handles permission escalation and privileged operations for Claude Python Agent.
Provides safe, auditable, and user-controlled privilege management.
"""

import os
import sys
import subprocess
import tempfile
import json
import logging
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from enum import Enum
from dataclasses import dataclass, asdict
from datetime import datetime

class PermissionLevel(Enum):
    """Permission levels for operations"""
    BASIC = "basic"          # User-level operations only
    ELEVATED = "elevated"    # Requires sudo/admin privileges
    ADMINISTRATIVE = "administrative"  # System-level changes

class OperationResult(Enum):
    """Result of permission operations"""
    SUCCESS = "success"
    PERMISSION_DENIED = "permission_denied"
    ESCALATION_FAILED = "escalation_failed"
    OPERATION_FAILED = "operation_failed"
    USER_CANCELLED = "user_cancelled"

@dataclass
class PrivilegedOperation:
    """Represents a privileged operation with metadata"""
    command: List[str]
    description: str
    permission_level: PermissionLevel
    requires_user_approval: bool = True
    timeout: int = 300
    working_directory: Optional[str] = None
    environment: Optional[Dict[str, str]] = None

@dataclass
class AuditEntry:
    """Audit log entry for privileged operations"""
    timestamp: datetime
    operation: str
    permission_level: str
    result: str
    user: str
    details: Dict[str, Any]

class PermissionManager:
    """Manages permissions and privilege escalation for Python SDK"""

    def __init__(self, log_file: Optional[str] = None):
        """
        Initialize the permission manager.

        Args:
            log_file: Path to audit log file
        """
        self.log_file = log_file or Path.home() / ".claude-python" / "audit.log"
        self.setup_logging()
        self.current_user = os.getenv('USER', os.getenv('USERNAME', 'unknown'))

        # Check if running in privileged environment
        self.is_privileged = self._check_privileged_status()

        # Operation history for session
        self.session_operations: List[AuditEntry] = []

    def setup_logging(self):
        """Set up logging for audit trail"""
        log_dir = Path(self.log_file).parent
        log_dir.mkdir(parents=True, exist_ok=True)

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)

    def _check_privileged_status(self) -> bool:
        """Check if running with elevated privileges"""
        try:
            # On Unix-like systems, check if running as root
            if hasattr(os, 'getuid'):
                return os.getuid() == 0
            # On Windows, check if running as administrator
            import ctypes
            return ctypes.windll.shell32.IsUserAnAdmin() != 0
        except Exception:
            return False

    def check_permission_required(self, operation: PrivilegedOperation) -> bool:
        """
        Check if an operation requires elevated permissions.

        Args:
            operation: The operation to check

        Returns:
            True if elevation is required
        """
        if operation.permission_level == PermissionLevel.BASIC:
            return False

        if self.is_privileged:
            return False

        return True

    def analyze_command_permissions(self, command: List[str]) -> PermissionLevel:
        """
        Analyze a command to determine required permission level.

        Args:
            command: Command to analyze

        Returns:
            Required permission level
        """
        if not command:
            return PermissionLevel.BASIC

        # Commands that typically require elevated permissions
        elevated_commands = {
            'sudo', 'doas', 'su', 'apt', 'apt-get', 'yum', 'dnf', 'pacman',
            'systemctl', 'service', 'mount', 'umount', 'fdisk', 'mkfs',
            'useradd', 'usermod', 'userdel', 'chmod', 'chown', 'visudo',
            'pip', 'conda', 'npm', 'yarn'  # Package managers
        }

        # Administrative commands
        admin_commands = {
            'crontab', 'iptables', 'ufw', 'firewall-cmd', 'sysctl',
            'hostnamectl', 'timedatectl', 'localectl'
        }

        first_cmd = command[0].lower()

        if first_cmd in admin_commands:
            return PermissionLevel.ADMINISTRATIVE
        elif first_cmd in elevated_commands:
            return PermissionLevel.ELEVATED

        # Check for privileged file paths
        privileged_paths = ['/etc', '/usr/local', '/opt', '/var', '/root']
        if any(arg.startswith(path) for arg in command for path in privileged_paths):
            return PermissionLevel.ELEVATED

        return PermissionLevel.BASIC

    def request_permission(self, operation: PrivilegedOperation) -> bool:
        """
        Request user permission for a privileged operation.

        Args:
            operation: The operation requiring permission

        Returns:
            True if user grants permission
        """
        if not operation.requires_user_approval:
            return True

        print(f"\n🔒 Privileged Operation Required")
        print(f"Description: {operation.description}")
        print(f"Command: {' '.join(operation.command)}")
        print(f"Permission Level: {operation.permission_level.value}")

        if operation.permission_level == PermissionLevel.ADMINISTRATIVE:
            print("⚠️  This operation makes system-level changes")
        elif operation.permission_level == PermissionLevel.ELEVATED:
            print("⚠️  This operation requires elevated privileges")

        while True:
            response = input("Do you want to proceed? (y/N): ").strip().lower()
            if response in ['y', 'yes']:
                return True
            elif response in ['n', 'no', '']:
                return False
            else:
                print("Please enter 'y' or 'n'")

    def execute_with_escalation(self, operation: PrivilegedOperation) -> Tuple[OperationResult, str]:
        """
        Execute an operation with automatic privilege escalation.

        Args:
            operation: The operation to execute

        Returns:
            Tuple of (result, output_message)
        """
        start_time = datetime.now()

        # Log the operation attempt
        self.logger.info(f"Attempting privileged operation: {operation.description}")
        self.logger.info(f"Command: {' '.join(operation.command)}")

        # Check if escalation is needed
        needs_escalation = self.check_permission_required(operation)

        # Request user permission if needed
        if needs_escalation and not self.request_permission(operation):
            result = OperationResult.USER_CANCELLED
            message = "User cancelled the operation"
            self._log_operation(operation, result, message, start_time)
            return result, message

        # Prepare the command
        command = operation.command.copy()
        if needs_escalation and not self.is_privileged:
            # Prefix with sudo for elevation
            command = ['sudo'] + command

        # Set up environment
        env = os.environ.copy()
        if operation.environment:
            env.update(operation.environment)

        try:
            # Execute the command
            process = subprocess.Popen(
                command,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                cwd=operation.working_directory,
                env=env
            )

            stdout, stderr = process.communicate(timeout=operation.timeout)

            if process.returncode == 0:
                result = OperationResult.SUCCESS
                message = stdout or "Operation completed successfully"
            else:
                result = OperationResult.OPERATION_FAILED
                message = f"Command failed with return code {process.returncode}: {stderr}"

        except subprocess.TimeoutExpired:
            result = OperationResult.OPERATION_FAILED
            message = f"Operation timed out after {operation.timeout} seconds"
            try:
                process.kill()
            except:
                pass

        except PermissionError:
            result = OperationResult.PERMISSION_DENIED
            message = "Permission denied - unable to execute command"

        except Exception as e:
            result = OperationResult.OPERATION_FAILED
            message = f"Unexpected error: {str(e)}"

        # Log the result
        self._log_operation(operation, result, message, start_time)

        return result, message

    def _log_operation(self, operation: PrivilegedOperation, result: OperationResult,
                       message: str, start_time: datetime):
        """Log an operation to the audit trail"""
        audit_entry = AuditEntry(
            timestamp=start_time,
            operation=' '.join(operation.command),
            permission_level=operation.permission_level.value,
            result=result.value,
            user=self.current_user,
            details={
                'description': operation.description,
                'duration_seconds': (datetime.now() - start_time).total_seconds(),
                'message': message,
                'working_directory': operation.working_directory
            }
        )

        # Add to session history
        self.session_operations.append(audit_entry)

        # Write to log file
        log_entry = {
            'timestamp': audit_entry.timestamp.isoformat(),
            'operation': audit_entry.operation,
            'permission_level': audit_entry.permission_level,
            'result': audit_entry.result,
            'user': audit_entry.user,
            'details': audit_entry.details
        }

        try:
            with open(self.log_file, 'a') as f:
                f.write(json.dumps(log_entry) + '\n')
        except Exception as e:
            self.logger.error(f"Failed to write audit log: {e}")

    def install_package(self, package_name: str, package_manager: str = "pip") -> Tuple[OperationResult, str]:
        """
        Install a Python package using the appropriate package manager.

        Args:
            package_name: Name of the package to install
            package_manager: Package manager to use (pip, conda)

        Returns:
            Tuple of (result, message)
        """
        if package_manager == "pip":
            command = ["pip", "install", package_name]
            description = f"Install Python package '{package_name}' using pip"
        elif package_manager == "conda":
            command = ["conda", "install", "-y", package_name]
            description = f"Install Python package '{package_name}' using conda"
        else:
            return OperationResult.OPERATION_FAILED, f"Unsupported package manager: {package_manager}"

        operation = PrivilegedOperation(
            command=command,
            description=description,
            permission_level=PermissionLevel.ELEVATED,
            timeout=600  # 10 minutes for package installation
        )

        return self.execute_with_escalation(operation)

    def manage_file_permissions(self, file_path: str, permissions: str,
                              owner: Optional[str] = None) -> Tuple[OperationResult, str]:
        """
        Change file permissions and optionally ownership.

        Args:
            file_path: Path to the file/directory
            permissions: Permission string (e.g., "755", "a+x")
            owner: Optional owner in format "user:group"

        Returns:
            Tuple of (result, message)
        """
        commands = []

        # Change permissions
        if permissions:
            commands.append(["chmod", permissions, file_path])

        # Change ownership if specified
        if owner:
            commands.append(["chown", owner, file_path])

        results = []
        for cmd in commands:
            operation = PrivilegedOperation(
                command=cmd,
                description=f"Change permissions/ownership for {file_path}",
                permission_level=PermissionLevel.ELEVATED
            )
            result, message = self.execute_with_escalation(operation)
            results.append((result, message))

            if result != OperationResult.SUCCESS:
                return result, message

        return OperationResult.SUCCESS, "Permissions updated successfully"

    def execute_script(self, script_path: str, arguments: Optional[List[str]] = None,
                       interpreter: str = "python3") -> Tuple[OperationResult, str]:
        """
        Execute a script with appropriate permissions.

        Args:
            script_path: Path to the script file
            arguments: Optional arguments to pass to the script
            interpreter: Interpreter to use

        Returns:
            Tuple of (result, message)
        """
        command = [interpreter, script_path]
        if arguments:
            command.extend(arguments)

        # Check script permissions first
        if not os.access(script_path, os.R_OK):
            return OperationResult.PERMISSION_DENIED, f"Cannot read script file: {script_path}"

        operation = PrivilegedOperation(
            command=command,
            description=f"Execute script: {script_path}",
            permission_level=self.analyze_command_permissions(command),
            timeout=300
        )

        return self.execute_with_escalation(operation)

    def get_session_history(self) -> List[AuditEntry]:
        """Get the history of operations in the current session"""
        return self.session_operations.copy()

    def get_audit_summary(self, limit: int = 50) -> Dict[str, Any]:
        """
        Get a summary of recent audit entries.

        Args:
            limit: Maximum number of entries to read

        Returns:
            Summary dictionary with statistics
        """
        try:
            entries = []
            with open(self.log_file, 'r') as f:
                for line in f:
                    try:
                        entries.append(json.loads(line.strip()))
                    except json.JSONDecodeError:
                        continue

            # Take the most recent entries
            recent_entries = entries[-limit:] if len(entries) > limit else entries

            # Calculate statistics
            summary = {
                'total_entries': len(recent_entries),
                'success_count': sum(1 for e in recent_entries if e['result'] == 'success'),
                'failure_count': sum(1 for e in recent_entries if e['result'] != 'success'),
                'elevated_operations': sum(1 for e in recent_entries
                                         if e['permission_level'] in ['elevated', 'administrative']),
                'recent_operations': recent_entries[-10:]  # Last 10 operations
            }

            return summary

        except FileNotFoundError:
            return {'total_entries': 0, 'message': 'No audit log found'}
        except Exception as e:
            return {'error': f'Failed to read audit log: {str(e)}'}

# Convenience functions for common operations
class PythonPrivileges:
    """High-level privilege operations for Python SDK"""

    def __init__(self, log_file: Optional[str] = None):
        self.manager = PermissionManager(log_file)

    def install_system_package(self, package_name: str) -> bool:
        """Install a system-wide Python package"""
        result, message = self.manager.install_package(package_name)
        print(f"Package installation: {message}")
        return result == OperationResult.SUCCESS

    def setup_development_environment(self, requirements_file: str) -> bool:
        """Install packages from requirements file"""
        if not os.path.exists(requirements_file):
            print(f"Requirements file not found: {requirements_file}")
            return False

        operation = PrivilegedOperation(
            command=["pip", "install", "-r", requirements_file],
            description=f"Install packages from {requirements_file}",
            permission_level=PermissionLevel.ELEVATED,
            timeout=600
        )

        result, message = self.manager.execute_with_escalation(operation)
        print(f"Environment setup: {message}")
        return result == OperationResult.SUCCESS

    def create_system_service(self, service_name: str, script_path: str) -> bool:
        """Create a systemd service (Linux only)"""
        service_content = f"""[Unit]
Description=Claude Python Agent Service
After=network.target

[Service]
Type=simple
User={os.getenv('USER', 'claude')}
WorkingDirectory={os.path.dirname(script_path)}
ExecStart=/usr/bin/python3 {script_path}
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
"""

        # Write service file
        service_file = f"/etc/systemd/system/{service_name}.service"
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as f:
            f.write(service_content)
            temp_file = f.name

        # Move service file to system location
        operation = PrivilegedOperation(
            command=["cp", temp_file, service_file],
            description=f"Create systemd service: {service_name}",
            permission_level=PermissionLevel.ADMINISTRATIVE
        )

        result, message = self.manager.execute_with_escalation(operation)

        # Clean up temp file
        os.unlink(temp_file)

        if result == OperationResult.SUCCESS:
            # Reload systemd and enable service
            for cmd in [["systemctl", "daemon-reload"],
                       ["systemctl", "enable", service_name]]:
                op = PrivilegedOperation(
                    command=cmd,
                    description=f"Setup service {service_name}",
                    permission_level=PermissionLevel.ADMINISTRATIVE
                )
                self.manager.execute_with_escalation(op)

        print(f"Service creation: {message}")
        return result == OperationResult.SUCCESS

# Example usage
if __name__ == "__main__":
    # Initialize permission manager
    manager = PermissionManager()

    # Example: Install a package with elevation
    result, message = manager.install_package("requests")
    print(f"Installation result: {result.value}")
    print(f"Message: {message}")

    # Example: Check audit summary
    summary = manager.get_audit_summary()
    print(f"Audit summary: {summary}")