#!/usr/bin/env bash
# pypi-resources.sh - Pinned resource stanza generation shared by the PyPI
# generator (lintro-full, winnow) and the binary generator's Intel branch.
#
# generate_pinned_resources installs the release sdist into a throwaway venv,
# walks the installed dependency tree and emits one `resource` stanza per
# dependency (sdist url + sha256 from PyPI JSON), wheel stanzas for the
# configured wheel-only packages, and the matching install block. Every
# dependency ends up url+sha256 pinned so the formula never resolves from
# PyPI at install time.

_PYPI_RESOURCES_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PYPI_RESOURCES_SCRIPT_DIR="$(cd "$_PYPI_RESOURCES_LIB_DIR/.." && pwd)"

# PEP 503 normalization of a PyPI project name: lowercase, runs of "-", "_"
# and "." collapsed to "-". brew audit --strict requires wheel resources to
# carry the normalized project name, so a wheel-only-packages key such as
# pydantic_core renders as pydantic-core (fetch_wheel_info.py applies the
# same rule to the stanza).
# Usage: pypi_canonical_name <package>
pypi_canonical_name() {
	# tr rather than ${var,,}: macOS ships bash 3.2.
	printf '%s' "$1" | sed -E 's/[-_.]+/-/g' | tr '[:upper:]' '[:lower:]'
	printf '\n'
}

# Usage: generate_pinned_resources <package> <tarball-file> <python-version> \
#          '<config-json>' <out-dir> <min-resource-count> [extras] [arch]
#   extras  comma-separated extras installed with the sdist ("" for none)
#   arch    "" for on_arm/on_intel wheel stanzas, or arm|intel for a flat
#           single-architecture stanza (the caller is already inside an
#           on_<arch> block)
# Writes <out-dir>/resources.txt, <out-dir>/wheels.txt and
# <out-dir>/install_resources.txt; the analysis venv lives under <out-dir>.
generate_pinned_resources() {
	local package="$1"
	local tarball_file="$2"
	local python_version="$3"
	local config_json="$4"
	local out_dir="$5"
	local min_resource_count="$6"
	local extras="${7:-}"
	local arch="${8:-}"
	local python_version_nodot="${python_version//./}"
	local script_dir="$_PYPI_RESOURCES_SCRIPT_DIR"

	local homebrew_deps_json wheel_packages_json
	homebrew_deps_json=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('homebrew-deps', [])))" "$config_json")
	wheel_packages_json=$(python3 -c "import json, sys; print(json.dumps(json.loads(sys.argv[1]).get('wheel-only-packages', {})))" "$config_json")

	local homebrew_pkgs=()
	local wheel_pkgs=()
	local line
	while IFS= read -r line; do
		[[ -n "$line" ]] && homebrew_pkgs+=("$line")
	done < <(python3 -c "import json, sys; print('\n'.join(json.loads(sys.argv[1])))" "$homebrew_deps_json")
	while IFS= read -r line; do
		[[ -n "$line" ]] && wheel_pkgs+=("$line")
	done < <(python3 -c "import json, sys; print('\n'.join(json.loads(sys.argv[1]).keys()))" "$wheel_packages_json")

	local analysis_venv="$out_dir/analysis-venv"
	log_info "Creating temporary venv for dependency analysis..."
	python3 -m venv "$analysis_venv"

	# pip accepts extras on a local archive path ("pkg.tar.gz[extra]"), so
	# the extras' dependency closure is part of the analysed tree.
	local install_target="$tarball_file"
	if [[ -n "$extras" ]]; then
		install_target="${tarball_file}[${extras}]"
	fi
	log_info "Installing ${package} from tarball..."
	"$analysis_venv/bin/pip" install --quiet "$install_target"

	local exclude_args=()
	local pkg
	for pkg in ${wheel_pkgs[@]+"${wheel_pkgs[@]}"} ${homebrew_pkgs[@]+"${homebrew_pkgs[@]}"}; do
		exclude_args+=("$pkg")
	done

	log_info "Generating resource stanzas..."
	local site_packages
	site_packages=$("$analysis_venv/bin/python" -c "import site; print(site.getsitepackages()[0])")
	# Markers are evaluated for the formula's target (macOS, the requested
	# CPU), never for the machine running this generator; the root package's
	# extras are followed so extras-only dependencies are pinned too.
	local platform_machine="arm64"
	if [[ "$arch" == "intel" ]]; then
		platform_machine="x86_64"
	fi
	local generate_args=("$script_dir/generate_resources.py" "$package"
		--platform-machine "$platform_machine")
	if [[ -n "$extras" ]]; then
		generate_args+=(--extras "$extras")
	fi
	if ((${#exclude_args[@]})); then
		generate_args+=(--exclude "${exclude_args[@]}")
	fi
	local resources
	resources=$(PYTHONPATH="$site_packages" python3 "${generate_args[@]}")

	local resource_count
	resource_count=$(printf '%s\n' "$resources" | awk '/^  resource / { count++ } END { print count + 0 }')
	if [[ "$resource_count" -lt "$min_resource_count" ]]; then
		log_error "Expected at least ${min_resource_count} resource stanzas but only found ${resource_count}"
		return 1
	fi
	echo "$resources" >"$out_dir/resources.txt"

	log_info "Generating wheel resources..."
	: >"$out_dir/wheels.txt"
	local emitted_wheels=()
	local wheel_pkg wheel_type wheel_comment resolve_from probe_name probe_status wheel_version
	for wheel_pkg in ${wheel_pkgs[@]+"${wheel_pkgs[@]}"}; do
		wheel_type=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], {}).get('type', 'universal'))" "$wheel_packages_json" "$wheel_pkg")
		wheel_comment=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], {}).get('comment', ''))" "$wheel_packages_json" "$wheel_pkg")
		resolve_from=$(python3 -c "import json, sys; print(json.loads(sys.argv[1]).get(sys.argv[2], {}).get('resolve-version-from', ''))" "$wheel_packages_json" "$wheel_pkg")

		# A configured wheel package may be absent from this release's
		# dependency tree; skip it rather than failing the generation.
		# Any other probe failure is fatal so a broken probe cannot
		# silently drop a wheel resource from the formula.
		probe_name="${resolve_from:-$wheel_pkg}"
		probe_status=0
		wheel_version=$("$analysis_venv/bin/python" \
			"$script_dir/probe_dist_version.py" "$probe_name") || probe_status=$?
		if [[ "$probe_status" -eq 3 ]]; then
			log_info "Skipping wheel package ${wheel_pkg}: not in the dependency tree"
			continue
		elif [[ "$probe_status" -ne 0 ]]; then
			log_error "Failed to probe installed version for ${wheel_pkg} (probe name: ${probe_name})"
			return 1
		fi

		local wheel_args=(--type "$wheel_type" --comment "$wheel_comment" --python-version "${python_version_nodot}")
		if [[ "$wheel_type" == "platform" ]]; then
			wheel_args+=(--version "$wheel_version")
			if [[ -n "$arch" ]]; then
				wheel_args+=(--arch "$arch")
			fi
		fi

		python3 "$script_dir/fetch_wheel_info.py" "$wheel_pkg" "${wheel_args[@]}" >>"$out_dir/wheels.txt"
		# Platform wheels are installed out-of-band in the formula;
		# universal wheels go through venv.pip_install like sdists. The
		# stanza is named after the normalized PyPI project name (what
		# fetch_wheel_info.py renders), so the wheel_only list must use
		# the same spelling for resources.reject to match it.
		if [[ "$wheel_type" == "platform" ]]; then
			emitted_wheels+=("$(pypi_canonical_name "$wheel_pkg")")
		fi
	done

	# Blank line between the sdist and wheel resource sections so the
	# rendered formula keeps consistent stanza spacing.
	if [[ -s "$out_dir/wheels.txt" && -s "$out_dir/resources.txt" ]]; then
		printf '\n' | cat - "$out_dir/wheels.txt" >"$out_dir/wheels.txt.tmp"
		mv "$out_dir/wheels.txt.tmp" "$out_dir/wheels.txt"
	fi

	# Platform-wheel packages (pydantic-core needs Rust; scipy/numpy need
	# native toolchains) are installed out-of-band from their prebuilt
	# wheels instead of letting venv.pip_install build them from source.
	if ((${#emitted_wheels[@]})); then
		# %w literal keeps brew style (Style/WordArray) happy.
		local wheel_names_ruby="%w[${emitted_wheels[*]}]"
		cat >"$out_dir/install_resources.txt" <<RUBY
    # Install other resources first (this sets up pip in the venv)
    wheel_only = ${wheel_names_ruby}
    other_resources = resources.reject { |r| wheel_only.include?(r.name) }
    venv.pip_install other_resources

    # Install prebuilt platform wheels out-of-band: building these from
    # source needs heavy native toolchains (Rust, C/Fortran).
    wheel_only.each do |name|
      resource(name).stage do
        wheel = Pathname.pwd.children.find { |f| f.extname == ".whl" }
        odie "#{name} wheel not found in staged resource" if wheel.nil?
        system libexec/"bin/python", "-m", "pip",
               "install", "--no-deps", "--ignore-installed", wheel.to_s
      end
    end
RUBY
	else
		printf '    venv.pip_install resources' >"$out_dir/install_resources.txt"
	fi
}

# Re-indent a rendered block by N spaces (empty lines stay empty).
# Usage: indent_block <spaces> <file>
indent_block() {
	local spaces="$1"
	local file="$2"
	local prefix
	prefix="$(printf '%*s' "$spaces" '')"
	sed -e "s/^\(.\)/${prefix}\1/" "$file" >"$file.tmp"
	mv "$file.tmp" "$file"
}
