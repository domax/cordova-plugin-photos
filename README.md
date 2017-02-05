Cordova Photos Plugin
=====================

This Cordova/Phonegap plugin provides access to photo library on device.

Only iOS and Android are supported for now - please feel free to make your pull requests for new platforms. 

Please note that this plugin deals with _photo images only - not videos or any other media data_.

Contents
--------

1. [Using](#using)
    1. [Install the plugin](#install-the-plugin)
        1. [Android Quirks](#android-quirks)
    2. [Get asset collections/albums - `collections()`][collections]
        1. [Arguments](#arguments)
        2. [Callbacks](#callbacks)
        3. [Examples](#examples)
    3. [Get photo assets - `photos()`][photos]
        1. [Arguments](#arguments-1)
        2. [Callbacks](#callbacks-1)
        3. [Examples](#examples-1)
    4. [Generate a thumbnail of given photo - `thumbnail()`][thumbnail]
        1. [Arguments](#arguments-2)
        2. [Callbacks](#callbacks-2)
        3. [Examples](#examples-2)
    5. [Get original data of photo - `image()`][image]
        1. [Arguments](#arguments-3)
        2. [Callbacks](#callbacks-3)
        3. [Examples](#examples-3)
    6. [Stop long fetching process - `cancel()`][cancel]
        1. [Examples](#examples-4)
2. [More Info](#more-info)

Using
-----

### Install the plugin

    $ cordova plugin add cordova-plugin-photos

or last, fresh version right from Github:

    $ cordova plugin add https://github.com/domax/cordova-plugin-photos.git --save    

#### Android Quirks

Since Android plugin implementation is written on Java 7, you have to switch your project to Java 7 or 8.

If your project is Gradle-driven, just open your project's `build.gradle` script 
and replace `JavaVersion.VERSION_1_6` to `JavaVersion.VERSION_1_7`, like that:
```gradle
	compileOptions {
		sourceCompatibility JavaVersion.VERSION_1_7
		targetCompatibility JavaVersion.VERSION_1_7
	}
```

Or, you can do the same in Android Studio:

_File -> Project Structure -> Modules -> "android" -> Properties_

And select "1.7" or "1.8" in "Source/Target Compatibility" combo boxes.

### Get asset collections/albums - `collections()`

This function requests the list of available photo collections (or albums) depending on platform.

#### Arguments

An optional `option` argument supports only one field `collectionMode` with the following values depending on platforms:

| Value     | Action |
|:--------- |:------ |
| `ROLL`    | Return collection data of device's Camera Roll. **Default**. |
| `SMART`   | Return list of albums that gather and display photos automatically based on criteria you specify. |
| `ALBUMS`  | Return list of all regular albums you create and name. |
| `MOMENTS` | Return list of albums that are automatically generated based on date and location. |

For Android platform `SMART`, `ALBUMS` and `MOMENTS` all work as `ALBUMS`.

#### Callbacks

The resulting structure of argument that comes into `success` callback function is
array of objects with the following structure:

| Property | Type   | Descritpion |
|:-------- |:------:|:----------- |
| `id`     | string | An unique collection identifier that you may use in [`photos()`][photos] method. |
| `name`   | string | A human-friendly name of collection. May not be unique. |

The `failure` callback function takes a string argument with error description.

#### Examples

1. Get all the user's collections/albums:

    ```js
    Photos.collections({"collectionMode": "ALBUMS"},
        function(albums) {
            console.log(albums);
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

### Get photo assets - `photos()`

This function requests the list of photo assets that are available in specified collections.

#### Arguments

1. An optional `collectionIds` argument takes an array of collection IDs that are obtained
	with [`collections()`][collections] method. You may specify only one ID as a string argument.
	<br>If you omit `collectionIds` argument then only assets from device's Camera Roll are returned.
	
2. An optional `options` argument that supports the following keys and according values:

	| Key        | Type | Default | Action |
	|:---------- |:----:|:-------:|:------ |
	| `offset`   | int  | `0`     | Amount of first N photos that should be skipped during fetch. Less than `0` means `0`. |
	| `limit`    | int  | `0`     | Maximal number of photos that should be returned to client at once during fetch. `0` or less means no limit. |
	| `interval` | int  | `30`    | A time interval delay in millis between bundle fetches. Less than `0` means default. |

__Please be warned__ that *`limit` option doesn't stop fetching process* - it just limits the amount
of fetched photo records that are aggregated in plugin for client -
so that if you use `limit` option then you may get several `success` callback calls,
where each of them brings next aggregated bundle of fetched photos.

If you want to stop fetching, you have to explicitly call [`cancel()`][cancel] function,
that will break the running fetch process.

An `interval` option makes sense only if `limit` is specified.
It is useful for some kind of "background" photo fetches (e.g. driven by timer events)
to minimize or even avoid UI freezes. 
An `interval` value less than `30` may cause [`cancel()`][cancel] function to break fetching
not instantly - so that you may receive one more excessive incomplete bundle.

#### Callbacks

The resulting structure of argument that comes into `success` callback function is 
array of objects with the following structure:

| Property      | Type   | Descritpion |
|:------------- |:------:|:----------- |
| `id`          | string | An unique photo identifier that you may use in [`thumbnail()`][thumbnail] or [`image()`][image] methods. |
| `name`        | string | A file name of photo (without path and extension). |
| `timestamp`   | long   | A photo's timestamp in millis from Jan 1, 1970 |
| `date`        | string | A photo's timestamp in [ISO 8601][1] format in `YYYY-MM-dd'T'HH:mm:ssZZZ` pattern. |
| `contentType` | string | Content type of image: e.g. `"image/png"` or `"image/jpeg"`. |
| `width`       | int    | A width of image in pixels. |
| `height`      | int    | A height of image in pixels. |
| `latitude`    | double | An optional geolocation latitude. | 
| `longitude`   | double | An optional geolocation longitude. | 

The `failure` callback function takes a string argument with error description.

#### Examples

1. Get all the photos' metadata that are available in Camera Roll now:

    ```js
    Photos.photos( 
        function(photos) {
            console.log(photos);
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

2. More complicated example with full set of arguments and fetching cancelling:

    ```js
    // Get all photos from albums "XXXXXX" and "YYYYYY"
    // partially, by 10 record bundles, skipping 100 first photos,
    // and only first 2 bundles maximum are needed.
    var bundleSize = 10;
    var bundleMax = 2;
    var bundle = 0;
    Photos.photos(["XXXXXX", "YYYYYY"],
        {"offset": 100, "limit": bundleSize},
        function(photos) {
            ++bundle;
            // We need only 2 bundles, so let's stop fetching
            // as soon as possible we've got them
            if (bundle >= bundleMax) 
                Photos.cancel();
            // This code will be called several times 
            // in case if amount of your photos is at least 
            // 100 (offset) + 10 (limit) = 110
            console.log("Bundle #" + bundle + ": " + JSON.stringify(photos));
            if (photos.length < bundleSize) {
                // It is guaranteed that if limit option is set 
                // then there will be the last call with photos.length < bundleSize,
                // so that you may get the last call with photos.length == 0
                console.log("That's it - no more bundles");
            }
        }, console.error);
    ```

### Generate a thumbnail of given photo - `thumbnail()`

This function requests generating a scaled (reduced) image from its original data.
Each supported platform uses its own specific tools to make scaled images - including optimizations and caching.

Despite the fact that multiple parallel calls to this function is quite safe, 
use it with caution - if you will request generating a lot of thumbnails simultaneously, 
all of them are processed by device in parallel threads, so you may suffer from big delays.

Thumbnails are returned only as JPEG data, even if source image is in other format (e.g. PNG screenshot).

#### Arguments

1. A required `photoId` argument that is a photo ID you obtained by [`photos()`][photos] function.
2. An optional `options` argument that supports the following keys and according values:

	| Key         | Type    | Default | Action |
	|:----------- |:-------:|:-------:|:------ |
	| `asDataUrl` | boolean | `false` | Whether return thumbnail data as [Data URL][2] (`true`) or as [ArrayBuffer][3]. | 
	| `dimension` | int     | `120`   | A maximal size of thumbnail both for width and height (aspect ratio will be kept). |
	| `quality`   | int     | `80`    | A [JPEG][4] quality factor from `100` (best quality) to `1` (least quality). |

*__Please note__ that you have to use combination of `asDataUrl:true` and `dimension` carefully:
device's WebViews have limitations in processing large [Data URL][2]s.*

#### Callbacks

The resulting data of argument that comes into `success` callback function
depends on `options.asDataUrl` flag:
- if it's `true` then data is returned as string in [Data URL][2] format
    that you e.g. may use as `src` attribute in `img` tag;
- otherwise data is returned as an [ArrayBuffer][3] that you may:
    * render as [blob-url][11] in `src` attribute of `img` tag;
    * draw in canvas (you'll need [JPEG decoder][8] for that);
    * save it as a file with [cordova-plugin-file][5].

The `failure` callback function takes a string argument with error description.

#### Examples

1. Generate a thumbnail as [ArrayBuffer][3] and render it using [Blob][10] and a [blob-url][11] as image source:

    ```js
    // Do not forget to extend your Content-Security-Policy with explicit 'img-src blob:' rule
    Photos.thumbnail("XXXXXX",
        function(data) {
            var blob = new Blob([data], {"type": "image/jpeg"});
            var domURL = window.URL || window.webkitURL;
            document.getElementsByTagName("img")[0].src = domURL.createObjectURL(blob);
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

2. Generate and render a thumbnail as [Data URL][2] with maximal dimension by width or height of 300 pixels:

    ```js
    // Generate a thumbnail of photo with ID "XXXXXX" as data URL
    // with maximal dimension by width or height of 300 pixels
    // and JPEG quality of 70:
    Photos.thumbnail("XXXXXX",
        {"asDataUrl": true, "dimension": 300, "quality": 70},
        function(data) {
            document.getElementsByTagName("img")[0].src = data;
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

3. Generate a thumbnail as [ArrayBuffer][3], store it as a temporary file on device
   and then render it as an image source (requires [cordova-plugin-file][5] to be installed):

    ```js
    var photoId = "XXXXXX";
    Photos.thumbnail(photoId, {"dimension": 300, "quality": 70},
        function(data) {
            requestFileSystem(LocalFileSystem.TEMPORARY, 1024*1024, function(fs) {
                var fn = photoId.replace(/\W/g, "_") + "-thumb.jpeg";
                fs.root.getFile(fn, {"create": true, "exclusive": false}, function(entry) {
                    entry.createWriter(function(writer) {
                        writer.onwriteend = function() {
                            document.getElementsByTagName("img")[0].src = entry.toURL();
                        };
                        writer.onerror = console.error;
                        writer.write(new Blob([data], {"type": "image/jpeg"}));
                    }, console.error);
                }, console.error);
            }, console.error);
        }, console.error);
    ```

   See full simple caching example in [`image()` examples](#examples-3).

### Get original data of photo - `image()`

This function requests original data of specified photo.
The content type of returned data may be different: 
you may pick it up in `contentType` property of results of [`photos()`][photos] function.

#### Arguments

A required `photoId` argument that is a photo ID you obtained by [`photos()`][photos] function.

#### Callbacks

The resulting data of argument that comes into `success` callback function
is an [ArrayBuffer][3] that you may:
* render as [blob-url][11] in `src` attribute of `img` tag;
* draw in canvas (you'll need [JPEG decoder][8] for `image/jpeg` data or [PNG decoder][9] for `image/png` data);
* save it as a file with [cordova-plugin-file][5].

The `failure` callback function takes a string argument with error description.

#### Examples

1. Render [ArrayBuffer][3] image using [Blob][10] and a [blob-url][11] as image source:

    ```js
    // Do not forget to extend your Content-Security-Policy with explicit 'img-src blob:' rule
    var photo = {"id": "XXXXXX", "contentType": "image/jpeg"}; // Get it from Photos.photos()
    Photos.image(photo.id,
        function(data) {
            var blob = new Blob([data], {"type": photo.contentType});
            var domURL = window.URL || window.webkitURL;
            document.getElementsByTagName("img")[0].src = domURL.createObjectURL(blob);
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

2. Draw [ArrayBuffer][3] PNG screenshot into canvas (requires [PNG decoder][9] to be included):

    ```js
    Photos.image("XXXXXX",
        function(data) {
            // you know MIME type from Photos.photos() result
            var png = new PNG(new Uint8Array(data));
            png.render(document.getElementsByTagName("canvas")[0]);
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

3. Draw [ArrayBuffer][3] JPEG photo into canvas (requires [JPEG decoder][8] to be included):

    ```js
    Photos.image("XXXXXX",
        function(data) {
            // you know MIME type from Photos.photos() result
            var parser = new JpegDecoder();
            parser.parse(new Uint8Array(data));
            var numComponents = parser.numComponents;
            var width = parser.width;
            var height = parser.height;
            var decoded = parser.getData(width, height);
            var canvas = document.getElementsByTagName("canvas")[0];
            canvas.width = width;
            canvas.height = height;
            var ctx = canvas.getContext("2d");
            var imageData = ctx.createImageData(width, height);
            var imageBytes = imageData.data;
            for (var i = 0, j = 0, ii = width * height * 4; i < ii;) {
                imageBytes[i++] = decoded[j++];
                imageBytes[i++] = numComponents === 3 ? decoded[j++] : decoded[j - 1];
                imageBytes[i++] = numComponents === 3 ? decoded[j++] : decoded[j - 1];
                imageBytes[i++] = 255;
            }
            ctx.putImageData(imageData, 0, 0);
        },
        function(error) {
            console.error("Error: " + error);
        });
    ```

4. Full simple caching solution of getting and rendering original image
   as an image source (requires [cordova-plugin-file][5] to be installed):

    ```js
    var photo = {"id": "XXXXXX", "contentType": "image/jpeg"}; // Get it from Photos.photos()
    var img = document.getElementsByTagName("img")[0];     // Get it from your DOM
    requestFileSystem(LocalFileSystem.TEMPORARY, 3*1024*1024, function(fs) {
        fs.root.getFile(
            photo.id.replace(/\W/g, "_") + photo.contentType.replace(/^image\//, "."),
            {create: true, exclusive: false},
            function(entry) {
                entry.file(function(file) {
                    if (file.size == 0) {
                        Photos.image(photo.id, function(data) {
                            entry.createWriter(function(writer) {
                                writer.onwriteend = function() {img.src = entry.toURL()};
                                writer.onerror = console.error;
                                writer.write(new Blob([data], {"type": photo.contentType}));
                            }, console.error);
                        }, console.error);
                    } else img.src = entry.toURL();
                }, console.error);
            }, console.error);
    }, console.error);
    
    ```

### Stop long fetching process - `cancel()`

This is no-argument function that simply breaks any long fetching process that runs in the background.
Though, it is used with only [`photos()`][photos] function now.

#### Examples

Please, see [`photos()` examples](#examples-1) for details.

More Info
---------

For more information on setting up Cordova see [the documentation][6].

For more info on plugins see the [Plugin Development Guide][7].

[collections]: #get-asset-collectionsalbums---collections
[photos]: #get-photo-assets---photos
[thumbnail]: #generate-a-thumbnail-of-given-photo---thumbnail
[image]: #get-original-data-of-photo---image
[cancel]: #stop-long-fetching-process---cancel

[1]: https://www.w3.org/TR/NOTE-datetime
[2]: https://en.wikipedia.org/wiki/Data_URI_scheme
[3]: https://www.html5rocks.com/en/tutorials/webgl/typed_arrays/
[4]: https://en.wikipedia.org/wiki/JPEG
[5]: https://cordova.apache.org/docs/en/latest/reference/cordova-plugin-file/#write-to-a-file-
[6]: https://cordova.apache.org/docs/en/latest/guide/cli/
[7]: https://cordova.apache.org/docs/en/latest/guide/hybrid/plugins/
[8]: https://github.com/notmasteryet/jpgjs
[9]: https://github.com/devongovett/png.js
[10]: https://developer.mozilla.org/en-US/docs/Web/API/Blob
[11]: https://developer.mozilla.org/en-US/docs/Web/API/URL/createObjectURL