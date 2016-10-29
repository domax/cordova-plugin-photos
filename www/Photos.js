/*
 * The MIT License (MIT)
 *
 * Copyright (c) 2016 Maksym Dominichenko
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
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
