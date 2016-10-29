Cordova Photos Plugin
=====================

This Cordova/Phonegap plugin provides access to photo library on device.

Only iOS and Android are supported for now - please feel free to make your pull requests for new platforms. 

Please note that this plugin deals with _photo images only - not videos or any other media data_.

Using
-----

### Install the plugin

    $ cordova plugin add cordova-plugin-photos

or last, fresh version right from Github:

    $ cordova plugin add https://github.com/domax/cordova-plugin-photos.git --save    

### Get asset collections/albums - `collections()`

This function requests the list of available photo collections (or albums) depending on platform.

#### Arguments

An optional `option` argument supports only one field `collectionMode` with the following values depending on platforms:

| Value | Platform | Action |
|:----- |:--------:|:------ |
| `ROLL` | iOS, Android | Return collection data of device's Camera Roll. **Default**. |
| `SMART` | iOS | Return list of albums that gather and display photos automatically based on criteria you specify. |
| `ALBUMS` | iOS | Return list of regular albums you create and name. |
| `MOMENTS` | iOS | Return list of albums that are automatically generated based on date and location. |

#### Callbacks

The resulting structure of argument that comes into `success` callback function is
array of objects with the following structure:

| Property | Type | Descritpion |
|:-------- |:----:|:----------- |
| `id` | string | An unique collection identifier that you may use in [`photos()`][h2] method. |
| `name` | string | A human-friendly name of collection. May not be unique. |

The `failure` callback function takes a string argument with error description.

#### Example:
```js
// Get all the iOS collections/albums that represent groups of photos orgnised by date and location
Photos.collections({"collectionMode": "MOMENTS"},
	function(albums) {
		console.log("Albums: " + JSON.stringify(albums));
	},
	function(error) {
		console.log("Error: " + error);
	});
```

### Get photo assets - `photos()`

This function requests the list of photo assets that are available in specified collections.

#### Arguments

An optional `collectionIds` argument takes an array of collection IDs that are obtained
with [`collections()`][h1] method. You may specify only one ID as a string argument.

If you omit `collectionIds` argument then only assets from device's Camera Roll are returned. 

#### Callbacks

The resulting structure of argument that comes into `success` callback function is 
array of objects with the following structure:

| Property | Type | Descritpion |
|:-------- |:----:|:----------- |
| `id` | string | An unique photo identifier that you may use in [`thumbnail()`][h3] or [`image()`][h4] methods. |
| `name` | string | A file name of photo (without path and extension). |
| `date` | string | A photo's timestamp in [ISO 8601][1] format in `YYYY-MM-dd'T'HH:mm:ssZZZ` pattern. |
| `contentType` | string | Content type of image: e.g. `"image/png"` or `"image/jpeg"`. |
| `width` | int | A width of image in pixels. |
| `height` | int | A height of image in pixels. |
| `latitude` | double | An optional geolocation latitude. | 
| `longitude` | double | An optional geolocation longitude. | 

The `failure` callback function takes a string argument with error description.

#### Example:
```js
// Get all the photos' metadata that are available in Camera Roll now
Photos.photos( 
	function(photos) {
		console.log("Photos: " + JSON.stringify(photos));
	},
	function(error) {
		console.log("Error: " + error);
	});
```

### Generate a thumbnail of given photo - `thumbnail()`

This function requests generating a scaled (reduced) image from its original data.
Each supported platform uses its own specific tools to make scaled images - including optimizations and caching.

Thumbnails are returned only as JPEG data, even if source image is in PNG format (e.g. screenshot).

#### Arguments

1. A required `photoId` argument that is a photo ID you obtained by [`photos()`][h2] function.
2. An optional `options` argument that supports the following keys and according values:

	| Key | Type | Default | Action |
	|:--- |:----:|:-------:|:------ |
	| `asDataUrl` | boolean | `false` | Whether return thumbnail data as [Data URL][2] (`true`) or as [ArrayBuffer][3]. | 
	| `dimension` | int | `120` | A maximal size of thumbnail both for width and height (aspect ratio will be kept). |
	| `quality` | int | `80` | A [JPEG][4] quality factor from `100` (best quality) to `1` (least quality). |

*__Please note__ that you have to use combination of `asDataUrl:true` and `dimension` carefully:
device's WebViews have limitations in processing large [Data URL][2]s.*

#### Callbacks

The resulting data of argument that comes into `success` callback function
depends on `options.asDataUrl` flag:
- if it's `true` then data is returned as string in [Data URL][2] format
	that you e.g. may use as `src` attribute in `img` tag;
- otherwise data is returned as an [ArrayBuffer][3] that you may use in canvas 
	or save it as a file with [cordova-plugin-file][5]. 

The `failure` callback function takes a string argument with error description.

#### Example:
```js
// Generate a thumbnail of photo with ID "XXXXXX" 
// with maximal dimension by width or height of 300 pixels
// and JPEG guality of 70:
Photos.thumbnail("XXXXXX",
	{"asDataUrl": true, "dimension":300, "quality":70},
	function(data) {
		console.log("Thumbnail: " + data);
	},
	function(error) {
		console.log("Error: " + error);
	});
```

### Get original data of photo - `image()`

This function requests original data of specified photo.
The content type of returned data may be different: 
you may pick it up in `contentType` property of results of [`photos()`][h2] function.

#### Arguments

A required `photoId` argument that is a photo ID you obtained by [`photos()`][h2] function.

#### Callbacks

The resulting data of argument that comes into `success` callback function
is an [ArrayBuffer][3] that you may use in canvas or save it as a file with [cordova-plugin-file][5]. 

The `failure` callback function takes a string argument with error description.

#### Example:
```js
// Get the original data of photo with ID "XXXXXX": 
Photos.image("XXXXXX",
	function(data) {
		console.log("Photo: " + data);
	},
	function(error) {
		console.log("Error: " + error);
	});
```

More Info
---------

For more information on setting up Cordova see [the documentation][6].

For more info on plugins see the [Plugin Development Guide][7].

[1]: https://www.w3.org/TR/NOTE-datetime
[2]: https://en.wikipedia.org/wiki/Data_URI_scheme
[3]: https://www.html5rocks.com/en/tutorials/webgl/typed_arrays/
[4]: https://en.wikipedia.org/wiki/JPEG
[5]: https://cordova.apache.org/docs/en/latest/reference/cordova-plugin-file/
[6]: https://cordova.apache.org/docs/en/latest/guide/cli/
[7]: https://cordova.apache.org/docs/en/latest/guide/hybrid/plugins/

[h1]: #get-asset-collectionsalbums---collections
[h2]: #get-photo-assets---photos
[h3]: #generate-a-thumbnail-of-given-photo---thumbnail
[h4]: #get-original-data-of-photo---image
