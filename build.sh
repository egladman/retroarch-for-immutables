#!/usr/bin/env bash

set -o errexit

usage::print() {
    # Usage: usage::print file

    declare -a cmd
    cmd=("${0##*/}")
    if [[ "$0" != "$1" ]]; then
	cmd+=("${1##*/}")
    fi
    
    printf '\n%s: %s\n' "Usage" "${cmd[*]}"
    while read -r line; do
	tmp="$(string::trim "$line")"
	if [[ "$tmp" == "#@"* ]]; then
	   arr=($(string::split "${tmp###@ }" "|"))
	   printf '%s\n' "${arr[0]}"     # argument
	   printf '  %s\n' "${arr[*]:1}" # description
	fi
    done < "$0"
}

init() {
    for f in "lib/"*.sh; do
	source "$f"
    done

    IMAGE_REPOSITORY=${IMAGE_REPOSITORY:-retroarch-rafi}
    IMAGE_VARIANT=${IMAGE_VARIANT:-vanilla}
    IMAGE_TAG=${IMAGE_TAG:-latest}
}

image_tag() {
    printf '%s-%s\n' "${IMAGE_VARIANT:?}" "${IMAGE_TAG:?}"
}

main() {
    init

    local argv
    while [[ $# -ge 0 ]]; do
        argv="$1"

        case "$argv" in
	   #@ h,help | Print this text
	   h|help|-h|--help)
	       usage::print
	       ;;
	   #@ c,clean | Remove temporary files
	   c|clean)
	       rm -rf build
	       ;;
	   #@ i,image | Build image
	   i|image)
	       case "$2" in
		   ''|podman)
		       podman build --tag "${IMAGE_REGISTRY}${IMAGE_REPOSITORY}:$(image_tag)" --target "runtime-${IMAGE_VARIANT}" .
		       ;;
		   docker)
		       docker buildx build --file Containerfile --tag "${IMAGE_REGISTRY}${IMAGE_REPOSITORY}:$(image_tag)" --target "runtime-${IMAGE_VARIANT}" .
		       ;;
		   *)
		       log::fatal "Unsupported: $2"
		       ;;
	       esac
	       ;;
	   #@ r,run | Run image interactively
	   r|run)
	       case "$2" in
		   ''|podman)
		       podman run --volume "${PWD:?}:/src" --rm -it "${IMAGE_REGISTRY}${IMAGE_REPOSITORY}:$(image_tag)" bash
		       ;;
		   docker)
		       docker run --volume "${PWD:?}:/src" --rm -it "${IMAGE_REGISTRY}${IMAGE_REPOSITORY}:$(image_tag)" bash
		       ;;
		   *)
		       log::fatal "Unsupported: $2"
		       ;;
	       esac
	       ;;
	   #@ o,oci-bundle | Build oci compliant image
	   o|oci-bundle)
	       mkdir -p "build/${argv}/rootfs" || true

	       case "$2" in
		   ''|podman)
		       podman build --target "runtime-${IMAGE_VARIANT}" --output "type=local,dest=build/${argv}/rootfs" .
		       ;;
		   docker)
		       docker buildx build --target "runtime-${IMAGE_VARIANT}" --file Containerfile --output "type=local,dest=build/${argv}/rootfs" . 
		       ;;
		   *)
		       log::fatal "Unsupported: $2"
		       ;;
	       esac

	       # oci-runtime-tool generate --output config.json
	       cp config.json "build/${argv}/config.json"
	       printf '%s\n' "build/${argv}"
	       ;;
	   oci-bundle-package)
	       mkdir -p "build/${argv}" || true
	       "$0" oci-bundle
	       tar -czf "build/${argv}/retroarch-rafi.tar" build/oci-bundle
	       printf '%s\n' "build/${argv}"
	       ;;
           *)
	       log::_fatal 128 "Invalid argument: '$argv'. Run $0 help" >&2
               ;;
        esac
	exit 0
    done
}

main "$@"
