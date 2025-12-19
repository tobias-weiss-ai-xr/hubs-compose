#!/usr/bin/env python3
"""
Test Suite for Docker Compose Logs Validation

This test suite validates the health and readiness of the hubs-compose
docker-compose environment by parsing service logs for:
- Critical errors (FATAL, ERROR, connection failures)
- Service readiness indicators (listening, watching, ready)
- Database connectivity and initialization status
- Warning patterns that indicate service degradation

Usage:
    pytest test_docker_compose_logs.py -v
    pytest test_docker_compose_logs.py -v -s  # Show output
    pytest test_docker_compose_logs.py::test_no_fatal_errors -v

Environment variables:
    DOCKER_COMPOSE_PATH: path to docker-compose.yml (default: current dir)
    LOG_TAIL_LINES: number of log lines to check (default: 200)
"""

import subprocess
import re
import pytest
from typing import List, Tuple, Dict
from collections import defaultdict


class DockerComposeLogsValidator:
    """Validates docker-compose service logs for errors and readiness."""
    
    def __init__(self, compose_dir: str = "/opt/git/hubs-compose", tail_lines: int = 200):
        self.compose_dir = compose_dir
        self.tail_lines = tail_lines
        self.logs_cache = {}
    
    def get_service_names(self) -> List[str]:
        """Get list of all services from docker-compose."""
        result = subprocess.run(
            ["docker", "compose", "config", "--services"],
            cwd=self.compose_dir,
            capture_output=True,
            text=True
        )
        if result.returncode != 0:
            raise RuntimeError(f"Failed to get services: {result.stderr}")
        return result.stdout.strip().split('\n')
    
    def get_service_logs(self, service: str) -> str:
        """Get logs for a specific service."""
        if service in self.logs_cache:
            return self.logs_cache[service]
        
        result = subprocess.run(
            ["docker", "compose", "logs", service, "--tail", str(self.tail_lines)],
            cwd=self.compose_dir,
            capture_output=True,
            text=True
        )
        logs = result.stdout or result.stderr
        self.logs_cache[service] = logs
        return logs
    
    def get_all_logs(self) -> Dict[str, str]:
        """Get logs for all services."""
        services = self.get_service_names()
        return {service: self.get_service_logs(service) for service in services}
    
    def find_errors(self, logs: str) -> List[str]:
        """Find critical error patterns in logs."""
        errors = []
        critical_patterns = [
            r'FATAL:.*',
            r'ERROR:.*',
            r'Connection refused',
            r'Cannot connect',
            r'database.*does not exist',
            r'No such file or directory',
            r'Bind for .* failed',
            r'Address already in use',
            r'permission denied',
        ]
        
        for line in logs.split('\n'):
            for pattern in critical_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    errors.append(line.strip())
                    break
        
        return errors
    
    def find_warnings(self, logs: str) -> List[str]:
        """Find warning patterns in logs."""
        warnings = []
        warning_patterns = [
            r'WARNING.*',
            r'could not resolve address',
            r'backend has no server available',
            r'Server .* is DOWN',
            r'retrying',
            r'failed.*retry',
            r'timed out',
            r'timeout',
        ]
        
        for line in logs.split('\n'):
            for pattern in warning_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    warnings.append(line.strip())
                    break
        
        return warnings
    
    def find_readiness_indicators(self, logs: str) -> List[str]:
        """Find service readiness indicators in logs."""
        readiness = []
        readiness_patterns = [
            r'listening on',
            r'listening at',
            r'Listening on',
            r'listening for connections',
            r'Ready to accept connections',
            r'watching for changes',
            r'Watching for changes',
            r'started successfully',
            r'Server running',
            r'HTTP.*started',
            r'Application startup complete',
            r'is UP',
            r'READY',
            r'ready to serve',
        ]
        
        for line in logs.split('\n'):
            for pattern in readiness_patterns:
                if re.search(pattern, line, re.IGNORECASE):
                    readiness.append(line.strip())
                    break
        
        return readiness
    
    def check_database_connectivity(self) -> Dict[str, Tuple[bool, str]]:
        """Check database connectivity for services that depend on PostgreSQL."""
        db_dependent_services = ['postgrest', 'reticulum', 'dialog']
        results = {}
        
        for service in db_dependent_services:
            try:
                logs = self.get_service_logs(service)
            except:
                results[service] = (False, "Service not found or logs unavailable")
                continue
            
            # Check for connection success
            success_patterns = [
                r'connected to.*database',
                r'ready to serve',
                r'Connection OK',
                r'listening on',
            ]
            
            # Check for connection failure
            failure_patterns = [
                r'database.*does not exist',
                r'FATAL.*password authentication failed',
                r'FATAL:.*connection refused',
                r'no pg_hba.conf entry',
            ]
            
            has_failure = any(re.search(pattern, logs, re.IGNORECASE) for pattern in failure_patterns)
            has_success = any(re.search(pattern, logs, re.IGNORECASE) for pattern in success_patterns)
            
            if has_failure:
                results[service] = (False, "Database connection failed")
            elif has_success:
                results[service] = (True, "Database connected")
            else:
                results[service] = (None, "Unclear database connectivity status")
        
        return results
    
    def check_service_running(self, service: str) -> bool:
        """Check if a service is currently running."""
        result = subprocess.run(
            ["docker", "compose", "ps", service],
            cwd=self.compose_dir,
            capture_output=True,
            text=True
        )
        # Service is running if status output contains "Up"
        return "Up" in result.stdout
    
    def get_service_status(self) -> Dict[str, bool]:
        """Get running status for all services."""
        result = subprocess.run(
            ["docker", "compose", "ps"],
            cwd=self.compose_dir,
            capture_output=True,
            text=True
        )
        
        services = {}
        for line in result.stdout.split('\n')[3:]:  # Skip header lines
            if not line.strip():
                continue
            parts = line.split()
            if len(parts) >= 2:
                # Extract service name (container name format: hubs-compose-{service}-1)
                container_name = parts[0]
                status = "Up" in line
                # Extract service name from container name
                if 'hubs-compose-' in container_name:
                    service_name = container_name.replace('hubs-compose-', '').rsplit('-1', 1)[0]
                    services[service_name] = status
        
        return services


# Fixtures
@pytest.fixture
def validator():
    """Create a validator instance."""
    return DockerComposeLogsValidator()


# Tests

def test_no_fatal_errors(validator):
    """Test that no services have FATAL errors in their logs."""
    all_logs = validator.get_all_logs()
    
    errors_by_service = {}
    for service, logs in all_logs.items():
        errors = validator.find_errors(logs)
        if errors:
            errors_by_service[service] = errors
    
    if errors_by_service:
        error_report = "\n".join([
            f"\n{service}:"
            + "\n  ".join([""] + errors_by_service[service])
            for service in sorted(errors_by_service.keys())
        ])
        pytest.fail(f"Found critical errors in service logs:{error_report}")


def test_database_initialization(validator):
    """Test that PostgreSQL database ret_dev exists and is initialized."""
    logs = validator.get_service_logs('db')
    
    # Check for database readiness
    if 'PostgreSQL init process complete' not in logs and 'ready to accept connections' not in logs:
        pytest.skip("Database may not be fully initialized yet")
    
    # Check for missing ret_dev database
    if 'database "ret_dev" does not exist' in logs:
        pytest.fail("Database 'ret_dev' does not exist - run migrations")
    
    # Verify no authentication errors
    if 'password authentication failed' in logs:
        pytest.fail("PostgreSQL authentication failed")


def test_postgrest_database_connection(validator):
    """Test that Postgrest successfully connects to the database."""
    results = validator.check_database_connectivity()
    
    if 'postgrest' in results:
        connected, message = results['postgrest']
        if connected is False:
            pytest.fail(f"Postgrest database connection failed: {message}")
        elif connected is None:
            pytest.skip(f"Postgrest connectivity unclear: {message}")


def test_reticulum_database_connection(validator):
    """Test that Reticulum successfully connects to the database."""
    results = validator.check_database_connectivity()
    
    if 'reticulum' in results:
        connected, message = results['reticulum']
        if connected is False:
            pytest.fail(f"Reticulum database connection failed: {message}")
        elif connected is None:
            pytest.skip(f"Reticulum connectivity unclear: {message}")


def test_no_services_crashing(validator):
    """Test that no services are in a restarting or error state."""
    result = subprocess.run(
        ["docker", "compose", "ps", "-a"],
        cwd="/opt/git/hubs-compose",
        capture_output=True,
        text=True
    )
    
    crashed_services = []
    for line in result.stdout.split('\n')[3:]:  # Skip header
        if not line.strip():
            continue
        # Check for Exited status
        if 'Exited' in line or 'restarting' in line.lower():
            container_name = line.split()[0]
            status = line.split('  ')[-1] if '  ' in line else line
            crashed_services.append(f"{container_name}: {status}")
    
    if crashed_services:
        report = "\n  ".join(crashed_services)
        pytest.fail(f"Found crashed or exited services:\n  {report}")


def test_haproxy_backend_health(validator):
    """Test that HAProxy has healthy backends registered."""
    logs = validator.get_service_logs('haproxy')
    
    # Check for successful backend registration
    required_backends = ['hugo-tobias-weiss-org', 'hugo-graphwiz-ai', 'hugo-chemie-lernen-org']
    
    missing_backends = []
    for backend in required_backends:
        if f"Server {backend} is UP" not in logs and f"'{backend}': added to backend" not in logs:
            # It's okay if backend is already initialized and not in recent logs
            # Just check for explicit DOWN status
            if f"Server {backend} is DOWN" in logs or f"could not resolve address '{backend}'" in logs:
                missing_backends.append(backend)
    
    if missing_backends:
        pytest.fail(f"HAProxy backends not healthy: {', '.join(missing_backends)}")


def test_hugo_sites_building(validator):
    """Test that Hugo sites are building successfully."""
    hugo_services = [
        'hugo-tobias-weiss-org',
        'hugo-graphwiz-ai',
        'hugo-chemie-lernen-org'
    ]
    
    failed_builds = []
    for service in hugo_services:
        try:
            logs = validator.get_service_logs(service)
        except:
            pytest.skip(f"{service} logs unavailable")
            continue
        
        # Check for successful build
        if 'error' in logs.lower() and 'pages' not in logs.lower():
            failed_builds.append(service)
        
        # Check for unmarshal/YAML errors
        if 'unmarshal failed' in logs or 'bare keys cannot contain' in logs:
            failed_builds.append(f"{service} (YAML/frontmatter error)")
    
    if failed_builds:
        pytest.fail(f"Hugo sites failed to build: {', '.join(failed_builds)}")


def test_tls_certificates_valid(validator):
    """Test that TLS certificates exist and are configured in HAProxy."""
    haproxy_logs = validator.get_service_logs('haproxy')
    
    # Check for certificate loading errors
    if 'no certificates' in haproxy_logs.lower():
        pytest.fail("HAProxy has no TLS certificates configured")
    
    if 'unable to load' in haproxy_logs.lower() and 'certificate' in haproxy_logs.lower():
        pytest.fail("HAProxy failed to load certificates")


def test_services_have_readiness_logs(validator):
    """Test that critical services show readiness indicators."""
    critical_services = {
        'haproxy': ['listening on', 'started'],
        'db': ['ready to accept connections', 'PostgreSQL init process complete'],
        'postgrest': ['listening on', 'ready to serve'],
    }
    
    services_missing_readiness = []
    
    for service, patterns in critical_services.items():
        try:
            logs = validator.get_service_logs(service)
        except:
            pytest.skip(f"{service} logs unavailable")
            continue
        
        has_readiness = any(pattern.lower() in logs.lower() for pattern in patterns)
        if not has_readiness:
            services_missing_readiness.append(service)
    
    if services_missing_readiness:
        pytest.fail(
            f"Services not showing readiness indicators: {', '.join(services_missing_readiness)}\n"
            "These services may still be initializing. If persistent, check logs with:\n"
            "  docker compose logs [service]"
        )


def test_no_memory_issues(validator):
    """Test for out-of-memory or memory-related errors."""
    all_logs = validator.get_all_logs()
    
    memory_issues = []
    for service, logs in all_logs.items():
        if any(pattern in logs.lower() for pattern in ['oom', 'out of memory', 'memory error', 'killed']):
            memory_issues.append(service)
    
    if memory_issues:
        pytest.fail(f"Memory issues detected in services: {', '.join(memory_issues)}")


def test_disk_space_available(validator):
    """Test that services can write to disk without errors."""
    all_logs = validator.get_all_logs()
    
    disk_issues = []
    for service, logs in all_logs.items():
        if any(pattern in logs.lower() for pattern in ['no space left', 'disk full', 'enospc', 'read-only file system']):
            disk_issues.append(service)
    
    if disk_issues:
        pytest.fail(f"Disk space issues detected in services: {', '.join(disk_issues)}")


def test_no_permission_denied_errors(validator):
    """Test that no services are encountering permission issues."""
    all_logs = validator.get_all_logs()
    
    permission_issues = []
    for service, logs in all_logs.items():
        if any(pattern in logs for pattern in ['Permission denied', 'permission error', 'access denied']):
            permission_issues.append(service)
    
    if permission_issues:
        pytest.fail(f"Permission denied errors in services: {', '.join(permission_issues)}")


if __name__ == '__main__':
    pytest.main([__file__, '-v', '--tb=short'])
