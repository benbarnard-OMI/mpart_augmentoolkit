# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2025-11-03

### Added
- Initial release of Augmentoolkit Docker container for UIUC Campus Cluster
- Dockerfile with NVIDIA CUDA support for GPU acceleration
- Entrypoint script for flexible container execution
- Content-agnostic QA generation configuration (`qa_generation.yaml`)
- Comprehensive README with setup and usage instructions
- QUICKSTART guide for getting started in under 10 minutes
- CONTRIBUTING guide for customization and extension
- SLURM batch scripts for cluster execution:
  - `run_augmentoolkit.slurm` - Full production job
  - `run_augmentoolkit_test.slurm` - Quick test job
- Build script for Docker image creation
- Example configurations:
  - `examples/config_high_throughput.yaml` - Speed-optimized configuration
  - `examples/config_high_quality.yaml` - Quality-optimized configuration
  - `examples/README.md` - Configuration comparison and usage guide
- `.gitignore` file for build artifacts and data directories

### Features
- Container runs Augmentoolkit 3.0 from upstream repository
- Support for environment variable configuration
- Support for custom YAML configuration files
- Automated Redis server management
- Volume mounting for inputs, outputs, configs, and cache
- GPU support via NVIDIA container runtime
- Compatible with Apptainer/Singularity on HPC clusters
- Extensive documentation for UIUC Campus Cluster usage

### Configuration Options
- Content-agnostic design works with any text or PDF input
- Configurable QA generation parameters (variations, passes, chunk size)
- Support for multiple LLM providers via OpenAI-compatible API
- Adjustable concurrency and resource usage
- Optional subset mode for testing and cost optimization

### Documentation
- Detailed setup instructions for cluster deployment
- Examples for interactive and batch execution
- Troubleshooting guide for common issues
- Best practices for optimal results
- Advanced usage scenarios (local models, multi-GPU, etc.)

## Future Plans

### Planned Features
- Pre-built container images on Docker Hub
- Support for additional LLM providers
- Integration with local model servers (vLLM, TGI)
- Advanced pipeline compositions
- Quality metrics and evaluation tools
- Automated output validation
- Multi-node distributed processing support

### Improvements
- Optimized Docker image size
- Enhanced error handling and recovery
- Better logging and monitoring
- Performance optimizations
- Additional example configurations for specific use cases
