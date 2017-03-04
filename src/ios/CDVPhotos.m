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
#import "CDVPhotos.h"
#import <Photos/Photos.h>

@interface CDVPhotos ()
@property (nonatomic, strong, readonly) NSDateFormatter* dateFormat;
@property (nonatomic, strong, readonly) NSDictionary<NSString*, NSString*>* extType;
@property (nonatomic, strong, readonly) NSRegularExpression* extRegex;
@property (nonatomic, strong) CDVInvokedUrlCommand* photosCommand;
@end

@implementation CDVPhotos

NSString* const P_ID = @"id";
NSString* const P_NAME = @"name";
NSString* const P_WIDTH = @"width";
NSString* const P_HEIGHT = @"height";
NSString* const P_LAT = @"latitude";
NSString* const P_LON = @"longitude";
NSString* const P_DATE = @"date";
NSString* const P_TS = @"timestamp";
NSString* const P_TYPE = @"contentType";

NSString* const P_SIZE = @"dimension";
NSString* const P_QUALITY = @"quality";
NSString* const P_AS_DATAURL = @"asDataUrl";

NSString* const P_C_MODE = @"collectionMode";
NSString* const P_C_MODE_ROLL = @"ROLL";
NSString* const P_C_MODE_SMART = @"SMART";
NSString* const P_C_MODE_ALBUMS = @"ALBUMS";
NSString* const P_C_MODE_MOMENTS = @"MOMENTS";

NSString* const P_LIST_OFFSET = @"offset";
NSString* const P_LIST_LIMIT = @"limit";
NSString* const P_LIST_INTERVAL = @"interval";

NSString* const T_DATA_URL = @"data:image/jpeg;base64,%@";
NSString* const T_DATE_FORMAT = @"YYYY-MM-dd\'T\'HH:mm:ssZZZZZ";
NSString* const T_EXT_PATTERN = @"^(.+)\\.([a-z]{3,4})$";

NSInteger const DEF_SIZE = 120;
NSInteger const DEF_QUALITY = 80;
NSString* const DEF_NAME = @"No Name";

NSString* const E_PERMISSION = @"Access to Photo Library permission required";
NSString* const E_COLLECTION_MODE = @"Unsupported collection mode";
NSString* const E_PHOTO_NO_DATA = @"Specified photo has no data";
NSString* const E_PHOTO_THUMB = @"Cannot get a thumbnail of photo";
NSString* const E_PHOTO_ID_UNDEF = @"Photo ID is undefined";
NSString* const E_PHOTO_ID_WRONG = @"Photo with specified ID wasn't found";
NSString* const E_PHOTO_NOT_IMAGE = @"Data with specified ID isn't an image";
NSString* const E_PHOTO_BUSY = @"Fetching of photo assets is in progress";

- (void) pluginInitialize {
    _dateFormat = [[NSDateFormatter alloc] init];
    [_dateFormat setDateFormat:T_DATE_FORMAT];

    _extType = @{@"JPG": @"image/jpeg",
                 @"JPEG": @"image/jpeg",
                 @"PNG": @"image/png",
                 @"GIF": @"image/gif",
                 @"TIF": @"image/tiff",
                 @"TIFF": @"image/tiff"};

    _extRegex = [NSRegularExpression
                 regularExpressionWithPattern:T_EXT_PATTERN
                 options:NSRegularExpressionCaseInsensitive
                 + NSRegularExpressionDotMatchesLineSeparators
                 + NSRegularExpressionAnchorsMatchLines
                 error:NULL];
}

#pragma mark - Command implementations

- (void) collections:(CDVInvokedUrlCommand*)command {
    CDVPhotos* __weak weakSelf = self;
    [self checkPermissionsOf:command andRun:^{
        NSDictionary* options = [weakSelf argOf:command atIndex:0 withDefault:@{}];

        PHFetchResult<PHAssetCollection*>* fetchResultAssetCollections
        = [weakSelf fetchCollections:options];
        if (fetchResultAssetCollections == nil) {
            [weakSelf failure:command withMessage:E_COLLECTION_MODE];
            return;
        }

        NSMutableArray<NSDictionary*>* result
        = [NSMutableArray arrayWithCapacity:fetchResultAssetCollections.count];

        [fetchResultAssetCollections enumerateObjectsUsingBlock:
         ^(PHAssetCollection* _Nonnull assetCollection, NSUInteger idx, BOOL* _Nonnull stop) {
             NSMutableDictionary<NSString*, NSObject*>* collectionItem
             = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                assetCollection.localIdentifier, P_ID,
                assetCollection.localizedTitle, P_NAME,
                nil];
             if ([weakSelf isNull:assetCollection.localizedTitle]) {
                 collectionItem[P_NAME] = DEF_NAME;
             }

             [result addObject:collectionItem];
         }];
        [weakSelf success:command withArray:result];
    }];
}

- (void) photos:(CDVInvokedUrlCommand*)command {
    if (![self isNull:self.photosCommand]) {
        [self failure:command withMessage:E_PHOTO_BUSY];
        return;
    }
    self.photosCommand = command;
    CDVPhotos* __weak weakSelf = self;
    [self checkPermissionsOf:command andRun:^{
        NSArray* collectionIds = [weakSelf argOf:command atIndex:0 withDefault:nil];
        NSLog(@"photos: collectionIds=%@", collectionIds);

        NSDictionary* options = [weakSelf argOf:command atIndex:1 withDefault:@{}];
        int offset = [[weakSelf valueFrom:options
                                    byKey:P_LIST_OFFSET
                              withDefault:@"0"] intValue];
        int limit = [[weakSelf valueFrom:options
                                   byKey:P_LIST_LIMIT
                             withDefault:@"0"] intValue];
        NSTimeInterval interval = [[weakSelf valueFrom:options
                                                 byKey:P_LIST_INTERVAL
                                           withDefault:@"30"] intValue];
        interval = interval < 0 ? .03f : interval / 1000.0f;

        PHFetchResult<PHAssetCollection*>* fetchResultAssetCollections
        = collectionIds == nil || collectionIds.count == 0
        ? [weakSelf fetchCollections:@{}]
        : [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:collectionIds
                                                               options:nil];
        if (fetchResultAssetCollections == nil) {
            weakSelf.photosCommand = nil;
            [weakSelf failure:command withMessage:E_COLLECTION_MODE];
            return;
        }

        int __block fetched = 0;
        NSMutableArray<PHAsset*>* __block skippedAssets = [NSMutableArray array];
        NSMutableArray<NSDictionary*>* __block result = [NSMutableArray array];
        [fetchResultAssetCollections enumerateObjectsUsingBlock:
         ^(PHAssetCollection* _Nonnull assetCollection, NSUInteger idx, BOOL* _Nonnull stop) {
             if ([weakSelf isNull:weakSelf.photosCommand]) {
                 *stop = YES;
                 return;
             }
             PHFetchOptions* fetchOptions = [[PHFetchOptions alloc] init];
             fetchOptions.sortDescriptors = @[[NSSortDescriptor
                                               sortDescriptorWithKey:@"creationDate"
                                               ascending:NO]];
             fetchOptions.predicate
             = [NSPredicate predicateWithFormat:@"mediaType = %d", PHAssetMediaTypeImage];

             PHFetchResult<PHAsset*>* fetchResultAssets =
             [PHAsset fetchAssetsInAssetCollection:assetCollection options:fetchOptions];

             [fetchResultAssets enumerateObjectsUsingBlock:
              ^(PHAsset* _Nonnull asset, NSUInteger idx, BOOL* _Nonnull stop) {
                  if ([weakSelf isNull:weakSelf.photosCommand]) {
                      *stop = YES;
                      return;
                  }
                  NSString* filename = [weakSelf getFilenameForAsset:asset];
                  if (![weakSelf isNull:filename]) {
                      NSTextCheckingResult* match
                      = [weakSelf.extRegex
                         firstMatchInString:filename
                         options:0
                         range:NSMakeRange(0, filename.length)];
                      if (match != nil) {
                          NSString* name = [filename substringWithRange:[match rangeAtIndex:1]];
                          NSString* ext = [[filename substringWithRange:[match rangeAtIndex:2]] uppercaseString];
                          NSString* type = weakSelf.extType[ext];
                          if (![weakSelf isNull:type]) {
                              if (offset <= fetched) {
                                  NSMutableDictionary<NSString*, NSObject*>* assetItem
                                  = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                     asset.localIdentifier, P_ID,
                                     name, P_NAME,
                                     type, P_TYPE,
                                     [weakSelf.dateFormat stringFromDate:asset.creationDate], P_DATE,
                                     @((long) (asset.creationDate.timeIntervalSince1970 * 1000)), P_TS,
                                     @(asset.pixelWidth), P_WIDTH,
                                     @(asset.pixelHeight), P_HEIGHT,
                                     nil];
                                  if (![weakSelf isNull:asset.location]) {
                                      CLLocationCoordinate2D coord = asset.location.coordinate;
                                      [assetItem setValue:@(coord.latitude) forKey:P_LAT];
                                      [assetItem setValue:@(coord.longitude) forKey:P_LON];
                                  }
                                  [result addObject:assetItem];
                                  if (limit > 0 && result.count >= limit) {
                                      [weakSelf partial:command withArray:result];
                                      [result removeAllObjects];
                                      [NSThread sleepForTimeInterval:interval];
                                  }
                              }
                              ++fetched;
                          } else [skippedAssets addObject:asset];
                      } else [skippedAssets addObject:asset];
                  } else [skippedAssets addObject:asset];
              }];
         }];
        [skippedAssets enumerateObjectsUsingBlock:^(PHAsset* _Nonnull asset, NSUInteger idx, BOOL* _Nonnull stop) {
            NSLog(@"skipped asset %lu: id=%@; name=%@, type=%ld-%ld; size=%lux%lu;",
                  idx, asset.localIdentifier, [weakSelf getFilenameForAsset:asset],
                  (long)asset.mediaType, (long)asset.mediaSubtypes,
                  (unsigned long)asset.pixelWidth, asset.pixelHeight);
        }];
        weakSelf.photosCommand = nil;
        [weakSelf success:command withArray:result];
    }];
}

- (void) thumbnail:(CDVInvokedUrlCommand*)command {
    CDVPhotos* __weak weakSelf = self;
    [self checkPermissionsOf:command andRun:^{
        PHAsset* asset = [weakSelf assetByCommand:command];
        if (asset == nil) return;

        NSDictionary* options = [weakSelf argOf:command atIndex:1 withDefault:@{}];

        NSInteger size = [options[P_SIZE] integerValue];
        if (size <= 0) size = DEF_SIZE;
        NSInteger quality = [options[P_QUALITY] integerValue];
        if (quality <= 0) quality = DEF_QUALITY;
        BOOL asDataUrl = [options[P_AS_DATAURL] boolValue];

        PHImageRequestOptions* reqOptions = [[PHImageRequestOptions alloc] init];
        reqOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
        reqOptions.networkAccessAllowed = YES;
        reqOptions.synchronous = YES;

        [[PHImageManager defaultManager]
         requestImageForAsset:asset
         targetSize:CGSizeMake(size, size)
         contentMode:PHImageContentModeDefault
         options:reqOptions
         resultHandler:^(UIImage* _Nullable result, NSDictionary* _Nullable info) {
             NSError* error = info[PHImageErrorKey];
             if (![weakSelf isNull:error]) {
                 [weakSelf failure:command withMessage:error.localizedDescription];
                 return;
             }
             if ([weakSelf isNull:result]) {
                 [weakSelf failure:command withMessage:E_PHOTO_NO_DATA];
                 return;
             }
             UIGraphicsBeginImageContext(result.size);
             [result drawInRect:CGRectMake(0, 0, result.size.width, result.size.height)];
             UIImage* image = UIGraphicsGetImageFromCurrentImageContext();
             UIGraphicsEndImageContext();
             NSData* data = UIImageJPEGRepresentation(image, (CGFloat) quality / 100);
             if ([weakSelf isNull:data]) {
                 [weakSelf failure:command withMessage:E_PHOTO_THUMB];
                 return;
             }
             if (asDataUrl) {
                 NSString* dataUrl = [NSString stringWithFormat:T_DATA_URL,
                                      [data base64EncodedStringWithOptions:0]];
                 [weakSelf success:command withMessage:dataUrl];
             } else [weakSelf success:command withData:data];
         }];
    }];
}

- (void) image:(CDVInvokedUrlCommand*)command {
    CDVPhotos* __weak weakSelf = self;
    [self checkPermissionsOf:command andRun:^{
        PHAsset* asset = [weakSelf assetByCommand:command];
        if (asset == nil) return;

        PHImageRequestOptions* reqOptions = [[PHImageRequestOptions alloc] init];
        reqOptions.networkAccessAllowed = YES;
        reqOptions.progressHandler = ^(double progress,
                                       NSError* __nullable error,
                                       BOOL* stop,
                                       NSDictionary* __nullable info) {
            NSLog(@"progress: %.2f, info: %@", progress, info);
            if (![weakSelf isNull:error]) {
                NSLog(@"error: %@", error);
                *stop = YES;
            }
        };

        [[PHImageManager defaultManager]
         requestImageDataForAsset:asset
         options:reqOptions
         resultHandler:^(NSData* _Nullable imageData,
                         NSString* _Nullable dataUTI,
                         UIImageOrientation orientation,
                         NSDictionary* _Nullable info) {
             NSError* error = info[PHImageErrorKey];
             if (![weakSelf isNull:error]) {
                 [weakSelf failure:command withMessage:error.localizedDescription];
                 return;
             }
             if ([weakSelf isNull:imageData]) {
                 [weakSelf failure:command withMessage:E_PHOTO_NO_DATA];
                 return;
             }
             [weakSelf success:command withData:imageData];
         }];
    }];
}

- (void) cancel:(CDVInvokedUrlCommand*)command {
    self.photosCommand = nil;
    [self success:command];
}

#pragma mark - Auxiliary functions

- (void) checkPermissionsOf:(CDVInvokedUrlCommand*)command andRun:(void (^)())block {
    [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
        switch ([PHPhotoLibrary authorizationStatus]) {
            case PHAuthorizationStatusAuthorized:
                [self.commandDelegate runInBackground:block];
                break;
            default:
                [self failure:command withMessage:E_PERMISSION];
                break;
        }
    }];
}

- (BOOL) isNull:(id)obj {
    return obj == nil || [[NSNull null] isEqual:obj];
}

- (id) argOf:(CDVInvokedUrlCommand*)command
            atIndex:(NSUInteger)idx
          withDefault:(NSObject*)def {
    NSArray* args = command.arguments;
    NSObject* arg = args.count > idx ? args[idx] : nil;
    if ([self isNull:arg]) arg = def;
    return arg;
}

- (id) valueFrom:(NSDictionary*)dictionary byKey:(id)key withDefault:(NSObject*)def {
    id result = dictionary[key];
    if ([self isNull:result]) result = def;
    return result;
}

- (PHAsset*) assetByCommand:(CDVInvokedUrlCommand*)command {
    NSString* assetId = [self argOf:command atIndex:0 withDefault:nil];

    if ([self isNull:assetId]) {
        [self failure:command withMessage:E_PHOTO_ID_UNDEF];
        return nil;
    }
    PHFetchResult<PHAsset*>* fetchResultAssets
    = [PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil];
    if (fetchResultAssets.count == 0) {
        [self failure:command withMessage:E_PHOTO_ID_WRONG];
        return nil;
    }
    PHAsset* asset = fetchResultAssets.firstObject;
    if (asset.mediaType != PHAssetMediaTypeImage) {
        [self failure:command withMessage:E_PHOTO_NOT_IMAGE];
        return nil;
    }
    return asset;
}

- (NSString*) getFilenameForAsset:(PHAsset*)asset {
// Works fine, but asynchronous ((.
//    [asset
//     requestContentEditingInputWithOptions:nil
//     completionHandler:^(PHContentEditingInput* _Nullable contentEditingInput, NSDictionary* _Nonnull info) {
//         NSString* filename = [[contentEditingInput.fullSizeImageURL.absoluteString componentsSeparatedByString:@"/"] lastObject];
//     }];

// Most optimal and fast, but it's dirty hack
    return [asset valueForKey:@"filename"];

// assetResourcesForAsset doesn't work properly for all images.
// Moreover, it obtains resource for very long time - too long for just a file name.
//    NSArray<PHAssetResource*>* resources = [PHAssetResource assetResourcesForAsset:asset];
//    if ([self isNull:resources] || resources.count == 0) return nil;
//    return resources[0].originalFilename;
}

- (PHFetchResult<PHAssetCollection*>*) fetchCollections:(NSDictionary*)options {
    NSString* mode = [self valueFrom:options
                               byKey:P_C_MODE
                         withDefault:P_C_MODE_ROLL];

    PHAssetCollectionType type;
    PHAssetCollectionSubtype subtype;
    if ([P_C_MODE_ROLL isEqualToString:mode]) {
        type = PHAssetCollectionTypeSmartAlbum;
        subtype = PHAssetCollectionSubtypeSmartAlbumUserLibrary;
    } else if ([P_C_MODE_SMART isEqualToString:mode]) {
        type = PHAssetCollectionTypeSmartAlbum;
        subtype = PHAssetCollectionSubtypeAny;
    } else if ([P_C_MODE_ALBUMS isEqualToString:mode]) {
        type = PHAssetCollectionTypeAlbum;
        subtype = PHAssetCollectionSubtypeAny;
    } else if ([P_C_MODE_MOMENTS isEqualToString:mode]) {
        type = PHAssetCollectionTypeMoment;
        subtype = PHAssetCollectionSubtypeAny;
    } else {
        return nil;
    }
    return [PHAssetCollection fetchAssetCollectionsWithType:type
                                                    subtype:subtype
                                                    options:nil];
}

#pragma mark - Callback methods

- (void) success:(CDVInvokedUrlCommand*)command {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK]
     callbackId:command.callbackId];
}

- (void) success:(CDVInvokedUrlCommand*)command withMessage:(NSString*)message {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                        messageAsString:message]
     callbackId:command.callbackId];
}

- (void) success:(CDVInvokedUrlCommand*)command withArray:(NSArray*)array {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                         messageAsArray:array]
     callbackId:command.callbackId];
}

- (void) success:(CDVInvokedUrlCommand*)command withData:(NSData*)data {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                   messageAsArrayBuffer:data]
     callbackId:command.callbackId];
}

- (void) partial:(CDVInvokedUrlCommand*)command withArray:(NSArray*)array {
    CDVPluginResult* result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                                 messageAsArray:array];
    [result setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

- (void) failure:(CDVInvokedUrlCommand*)command withMessage:(NSString*)message {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                        messageAsString:message]
     callbackId:command.callbackId];
}

@end
