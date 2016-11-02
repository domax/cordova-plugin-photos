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
| `id`     | string | An unique collection identifier that you may use in [`photos()`][h2] method. |
| `name`   | string | A human-friendly name of collection. May not be unique. |

The `failure` callback function takes a string argument with error description.

#### Example
```js
// Get all the user's collections/albums
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
	with [`collections()`][h1] method. You may specify only one ID as a string argument.
	<br>If you omit `collectionIds` argument then only assets from device's Camera Roll are returned.
	
2. An optional `options` argument that supports the following keys and according values:

	| Key      | Type | Default | Action |
	|:-------- |:----:|:-------:|:------ |
	| `offset` | int  | `0`     | Amount of first N photos that should be skipped during fetch. |
	| `limit`  | int  | `0`     | Maximal number of photos that should be returned to client at once during fetch. |

__Please be warned__ that *`limit` option doesn't stop fetching process* - it just limits the amount
of fetched photo records that are aggregated in plugin for client.
So that if you use `limit` option then you may get several `success` callback calls,
where each of them brings to you next aggregated bundle of fetched photos.

If you want to stop fetching, you have to explicitly call [`cancel()`][h5] function,
that will break the running fetch process.

#### Callbacks

The resulting structure of argument that comes into `success` callback function is 
array of objects with the following structure:

| Property      | Type   | Descritpion |
|:------------- |:------:|:----------- |
| `id`          | string | An unique photo identifier that you may use in [`thumbnail()`][h3] or [`image()`][h4] methods. |
| `name`        | string | A file name of photo (without path and extension). |
| `date`        | string | A photo's timestamp in [ISO 8601][1] format in `YYYY-MM-dd'T'HH:mm:ssZZZ` pattern. |
| `contentType` | string | Content type of image: e.g. `"image/png"` or `"image/jpeg"`. |
| `width`       | int    | A width of image in pixels. |
| `height`      | int    | A height of image in pixels. |
| `latitude`    | double | An optional geolocation latitude. | 
| `longitude`   | double | An optional geolocation longitude. | 

The `failure` callback function takes a string argument with error description.

#### Examples

```js
// 1: Get all the photos' metadata that are available in Camera Roll now
Photos.photos( 
	function(photos) {
		console.log(photos);
	},
	function(error) {
		console.error("Error: " + error);
	});
```

More complicated example with full set of arguments and fetching cancelling:

```js
// 2. Get all photos from albums "XXXXXX" and "YYYYYY"
//    partially, by 10 record bundles, skipping 100 first photos,
//    and only first 2 bundles maximum is needed.
var bundleSize = 10;
var bundleMax = 2;
var bundle = 0;
Photos.photos(
	["XXXXXX", "YYYYYY"],
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
	},
	function(error) {
		console.error("Error: " + error);
	});
```

### Generate a thumbnail of given photo - `thumbnail()`

This function requests generating a scaled (reduced) image from its original data.
Each supported platform uses its own specific tools to make scaled images - including optimizations and caching.

Despite the fact that multiple parallel calls to this function is quite safe, 
use it with caution - if you will request generating a lot of thumbnails simultaneously, 
all of them are processed by device in parallel threads, so you may suffer from big delays.

Thumbnails are returned only as JPEG data, even if source image is in other format (e.g. PNG screenshot).

#### Arguments

1. A required `photoId` argument that is a photo ID you obtained by [`photos()`][h2] function.
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
- otherwise data is returned as an [ArrayBuffer][3] that you may use in canvas 
	or save it as a file with [cordova-plugin-file][5]. 

The `failure` callback function takes a string argument with error description.

#### Example
```js
// Generate a thumbnail of photo with ID "XXXXXX" as data URL
// with maximal dimension by width or height of 300 pixels
// and JPEG guality of 70:
Photos.thumbnail("XXXXXX",
	{"asDataUrl": true, "dimension":300, "quality":70},
	function(data) {
		console.log(data);
	},
	function(error) {
		console.error("Error: " + error);
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

#### Example
```js
// Get the original data of photo with ID "XXXXXX": 
Photos.image("XXXXXX",
	function(data) {
		console.log(data);
	},
	function(error) {
		console.error("Error: " + error);
	});
```

### Stop long fetching process - `cancel()`

This is no-argument function that simply breaks any long fetching process that runs in the background.
Though, it is used with only [`photos()`][h2] function now.

#### Example

Please, see [`photos()`][h2] examples for details.

More Info
---------

For more information on setting up Cordova see [the documentation][6].

For more info on plugins see the [Plugin Development Guide][7].

[h1]: #get-asset-collectionsalbums---collections
[h2]: #get-photo-assets---photos
[h3]: #generate-a-thumbnail-of-given-photo---thumbnail
[h4]: #get-original-data-of-photo---image
[h5]: #stop-long-fetching-process---cancel

[1]: https://www.w3.org/TR/NOTE-datetime
[2]: https://en.wikipedia.org/wiki/Data_URI_scheme
[3]: https://www.html5rocks.com/en/tutorials/webgl/typed_arrays/
[4]: https://en.wikipedia.org/wiki/JPEG
[5]: https://cordova.apache.org/docs/en/latest/reference/cordova-plugin-file/#write-to-a-file-
[6]: https://cordova.apache.org/docs/en/latest/guide/cli/
[7]: https://cordova.apache.org/docs/en/latest/guide/hybrid/plugins/
