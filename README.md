# dokku-maintenance

dokku-maintenance is a plugin for [dokku](https://github.com/progrium/dokku) that gives the ability to enable or disable maintenance mode for an application.

## requirements

- dokku 0.4.x+
- docker 1.8.x

## installation

```shell
# on 0.4.x+
sudo dokku plugin:install https://github.com/dokku/dokku-maintenance.git maintenance
```

## commands

```
$ dokku help
    maintenance <app>                               Display the list of commands
    maintenance:custom-page <app>                   Imports a tarball from stdin; should contain at least maintenance.html
    maintenance:custom-page-export <app>            Exports the current custom page as a tarball to stdout
    maintenance:custom-page-remove <app>            Removes a custom maintenance page and resets to the default page
    maintenance:disable <app>                       Disable app maintenance mode
    maintenance:enable <app>                        Enable app maintenance mode
    maintenance:report [<app>] [<flag>] [--format stdout|json]   Displays a maintenance report for one or more apps
```

## usage

Check maintenance status of my-app

```
# dokku maintenance:report my-app            # Server side
$ ssh dokku@server maintenance:report my-app # Client side

-----> Maintenance status of my-app:
       off
```

The report can also be emitted as JSON for programmatic use:

```
# dokku maintenance:report my-app --format json            # Server side
$ ssh dokku@server maintenance:report my-app --format json # Client side

{"enabled":"false","custom-page-sha256":""}
```

The `custom-page-sha256` key is a content checksum of the app's current custom page (see [custom page checksum](#custom-page-checksum) below). It is empty until a custom page is imported.

Enable maintenance mode for my-app

```
# dokku maintenance:enable my-app            # Server side
$ ssh dokku@server maintenance:enable my-app # Client side

-----> Enabling maintenance mode for ruby-test...
       done
```

Disable maintenance mode for my-app

```
# dokku maintenance:disable my-app            # Server side
$ ssh dokku@server maintenance:disable my-app # Client side

-----> Disabling maintenance mode for ruby-test...
       done
```

Use a custom page for maintenance

```
# dokku maintenance:custom-page my-app < my-custom-page.tar            # Server side
$ ssh dokku@server maintenance:custom-page my-app < my-custom-page.tar # Client side

-----> Importing custom maintenance page...
maintenance.html
image.jpg
       done
```

You have to provide at least a maintenance.html page but you can provide images, css, custom font, etc. if you want. Just write absolute paths in your html and not relative ones (so to serve image.jpg which is at the same level than your maintenance.html page you’ll write “/image.jpg” instead of “./image.jpg” or “image.jpg”).

Importing a custom page replaces the previously stored page in full, so files from an earlier upload are not left behind.

Export the current custom page

```
# dokku maintenance:custom-page-export my-app > my-custom-page.tar            # Server side
$ ssh dokku@server maintenance:custom-page-export my-app > my-custom-page.tar # Client side
```

This is the inverse of `maintenance:custom-page`: it streams the app's stored custom page to stdout as a tarball, so it can be saved or re-applied to another app or server. Piping it straight back in reproduces the same page (and the same `custom-page-sha256`):

```
$ ssh dokku@server maintenance:custom-page-export my-app | ssh dokku@other maintenance:custom-page my-app
```

If the app has no imported custom page, the command still exits successfully but emits an empty archive and prints a notice to stderr rather than the built-in default page. Because it writes a binary archive to stdout, redirect it to a file or pipe it rather than running it directly in a terminal.

Remove a custom page and reset to the default

```
# dokku maintenance:custom-page-remove my-app            # Server side
$ ssh dokku@server maintenance:custom-page-remove my-app # Client side

-----> Removing custom maintenance page for my-app...
       done
```

Removing the custom page clears the stored `custom-page-sha256`. If maintenance mode is enabled at the time, the app immediately falls back to serving the default maintenance page.

## custom page checksum

`maintenance:report` exposes a `custom-page-sha256` key so tools that manage maintenance declaratively (for example [docket](https://github.com/dokku/docket)) can tell whether the stored page already matches the desired one and skip a redundant upload. The value is empty until a custom page is imported, and it is a checksum of the extracted page content rather than the uploaded tar (tar wrappers embed mtimes and entry ordering and are not byte-reproducible).

The checksum cannot be reversed into the page itself, so to recover the actual content a remote client uses `maintenance:custom-page-export` (see [usage](#usage) above), which streams the stored page back out as a tarball. This lets a declarative tool reconstruct a server's custom maintenance page without reading the on-disk files directly.

The checksum is a canonical digest over every stored file: for each regular file, sorted by its path relative to the page directory, a line of `<sha256-of-contents>  <relative-path>` is emitted, and the sha256 of that stream is the reported value. A client can reproduce it over the source directory before uploading:

```shell
cd pagedir
find . -type f | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do
  printf '%s  %s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$f"
done | sha256sum | cut -d' ' -f1
```

Upgrading the plugin records the checksum for any app that already has a custom page, so the value is populated without re-uploading.

## maintenance page storage

The maintenance page and any custom assets are stored under nginx's docroot at `/var/www/dokku-maintenance/<app>` and served from there. Earlier versions served them out of `/home/dokku/<app>`, which nginx workers cannot read on hardened installs where `/home/dokku` is `0700`, producing a `403` instead of the maintenance page. Upgrading the plugin automatically relocates the assets for any app that already has maintenance mode enabled, so no manual action is required.

## let's encrypt

Maintenance mode leaves the `/.well-known/acme-challenge` path untouched, so [dokku-letsencrypt](https://github.com/dokku/dokku-letsencrypt) can still complete the ACME HTTP-01 challenge. Certificate issuance and renewal continue to work while an app is in maintenance mode.
