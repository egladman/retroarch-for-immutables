# retroarch-for-immutables

## Quickstart

### systemd-nspawn

If you're linux distribution ships with a modern version of systemd then chances are this is already installed.

1. Run container

```
./run-nspawn.sh <path/to/oci-bundle>
```

### Docker

todo

### Podman

todo

## Development

### Dependencies

- Docker or Podman

### Build

1. Build docker image and start container with interactive session

```
./build.sh
./build.sh run
```

2. Run command(s) inside container. The source code is bind mounted into the working directory

```
./main help
```

## Release/Packaging

The project is packaged as an OCI compliant image therefore can be ran by most container runtimes.

1. Build oci image

```
./build.sh oci-bundle-package
```

A `.tar` file will be written to directory `build/oci-bundle-package`
