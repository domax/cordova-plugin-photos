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
package com.domax.cordova;

import android.Manifest;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.net.Uri;
import android.util.Base64;
import android.util.Log;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import static android.provider.MediaStore.Images.Media.*;
import static android.provider.MediaStore.Images.Thumbnails.MINI_KIND;
import static android.provider.MediaStore.Images.Thumbnails.getThumbnail;

import java.io.ByteArrayOutputStream;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.List;
import java.util.Locale;

/**
 * Useful links:
 * <ul>
 * <li><a href='https://developer.android.com/reference/android/provider/MediaStore.Images.Media.html'>MediaStore.Images.Media</a></li>
 * <li><a href='https://developer.android.com/reference/android/provider/MediaStore.Images.Thumbnails.html'>MediaStore.Images.Thumbnails</a></li>
 * </ul>
 */
public class Photos extends CordovaPlugin {

	private static final String TAG = Photos.class.getSimpleName();

	private static final String P_ID = "id";
	private static final String P_NAME = "name";
	private static final String P_WIDTH = "width";
	private static final String P_HEIGHT = "height";
	private static final String P_LAT = "latitude";
	private static final String P_LON = "longitude";
	private static final String P_DATE = "date";
	private static final String P_TS = "timestamp";
	private static final String P_TYPE = "contentType";

	private static final String P_SIZE = "dimension";
	private static final String P_QUALITY = "quality";
	private static final String P_AS_DATAURL = "asDataUrl";

	private static final String P_C_MODE = "collectionMode";
	private static final String P_C_MODE_ROLL = "ROLL";
	private static final String P_C_MODE_SMART = "SMART";
	private static final String P_C_MODE_ALBUMS = "ALBUMS";
	private static final String P_C_MODE_MOMENTS = "MOMENTS";

	private static final String P_LIST_OFFSET = "offset";
	private static final String P_LIST_LIMIT = "limit";
	private static final String P_LIST_INTERVAL = "interval";

	private static final String T_DATA_URL = "data:image/jpeg;base64,";
	private static final String T_DATE_FORMAT = "yyyy-MM-dd'T'HH:mm:ssZZZZZ";

	private static final String BN_CAMERA = "Camera";

	private static final String E_PERMISSION = "Read external storage permission required";
	private static final String E_COLLECTION_MODE = "Unsupported collection mode";
	private static final String E_PHOTO_ID_UNDEF = "Photo ID is undefined";
	private static final String E_PHOTO_ID_WRONG = "Photo with specified ID wasn't found";
	private static final String E_PHOTO_BUSY = "Fetching of photo assets is in progress";

	private static final int DEF_SIZE = 120;
	private static final int DEF_QUALITY = 80;

	private static final SimpleDateFormat DF = new SimpleDateFormat(T_DATE_FORMAT, Locale.getDefault());

	@SuppressWarnings("MismatchedReadAndWriteOfArray")
	private static final String[] PRJ_COLLECTIONS =
			new String[]{"DISTINCT " + BUCKET_ID, BUCKET_DISPLAY_NAME};

	@SuppressWarnings("MismatchedReadAndWriteOfArray")
	private static final String[] PRJ_PHOTOS =
			new String[]{_ID, TITLE, DATE_TAKEN, LATITUDE, LONGITUDE, WIDTH, HEIGHT};

	private String action;
	private JSONArray data;
	private CallbackContext permissionCallbackContext;
	private volatile CallbackContext photosCallbackContext;

	@Override
	public boolean execute(
			String action, final JSONArray data, final CallbackContext callbackContext) throws JSONException {
		switch (action) {
			case "collections":
				if (checkPermission(action, data, callbackContext))
					cordova.getThreadPool().execute(new Runnable() {
						@Override
						public void run() {
							collections(data.optJSONObject(0), callbackContext);
						}
					});
				break;
			case "photos":
				if (checkPermission(action, data, callbackContext))
					cordova.getThreadPool().execute(new Runnable() {
						@Override
						public void run() {
							photos(data.optJSONArray(0), data.optJSONObject(1), callbackContext);
						}
					});
				break;
			case "thumbnail":
				if (checkPermission(action, data, callbackContext))
					cordova.getThreadPool().execute(new Runnable() {
						@Override
						public void run() {
							thumbnail(data.optString(0, null), data.optJSONObject(1), callbackContext);
						}
					});
				break;
			case "image":
				if (checkPermission(action, data, callbackContext))
					cordova.getThreadPool().execute(new Runnable() {
						@Override
						public void run() {
							image(data.optString(0, null), callbackContext);
						}
					});
				break;
			case "cancel":
				cancel(callbackContext);
				break;
			default:
				return false;
		}
		return true;
	}

	private boolean checkPermission(String action, JSONArray data, final CallbackContext callbackContext) {
		if (!PermissionHelper.hasPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE)) {
			this.action = action;
			this.data = data;
			this.permissionCallbackContext = callbackContext;
			PermissionHelper.requestPermission(this, 0, Manifest.permission.READ_EXTERNAL_STORAGE);
			return false;
		}
		return true;
	}

	@Override
	public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
		for (int grantResult : grantResults) {
			if (grantResult == PackageManager.PERMISSION_DENIED) {
				this.permissionCallbackContext.error(E_PERMISSION);
				return;
			}
		}
		execute(action, data, permissionCallbackContext);
	}

	private void collections(final JSONObject options, final CallbackContext callbackContext) {
		final String selection;
		final String[] selectionArgs;
		switch (options != null ? options.optString(P_C_MODE, P_C_MODE_ROLL) : P_C_MODE_ROLL) {
			case P_C_MODE_ROLL:
				selection = BUCKET_DISPLAY_NAME + "=?";
				selectionArgs = new String[]{BN_CAMERA};
				break;
			case P_C_MODE_SMART:
			case P_C_MODE_ALBUMS:
			case P_C_MODE_MOMENTS:
				selection = null;
				selectionArgs = null;
				break;
			default:
				callbackContext.error(E_COLLECTION_MODE);
				return;
		}
		try (final Cursor cursor = query(
				cordova.getActivity().getContentResolver(),
				EXTERNAL_CONTENT_URI,
				PRJ_COLLECTIONS,
				selection,
				selectionArgs,
				DEFAULT_SORT_ORDER)) {
			final JSONArray result = new JSONArray();
			if (cursor.moveToFirst()) {
				do {
					final JSONObject item = new JSONObject();
					item.put(P_ID, cursor.getString(cursor.getColumnIndex(BUCKET_ID)));
					item.put(P_NAME, cursor.getString(cursor.getColumnIndex(BUCKET_DISPLAY_NAME)));
					result.put(item);
				} while (cursor.moveToNext());
			}
			callbackContext.success(result);
		} catch (Exception e) {
			Log.e(TAG, e.getMessage(), e);
			callbackContext.error(e.getMessage());
		}
	}

	private void photos(final JSONArray collectionIds, final JSONObject options, final CallbackContext callbackContext) {
		if (getPhotosCallbackContext() != null) {
			callbackContext.error(E_PHOTO_BUSY);
			return;
		}
		setPhotosCallbackContext(callbackContext);

		final String selection;
		final String[] selectionArgs;
		if (collectionIds != null && collectionIds.length() > 0) {
			selection = BUCKET_ID + " IN (" + repeatText(collectionIds.length(), "?", ",") + ")";
			selectionArgs = this.<String>jsonArrayToList(collectionIds).toArray(new String[collectionIds.length()]);
		} else {
			selection = BUCKET_DISPLAY_NAME + "=?";
			selectionArgs = new String[]{BN_CAMERA};
		}

		final int offset = options != null ? options.optInt(P_LIST_OFFSET, 0) : 0;
		final int limit = options != null ? options.optInt(P_LIST_LIMIT, 0) : 0;
		final int interval = options != null ? options.optInt(P_LIST_INTERVAL, 30) : 30;

		try (final Cursor cursor = query(
				cordova.getActivity().getContentResolver(),
				EXTERNAL_CONTENT_URI,
				PRJ_PHOTOS,
				selection,
				selectionArgs,
				DATE_TAKEN + " DESC")) {
			int fetched = 0;
			JSONArray result = new JSONArray();
			if (cursor.moveToFirst()) {
				do {
					if (getPhotosCallbackContext() == null) break;
					if (offset <= fetched) {
						final JSONObject item = new JSONObject();
						item.put(P_ID, cursor.getString(cursor.getColumnIndex(_ID)));
						item.put(P_NAME, cursor.getString(cursor.getColumnIndex(TITLE)));
						item.put(P_TYPE, "image/jpeg");
						long ts = cursor.getLong(cursor.getColumnIndex(DATE_TAKEN));
						if (ts != 0) {
							item.put(P_TS, ts);
							item.put(P_DATE, DF.format(new Date(ts)));
						}
						item.put(P_WIDTH, cursor.getInt(cursor.getColumnIndex(WIDTH)));
						item.put(P_HEIGHT, cursor.getInt(cursor.getColumnIndex(HEIGHT)));
						double latitude = cursor.getDouble(cursor.getColumnIndex(LATITUDE));
						double longitude = cursor.getDouble(cursor.getColumnIndex(LONGITUDE));
						if (latitude != 0 || longitude != 0) {
							item.put(P_LAT, latitude);
							item.put(P_LON, longitude);
						}
						result.put(item);
						if (limit > 0 && result.length() >= limit) {
							PluginResult pr = new PluginResult(PluginResult.Status.OK, result);
							pr.setKeepCallback(true);
							callbackContext.sendPluginResult(pr);
							result = new JSONArray();
							Thread.sleep(interval < 0 ? 30 : interval);
						}
					}
					++fetched;
				} while (cursor.moveToNext());
			}
			setPhotosCallbackContext(null);
			callbackContext.success(result);
		} catch (Exception e) {
			Log.e(TAG, e.getMessage(), e);
			setPhotosCallbackContext(null);
			callbackContext.error(e.getMessage());
		}
	}

	private void thumbnail(final String photoId, final JSONObject options, final CallbackContext callbackContext) {
		int size = options != null ? options.optInt(P_SIZE, DEF_SIZE) : DEF_SIZE;
		int quality = options != null ? options.optInt(P_QUALITY, DEF_QUALITY) : DEF_QUALITY;
		boolean asDataUrl = options != null && options.optBoolean(P_AS_DATAURL);
		try {
			if (photoId == null || photoId.isEmpty() || "null".equalsIgnoreCase(photoId))
				throw new IllegalArgumentException(E_PHOTO_ID_UNDEF);
			final Bitmap thumb = getThumbnail(
					cordova.getActivity().getContentResolver(), Long.parseLong(photoId), MINI_KIND, null);
			if (thumb == null) throw new IllegalStateException(E_PHOTO_ID_WRONG);

			double ratio = (double) size / (thumb.getWidth() >= thumb.getHeight() ? thumb.getWidth() : thumb.getHeight());
			int thumbW = (int) Math.round(thumb.getWidth() * ratio);
			int thumbH = (int) Math.round(thumb.getHeight() * ratio);

			final ByteArrayOutputStream osThumb = new ByteArrayOutputStream();
			Bitmap.createScaledBitmap(thumb, thumbW, thumbH, false).compress(Bitmap.CompressFormat.JPEG, quality, osThumb);
			if (!asDataUrl) callbackContext.success(osThumb.toByteArray());
			else callbackContext.success(T_DATA_URL + Base64.encodeToString(osThumb.toByteArray(), Base64.NO_WRAP));
		} catch (Exception e) {
			Log.e(TAG, e.getMessage(), e);
			callbackContext.error(e.getMessage());
		}
	}

	private void image(final String photoId, final CallbackContext callbackContext) {
		try {
			if (photoId == null || photoId.isEmpty() || "null".equalsIgnoreCase(photoId))
				throw new IllegalArgumentException(E_PHOTO_ID_UNDEF);
			final Bitmap image = getBitmap(
					cordova.getActivity().getContentResolver(),
					Uri.withAppendedPath(EXTERNAL_CONTENT_URI, photoId));
			if (image == null) throw new IllegalStateException(E_PHOTO_ID_WRONG);
			final ByteArrayOutputStream osImage = new ByteArrayOutputStream();
			image.compress(Bitmap.CompressFormat.JPEG, DEF_QUALITY, osImage);
			callbackContext.success(osImage.toByteArray());
		} catch (Exception e) {
			Log.e(TAG, e.getMessage(), e);
			callbackContext.error(e.getMessage());
		}
	}

	private void cancel(final CallbackContext callbackContext) {
		setPhotosCallbackContext(null);
		callbackContext.success();
	}

	private synchronized CallbackContext getPhotosCallbackContext() {
		return this.photosCallbackContext;
	}

	private synchronized void setPhotosCallbackContext(CallbackContext photosCallbackContext) {
		this.photosCallbackContext = photosCallbackContext;
	}

	private String repeatText(int count, String text, String separator) {
		if (count <= 0 || text == null || text.isEmpty()) return "";
		final StringBuilder result = new StringBuilder();
		for (int i = 0; i < count; ++i) {
			if (i > 0 && separator != null && !separator.isEmpty())
				result.append(separator);
			result.append(text);
		}
		return result.toString();
	}

	@SuppressWarnings("unchecked")
	private <T> List<T> jsonArrayToList(JSONArray array) {
		if (array == null) return null;
		final List<T> result = new ArrayList<>();
		for (int i = 0; i < array.length(); ++i)
			result.add((T) array.opt(i));
		return result;
	}
}
