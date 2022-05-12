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
    maintenance <app>                               Display the current maintenance status of app
    maintenance:custom-page <app>                   Imports a tarball from stdin; should contain at least maintenance.html
    maintenance:disable <app>                       Disable app maintenance mode
    maintenance:enable <app>                        Enable app
     maintenance mode
```

## usage

Check maintenance status of my-app

```
# dokku maintenance my-app            # Server side
$ ssh dokku@server maintenance my-app # Client side

-----> Maintenance status of my-app:
       off
```

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
