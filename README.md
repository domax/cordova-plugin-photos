Cordova Photos Plugin
=====================

TODO plugin description

Using
-----

### Clone the plugin

    $ git clone git@home.dominichenko.com:Captimize/cordova-plugin-photos.git

### Install the plugin

    $ cd myProject
    $ cordova plugin add ../cordova-plugin-photos

Edit `www/js/Photos.js` and add the following code inside `onDeviceReady`

```js
    var success = function(message) {
        alert(message);
    }

    var failure = function() {
        alert("Error calling Photos Plugin");
    }

    hello.greet("World", success, failure);
```

More Info
---------

For more information on setting up Cordova see [the documentation](http://cordova.apache.org/docs/en/4.0.0/guide_cli_index.md.html#The%20Command-Line%20Interface)

For more info on plugins see the [Plugin Development Guide](http://cordova.apache.org/docs/en/4.0.0/guide_hybrid_plugins_index.md.html#Plugin%20Development%20Guide)
