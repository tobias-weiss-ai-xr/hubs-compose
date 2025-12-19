#!/usr/bin/env python3
"""
Standalone Docker Compose Logs Validator (no pytest required)

Run as: python3 test_docker_compose_logs_standalone.py
"""

import subprocess
import re
import sys
from typing import List, Dict, Tuple
from collections import defaultdict


try:
    import docker
except Exception:
    docker = None


class DockerComposeLogsValidator:
    """Validates docker-compose service logs for errors and readiness."""
    
    def __init__(self, compose_dir: str = "/opt/git/hubs-compose", tail_lines: int = 200):
        self.compose_dir = compose_dir
        self.tail_lines = tail_lines
        self.logs_cache = {}
        self.results = defaultdict(lambda: {'passed': 0, 'failed': 0, 'skipped': 0, 'errors': []})
    
    def get_service_names(self) -> List[str]:
        """Get list of all services from running containers (compose project prefix).

        Falls back to `docker compose config --services` if the Docker SDK
        is not available in the environment.
        """
        if docker is None:
            result = subprocess.run(
                ["docker", "compose", "config", "--services"],
                cwd=self.compose_dir,
                capture_output=True,
                text=True
            )
            if result.returncode != 0:
                raise RuntimeError(f"Failed to get services: {result.stderr}")
            return result.stdout.strip().split('\n')

        client = docker.from_env()
        containers = client.containers.list(all=True)
        services = set()
        for c in containers:
            name = c.name
            if name.startswith('hubs-compose-'):
                svc = name.replace('hubs-compose-', '')
                svc = svc.rsplit('-', 1)[0]
                services.add(svc)
        return sorted(services)
    
    def get_service_logs(self, service: str) -> str:
        """Get logs for a specific service. Uses Docker SDK if available."""
        if service in self.logs_cache:
            return self.logs_cache[service]

        if docker is None:
            result = subprocess.run(
                ["docker", "compose", "logs", service, "--tail", str(self.tail_lines)],
                cwd=self.compose_dir,
                capture_output=True,
                text=True
            )
            logs = result.stdout or result.stderr
            self.logs_cache[service] = logs
            return logs

        client = docker.from_env()
        container_name = f"hubs-compose-{service}-1"
        try:
            container = client.containers.get(container_name)
            raw = container.logs(tail=self.tail_lines, stdout=True, stderr=True)
            logs = raw.decode('utf-8', errors='replace')
        except Exception:
            # Try to match any container whose name contains the service
            matched = None
            for c in client.containers.list(all=True):
                if f'-{service}-' in c.name or c.name.endswith(f'-{service}-1'):
                    matched = c
                    break
            if matched:
                raw = matched.logs(tail=self.tail_lines, stdout=True, stderr=True)
                logs = raw.decode('utf-8', errors='replace')
            else:
                logs = ''

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
    
    def check_service_running(self, service: str) -> bool:
        """Check if a service is currently running."""
        if docker is None:
            result = subprocess.run(
                ["docker", "compose", "ps", service],
                cwd=self.compose_dir,
                capture_output=True,
                text=True
            )
            return "Up" in result.stdout

        client = docker.from_env()
        container_name = f"hubs-compose-{service}-1"
        try:
            c = client.containers.get(container_name)
            return c.status == 'running'
        except Exception:
            for c in client.containers.list(all=True):
                if f'-{service}-' in c.name or c.name.endswith(f'-{service}-1'):
                    return c.status == 'running'
            return False
    
    def test_no_fatal_errors(self) -> bool:
        """Test that no services have FATAL errors in their logs."""
        print("\n[TEST] No FATAL/ERROR in service logs...")
        all_logs = self.get_all_logs()
        
        errors_by_service = {}
        for service, logs in all_logs.items():
            errors = self.find_errors(logs)
            if errors:
                errors_by_service[service] = errors
        
        if errors_by_service:
            for service in sorted(errors_by_service.keys()):
                print(f"  ✗ {service}:")
                for error in errors_by_service[service][:5]:  # Show first 5 errors
                    print(f"    - {error[:100]}")
            self.results['no_fatal_errors']['failed'] += 1
            return False
        else:
            print("  ✓ PASSED")
            self.results['no_fatal_errors']['passed'] += 1
            return True
    
    def test_database_initialization(self) -> bool:
        """Test that PostgreSQL database ret_dev exists and is initialized."""
        print("\n[TEST] PostgreSQL ret_dev database initialized...")
        try:
            logs = self.get_service_logs('db')
        except:
            print("  ⊘ SKIPPED - db service not available")
            self.results['db_init']['skipped'] += 1
            return None
        
        if 'PostgreSQL init process complete' not in logs and 'ready to accept connections' not in logs:
            print("  ⊘ SKIPPED - Database still initializing")
            self.results['db_init']['skipped'] += 1
            return None
        
        if 'database "ret_dev" does not exist' in logs:
            print("  ✗ FAILED - Database ret_dev does not exist")
            self.results['db_init']['failed'] += 1
            return False
        
        if 'password authentication failed' in logs:
            print("  ✗ FAILED - PostgreSQL authentication failed")
            self.results['db_init']['failed'] += 1
            return False
        
        print("  ✓ PASSED")
        self.results['db_init']['passed'] += 1
        return True
    
    def test_no_services_crashing(self) -> bool:
        """Test that no services are in a restarting or error state."""
        print("\n[TEST] No crashed or exited services...")
        result = subprocess.run(
            ["docker", "compose", "ps", "-a"],
            cwd=self.compose_dir,
            capture_output=True,
            text=True
        )
        
        crashed_services = []
        for line in result.stdout.split('\n')[3:]:  # Skip header
            if not line.strip():
                continue
            if 'Exited' in line or 'restarting' in line.lower():
                container_name = line.split()[0]
                crashed_services.append(container_name)
        
        if crashed_services:
            print(f"  ✗ FAILED - Found {len(crashed_services)} crashed service(s):")
            for svc in crashed_services[:5]:
                print(f"    - {svc}")
            self.results['no_crashed']['failed'] += 1
            return False
        else:
            print("  ✓ PASSED")
            self.results['no_crashed']['passed'] += 1
            return True
    
    def test_haproxy_backends(self) -> bool:
        """Test that HAProxy has healthy backends registered."""
        print("\n[TEST] HAProxy backends healthy...")
        try:
            logs = self.get_service_logs('haproxy')
        except:
            print("  ⊘ SKIPPED - HAProxy logs unavailable")
            self.results['haproxy_backends']['skipped'] += 1
            return None
        
        required_backends = ['hugo-tobias-weiss-org', 'hugo-graphwiz-ai', 'hugo-chemie-lernen-org']
        missing_backends = []
        
        for backend in required_backends:
            if f"Server {backend} is DOWN" in logs:
                missing_backends.append(f"{backend} (DOWN)")
            elif f"could not resolve address '{backend}'" in logs:
                missing_backends.append(f"{backend} (unresolved)")
        
        if missing_backends:
            print(f"  ✗ FAILED - Unhealthy backends:")
            for backend in missing_backends:
                print(f"    - {backend}")
            self.results['haproxy_backends']['failed'] += 1
            return False
        else:
            print("  ✓ PASSED")
            self.results['haproxy_backends']['passed'] += 1
            return True
    
    def test_hugo_sites(self) -> bool:
        """Test that Hugo sites are building successfully."""
        print("\n[TEST] Hugo sites building...")
        hugo_services = [
            'hugo-tobias-weiss-org',
            'hugo-graphwiz-ai',
            'hugo-chemie-lernen-org'
        ]
        
        failed_builds = []
        for service in hugo_services:
            try:
                logs = self.get_service_logs(service)
            except:
                continue
            
            # Check for build errors
            if 'unmarshal failed' in logs or 'bare keys cannot contain' in logs:
                failed_builds.append(f"{service} (YAML/frontmatter error)")
            elif 'error' in logs.lower() and 'pages' not in logs.lower():
                failed_builds.append(service)
        
        if failed_builds:
            print(f"  ✗ FAILED - Hugo sites with build issues:")
            for site in failed_builds:
                print(f"    - {site}")
            self.results['hugo_build']['failed'] += 1
            return False
        else:
            print("  ✓ PASSED")
            self.results['hugo_build']['passed'] += 1
            return True
    
    def test_disk_space(self) -> bool:
        """Test that services can write to disk without errors."""
        print("\n[TEST] Disk space available...")
        all_logs = self.get_all_logs()
        
        disk_issues = []
        for service, logs in all_logs.items():
            if any(p in logs.lower() for p in ['no space left', 'disk full', 'enospc']):
                disk_issues.append(service)
        
        if disk_issues:
            print(f"  ✗ FAILED - Disk space issues in: {', '.join(disk_issues)}")
            self.results['disk_space']['failed'] += 1
            return False
        else:
            print("  ✓ PASSED")
            self.results['disk_space']['passed'] += 1
            return True
    
    def test_memory_issues(self) -> bool:
        """Test for out-of-memory errors."""
        print("\n[TEST] No memory errors...")
        all_logs = self.get_all_logs()
        
        memory_issues = []
        for service, logs in all_logs.items():
            if any(p in logs.lower() for p in ['oom', 'out of memory', 'killed']):
                memory_issues.append(service)
        
        if memory_issues:
            print(f"  ✗ FAILED - Memory issues in: {', '.join(memory_issues)}")
            self.results['memory']['failed'] += 1
            return False
        else:
            print("  ✓ PASSED")
            self.results['memory']['passed'] += 1
            return True
    
    def run_all_tests(self) -> int:
        """Run all validation tests and return exit code."""
        print("=" * 70)
        print("DOCKER COMPOSE LOGS VALIDATION TEST SUITE")
        print("=" * 70)
        
        try:
            self.test_no_fatal_errors()
            self.test_database_initialization()
            self.test_no_services_crashing()
            self.test_haproxy_backends()
            self.test_hugo_sites()
            self.test_disk_space()
            self.test_memory_issues()
        except Exception as e:
            print(f"\n✗ FATAL ERROR: {e}")
            return 1
        
        # Print summary
        print("\n" + "=" * 70)
        print("TEST SUMMARY")
        print("=" * 70)
        
        total_passed = sum(r['passed'] for r in self.results.values())
        total_failed = sum(r['failed'] for r in self.results.values())
        total_skipped = sum(r['skipped'] for r in self.results.values())
        
        print(f"\nTotal: {total_passed + total_failed + total_skipped} tests")
        print(f"  ✓ Passed:  {total_passed}")
        print(f"  ✗ Failed:  {total_failed}")
        print(f"  ⊘ Skipped: {total_skipped}")
        
        if total_failed == 0:
            print("\n✓ All critical tests PASSED")
            return 0
        else:
            print(f"\n✗ {total_failed} test(s) FAILED")
            return 1


if __name__ == '__main__':
    validator = DockerComposeLogsValidator()
    exit_code = validator.run_all_tests()
    sys.exit(exit_code)
