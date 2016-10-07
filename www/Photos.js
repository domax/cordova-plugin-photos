var exec = require('cordova/exec');

var Photos = {

	collections: function (options, successCallback, errorCallback) {
		if (typeof options === "function") {
			errorCallback = successCallback;
			successCallback = options;
			options = null;
		}
		exec(successCallback, errorCallback, "Photos", "collections", [options]);
	},

	photos: function (collectionIds, successCallback, errorCallback) {
		switch (typeof collectionIds) {
			case "function":
				errorCallback = successCallback;
				successCallback = collectionIds;
				collectionIds = null;
				break;
			case "string":
				collectionIds = [collectionIds];
				break;
		}
		exec(successCallback, errorCallback, "Photos", "photos", [collectionIds]);
	},

	thumbnail: function (photoId, options, successCallback, errorCallback) {
		if (typeof options === "function") {
			errorCallback = successCallback;
			successCallback = options;
			options = null;
		}
		exec(successCallback, errorCallback, "Photos", "thumbnail", [photoId, options]);
	},

	image: function (photoId, successCallback, errorCallback) {
		exec(successCallback, errorCallback, "Photos", "image", [photoId]);
	}

};

module.exports = Photos;
