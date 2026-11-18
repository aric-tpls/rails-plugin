_default:
    @just --list

# Build the generator image once
build:
    docker build -t rails-plugin-generator {{justfile_directory()}}

# Generate a new plugin into the CURRENT directory (must be empty).
# Usage: cd <target-dir> && just -f /path/to/rails-plugin/justfile new
new:
    #!/usr/bin/env bash
    set -euo pipefail
    target="$PWD"
    if [ -n "$(ls -A "$target" | grep -v '^\.git$')" ]; then
      echo "Error: target directory is not empty: $target" >&2
      exit 1
    fi
    exec docker run --rm -it \
      -v "{{justfile_directory()}}:/template:ro" \
      -v "$target:/output" \
      rails-plugin-generator \
      rails plugin new /output --mountable --skip-bundle -m /template/template.rb

# Shell into the generator image (for debugging)
sh:
    docker run --rm -it \
      -v "{{justfile_directory()}}:/template:ro" \
      -v "$PWD:/output" \
      rails-plugin-generator bash
