# retroarch-immutables

## Development

1. Build docker image and start container with interactive session

```
./build.sh
./build.sh run
```

2. Run command(s) inside container. The source code is bind mounted into the working directory

```
./main help
```

## Release

The project is packaged as an OCI compliant image therefore can be ran by most container runtimes.

1. Build oci image

```
./build.sh oci-bundle
```

2. Run using systemd-nspawn

```
./launch.sh build/oci-bundle
```

*Note:* The oci bundle argument can either be a directory or `.tar` file
