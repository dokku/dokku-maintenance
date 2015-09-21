# dokku-maintenance

dokku-maintenance is a plugin for [dokku][dokku] that gives the ability to enable or disable maintenance mode for an application.

## Installation

```sh
# dokku 0.3.26
$ sudo git clone https://github.com/Flink/dokku-maintenance.git /var/lib/dokku/plugins/maintenance

# dokku 0.4+
$ dokku plugin:install https://github.com/Flink/dokku-maintenance.git
```

## Commands

```
$ dokku help
    maintenance <app>                               Display the current maintenance status of app
    maintenance:custom-page <app>                   Imports a tarball from stdin; should contain at least maintenance.html
    maintenance:off <app>                           Take the app out of maintenance mode
    maintenance:on <app>                            Put the app into maintenance mode
```

## Usage

Check maintenance status of my-app
```
# dokku maintenance my-app            # Server side
$ ssh dokku@server maintenance my-app # Client side

-----> Maintenance status of my-app:
       off
```

Enable maintenance mode for my-app
```
# dokku maintenance:on my-app            # Server side
$ ssh dokku@server maintenance:on my-app # Client side

-----> Enabling maintenance mode for ruby-test...
       done
```

Disable maintenance mode for my-app
```
# dokku maintenance:off my-app            # Server side
$ ssh dokku@server maintenance:off my-app # Client side

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

## License

This plugin is released under the MIT license. See the file [LICENSE](LICENSE).

[dokku]: https://github.com/progrium/dokku
