var exec = require('cordova/exec');

var Photos = {

	greet: function (name, successCallback, errorCallback) {
		exec(successCallback, errorCallback, "Photos", "greet", [name]);
	}

};

module.exports = Photos;
