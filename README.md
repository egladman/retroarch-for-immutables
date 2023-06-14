# retroarch-for-immutables

Yet another way to run [RetroArch](https://github.com/libretro/RetroArch). Install retroarch (and various libretro cores) to an immutable system non-destructivly.

## Quickstart

### systemd-nspawn

If you're linux distribution ships with a modern version of systemd then chances are this is already installed.

1. Run container

```
./run-nspawn.sh <path/to/oci-bundle>
```

## Commonly Asked Questions

### Should I use this?

Nope. Use the [official flatpak](https://github.com/flathub/org.libretro.RetroArch).

I was curious how one would go about running a GUI using [systemd-nspawn](https://www.freedesktop.org/software/systemd/man/systemd-nspawn.html). 
So against my better judgement, I wrote it. While nspawn isn't the best tool for job it's often already present on the user's machine. There's huge
implications to shipping software without requiring additonal dependencies to be installed.

Still not convinced? Projects like Flatpak was explicity written to address the inherit packaging challenges faced on the desktop.

- Dedupped:
  Flatpak dependencies are shared across packages. So they take up less storage when compared to OCI images/bundles.
- Rootless:
  Flatpak is able to run unprivileged by utilizing [user namespaces](https://www.redhat.com/sysadmin/building-container-namespaces) (via [bubblewrap](https://github.com/containers/bubblewrap)) rather than [setting the effective user](https://www.gnu.org/software/libc/manual/html_node/Setuid-Program-Example.html) by calling `setuid`.

Additonal reading:

- https://docs.flatpak.org/en/latest/under-the-hood.html

## Development

### Dependencies

- Docker or Podman

### Build

1. Build devel image and start container with interactive session

```
IMAGE_VARIANT=devel ./build.sh
IMAGE_VARIANT=devel ./build.sh run
```

2. Run command(s) inside container. The source code is bind mounted into `/src/project`

```
./main help
```

## Release/Packaging

The project is packaged as an [OCI runtime bundle](https://github.com/opencontainers/runtime-spec/blob/master/bundle.md) therefore can be ran by most container runtimes with minimal effort.

1. Build oci runtime bundle

```
./build.sh oci-bundle
tar -czf build/retroarch-for-immutables.tar build/oci-bundle
```

A `.tar` file will be written to directory `build/oci-bundle-package`
