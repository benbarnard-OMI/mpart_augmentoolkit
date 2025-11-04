#!/usr/bin/env python3
"""
Comprehensive Docker Environment Test Script for Augmentoolkit with GPU

This script validates that all components are properly configured for running
Augmentoolkit on 1,100+ PDFs with GPU acceleration.

Usage:
    python scripts/test_environment.py

Exit Codes:
    0 - All tests passed
    1 - One or more tests failed
"""

import sys
import os
from pathlib import Path
from typing import Tuple, List, Dict, Any
import traceback


# ANSI color codes for pretty output
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    BOLD = '\033[1m'
    END = '\033[0m'


class TestResult:
    """Track test results across all test functions"""
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.tests: List[Tuple[str, bool, str]] = []
    
    def add_pass(self, test_name: str, message: str = ""):
        self.passed += 1
        self.tests.append((test_name, True, message))
        print(f"{Colors.GREEN}✓{Colors.END} {test_name}: {message}")
    
    def add_fail(self, test_name: str, message: str = ""):
        self.failed += 1
        self.tests.append((test_name, False, message))
        print(f"{Colors.RED}✗{Colors.END} {test_name}: {message}")
    
    def get_total(self) -> int:
        return self.passed + self.failed


def print_section_header(title: str):
    """Print a formatted section header"""
    print(f"\n{Colors.BLUE}{Colors.BOLD}{'=' * 70}{Colors.END}")
    print(f"{Colors.BLUE}{Colors.BOLD}{title}{Colors.END}")
    print(f"{Colors.BLUE}{Colors.BOLD}{'=' * 70}{Colors.END}")


def test_gpu_validation(result: TestResult):
    """Test GPU availability and CUDA functionality"""
    print_section_header("GPU VALIDATION")
    
    try:
        import torch
        
        # Check if CUDA is available
        cuda_available = torch.cuda.is_available()
        if cuda_available:
            result.add_pass("CUDA available", "True")
        else:
            result.add_fail("CUDA available", "False - No GPU detected")
            return
        
        # Get GPU count
        gpu_count = torch.cuda.device_count()
        if gpu_count > 0:
            result.add_pass("GPU count", f"{gpu_count}")
        else:
            result.add_fail("GPU count", "0 GPUs found")
            return
        
        # Get GPU details for each device
        for i in range(gpu_count):
            gpu_name = torch.cuda.get_device_name(i)
            gpu_memory = torch.cuda.get_device_properties(i).total_memory / (1024**3)  # Convert to GB
            result.add_pass(
                f"GPU {i}",
                f"{gpu_name} ({gpu_memory:.1f} GB)"
            )
        
        # Test tensor allocation on GPU
        try:
            test_tensor = torch.zeros(100, 100).cuda()
            result.add_pass("Tensor allocation test", "Successfully allocated tensor on GPU")
            del test_tensor
            torch.cuda.empty_cache()
        except Exception as e:
            result.add_fail("Tensor allocation test", f"Failed: {str(e)}")
        
        # Check CUDA version
        cuda_version = torch.version.cuda
        if cuda_version:
            result.add_pass("CUDA version", cuda_version)
        else:
            result.add_fail("CUDA version", "Unable to detect CUDA version")
        
    except ImportError as e:
        result.add_fail("GPU validation", f"Failed to import torch: {str(e)}")
    except Exception as e:
        result.add_fail("GPU validation", f"Unexpected error: {str(e)}")


def test_library_imports(result: TestResult):
    """Test importing critical libraries and print their versions"""
    print_section_header("LIBRARY IMPORTS")
    
    # List of critical packages to test
    packages = [
        ('torch', 'PyTorch'),
        ('transformers', 'Transformers'),
        ('accelerate', 'Accelerate'),
        ('vllm', 'vLLM'),
        ('docling', 'Docling'),
        ('yaml', 'PyYAML'),
        ('pandas', 'Pandas'),
        ('numpy', 'NumPy'),
        ('asyncio', 'AsyncIO'),
        ('aiohttp', 'AioHTTP'),
    ]
    
    for module_name, display_name in packages:
        try:
            module = __import__(module_name)
            # Try to get version
            version = getattr(module, '__version__', 'unknown')
            result.add_pass(display_name, f"v{version}")
        except ImportError as e:
            result.add_fail(display_name, f"Import failed: {str(e)}")
        except Exception as e:
            result.add_fail(display_name, f"Unexpected error: {str(e)}")
    
    # Test some optional but useful packages
    optional_packages = [
        ('PIL', 'Pillow'),
        ('tqdm', 'tqdm'),
        ('requests', 'Requests'),
    ]
    
    print(f"\n{Colors.YELLOW}Optional packages:{Colors.END}")
    for module_name, display_name in optional_packages:
        try:
            module = __import__(module_name)
            version = getattr(module, '__version__', 'unknown')
            print(f"  • {display_name}: v{version}")
        except ImportError:
            print(f"  • {display_name}: Not installed (optional)")


def test_augmentoolkit_verification(result: TestResult):
    """Verify Augmentoolkit directory and key files exist"""
    print_section_header("AUGMENTOOLKIT VERIFICATION")
    
    augmentoolkit_path = Path("/workspace/augmentoolkit")
    
    # Check if Augmentoolkit directory exists
    if augmentoolkit_path.exists() and augmentoolkit_path.is_dir():
        result.add_pass("Augmentoolkit directory", str(augmentoolkit_path))
    else:
        result.add_fail("Augmentoolkit directory", f"Not found at {augmentoolkit_path}")
        return
    
    # Check for key subdirectories and files
    expected_items = [
        ("prompts", True),  # (name, is_directory)
        ("prompts_inferred_facts", True),
        ("prompt_overrides", True),
    ]
    
    for item_name, is_dir in expected_items:
        item_path = augmentoolkit_path / item_name
        if item_path.exists():
            item_type = "directory" if is_dir else "file"
            result.add_pass(f"Augmentoolkit/{item_name}", f"{item_type} exists")
        else:
            item_type = "directory" if is_dir else "file"
            result.add_fail(f"Augmentoolkit/{item_name}", f"{item_type} not found")
    
    # Try to find Python files in augmentoolkit
    try:
        py_files = list(augmentoolkit_path.rglob("*.py"))
        if len(py_files) > 0:
            result.add_pass("Augmentoolkit Python files", f"Found {len(py_files)} .py files")
        else:
            result.add_fail("Augmentoolkit Python files", "No .py files found")
    except Exception as e:
        result.add_fail("Augmentoolkit Python files", f"Error scanning: {str(e)}")


def test_configuration_file(result: TestResult):
    """Test configuration file existence and validity"""
    print_section_header("CONFIGURATION FILE CHECK")
    
    config_path = Path("/workspace/configs/medicaid_config.yaml")
    
    # Check if config file exists
    if config_path.exists() and config_path.is_file():
        result.add_pass("Config file exists", str(config_path))
    else:
        result.add_fail("Config file exists", f"Not found at {config_path}")
        return
    
    # Try to load and parse the YAML file
    try:
        import yaml
        with open(config_path, 'r') as f:
            config = yaml.safe_load(f)
        result.add_pass("Config file parsing", "Successfully parsed YAML")
    except Exception as e:
        result.add_fail("Config file parsing", f"Failed to parse: {str(e)}")
        return
    
    # Check for required top-level keys
    required_keys = [
        'pipeline',
        'path',
        'system',
        'factual_sft',
        'factual_sft_settings',
        'rag_data',
        'correction_pipeline',
        'final_datasaving_settings',
    ]
    
    for key in required_keys:
        if key in config:
            result.add_pass(f"Config key: {key}", "Present")
        else:
            result.add_fail(f"Config key: {key}", "Missing")
    
    # Check specific nested configurations
    try:
        # Check path configuration
        if 'path' in config:
            path_config = config['path']
            if 'input_dirs' in path_config and isinstance(path_config['input_dirs'], list):
                result.add_pass("Config path.input_dirs", f"{len(path_config['input_dirs'])} input directory configured")
            else:
                result.add_fail("Config path.input_dirs", "Missing or invalid")
            
            if 'output_dir' in path_config:
                result.add_pass("Config path.output_dir", path_config['output_dir'])
            else:
                result.add_fail("Config path.output_dir", "Missing")
        
        # Check system configuration
        if 'system' in config:
            system_config = config['system']
            concurrency = system_config.get('concurrency_limit', 'not set')
            result.add_pass("Config system.concurrency_limit", str(concurrency))
    except Exception as e:
        result.add_fail("Config nested validation", f"Error: {str(e)}")


def test_directory_structure(result: TestResult):
    """Verify expected directories exist and have proper permissions"""
    print_section_header("DIRECTORY STRUCTURE")
    
    # Directories that should exist
    required_dirs = [
        "/workspace",
        "/workspace/data",
        "/workspace/configs",
        "/workspace/scripts",
    ]
    
    # Directories that should be writable
    writable_dirs = [
        "/workspace/output",
        "/workspace/data/output",
        "/workspace/data/processed",
    ]
    
    # Check required directories
    for dir_path in required_dirs:
        path = Path(dir_path)
        if path.exists() and path.is_dir():
            result.add_pass(f"Directory exists: {dir_path}", "✓")
        else:
            result.add_fail(f"Directory exists: {dir_path}", "Not found")
    
    # Check writable directories (create if they don't exist)
    for dir_path in writable_dirs:
        path = Path(dir_path)
        
        # Create if doesn't exist
        if not path.exists():
            try:
                path.mkdir(parents=True, exist_ok=True)
                result.add_pass(f"Created directory: {dir_path}", "✓")
            except Exception as e:
                result.add_fail(f"Create directory: {dir_path}", f"Failed: {str(e)}")
                continue
        
        # Test write permissions
        test_file = path / ".test_write_permission"
        try:
            test_file.write_text("test")
            test_file.unlink()
            result.add_pass(f"Write permission: {dir_path}", "✓")
        except Exception as e:
            result.add_fail(f"Write permission: {dir_path}", f"No write access: {str(e)}")


def test_vllm_compatibility(result: TestResult):
    """Test vLLM-specific functionality"""
    print_section_header("vLLM COMPATIBILITY")
    
    try:
        import vllm
        from vllm import LLM, SamplingParams
        result.add_pass("vLLM imports", "Core classes imported successfully")
        
        # Check if vLLM can detect GPUs
        try:
            import torch
            if torch.cuda.is_available():
                result.add_pass("vLLM GPU detection", "CUDA available for vLLM")
            else:
                result.add_fail("vLLM GPU detection", "CUDA not available")
        except Exception as e:
            result.add_fail("vLLM GPU detection", f"Error: {str(e)}")
        
    except ImportError as e:
        result.add_fail("vLLM imports", f"Import failed: {str(e)}")
    except Exception as e:
        result.add_fail("vLLM imports", f"Unexpected error: {str(e)}")


def test_environment_variables(result: TestResult):
    """Check for important environment variables"""
    print_section_header("ENVIRONMENT VARIABLES")
    
    # Important environment variables (some may be optional)
    env_vars = [
        ('CUDA_VISIBLE_DEVICES', False),  # (name, required)
        ('LLAMA_API_KEY', False),
        ('VLLM_BASE_URL', False),
        ('LLAMA_MODEL', False),
        ('HF_HOME', False),
        ('TRANSFORMERS_CACHE', False),
    ]
    
    for var_name, required in env_vars:
        value = os.environ.get(var_name)
        if value:
            # Mask sensitive values
            if 'KEY' in var_name or 'TOKEN' in var_name:
                display_value = f"{value[:8]}..." if len(value) > 8 else "***"
            else:
                display_value = value
            result.add_pass(f"Env var: {var_name}", display_value)
        else:
            if required:
                result.add_fail(f"Env var: {var_name}", "Not set (required)")
            else:
                print(f"{Colors.YELLOW}ℹ{Colors.END} Env var: {var_name}: Not set (optional)")


def test_python_environment(result: TestResult):
    """Test Python environment details"""
    print_section_header("PYTHON ENVIRONMENT")
    
    # Python version
    python_version = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    result.add_pass("Python version", python_version)
    
    # Python executable
    result.add_pass("Python executable", sys.executable)
    
    # Check if we're in a virtual environment
    in_venv = hasattr(sys, 'real_prefix') or (
        hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix
    )
    venv_status = "Yes" if in_venv else "No"
    result.add_pass("Virtual environment", venv_status)


def print_summary(result: TestResult):
    """Print final test summary"""
    print_section_header("TEST SUMMARY")
    
    total = result.get_total()
    pass_rate = (result.passed / total * 100) if total > 0 else 0
    
    print(f"\nTotal tests run: {total}")
    print(f"{Colors.GREEN}Passed: {result.passed}{Colors.END}")
    print(f"{Colors.RED}Failed: {result.failed}{Colors.END}")
    print(f"Pass rate: {pass_rate:.1f}%")
    
    if result.failed == 0:
        print(f"\n{Colors.GREEN}{Colors.BOLD}{'=' * 70}{Colors.END}")
        print(f"{Colors.GREEN}{Colors.BOLD}✓ ALL TESTS PASSED - Environment is ready for Augmentoolkit!{Colors.END}")
        print(f"{Colors.GREEN}{Colors.BOLD}{'=' * 70}{Colors.END}\n")
        return 0
    else:
        print(f"\n{Colors.RED}{Colors.BOLD}{'=' * 70}{Colors.END}")
        print(f"{Colors.RED}{Colors.BOLD}✗ SOME TESTS FAILED - Please review failures above{Colors.END}")
        print(f"{Colors.RED}{Colors.BOLD}{'=' * 70}{Colors.END}\n")
        
        # Print failed tests
        print(f"{Colors.BOLD}Failed tests:{Colors.END}")
        for test_name, passed, message in result.tests:
            if not passed:
                print(f"  • {test_name}: {message}")
        print()
        return 1


def main():
    """Main test orchestration function"""
    print(f"\n{Colors.BOLD}Augmentoolkit Docker Environment Test Suite{Colors.END}")
    print(f"{Colors.BOLD}Testing environment for GPU-accelerated processing{Colors.END}")
    
    result = TestResult()
    
    try:
        # Run all test suites
        test_python_environment(result)
        test_gpu_validation(result)
        test_library_imports(result)
        test_vllm_compatibility(result)
        test_augmentoolkit_verification(result)
        test_configuration_file(result)
        test_directory_structure(result)
        test_environment_variables(result)
        
        # Print summary and return exit code
        exit_code = print_summary(result)
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        print(f"\n\n{Colors.YELLOW}Test interrupted by user{Colors.END}")
        sys.exit(130)
    except Exception as e:
        print(f"\n{Colors.RED}{Colors.BOLD}FATAL ERROR:{Colors.END} {str(e)}")
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
