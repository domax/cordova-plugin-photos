#import "CDVPhotos.h"
#import <Photos/Photos.h>

@interface CDVPhotos ()
@property (nonatomic, strong, readonly) NSDateFormatter* dateFormat;
@property (nonatomic, strong, readonly) NSDictionary<NSString*, NSString*>* extType;
@property (nonatomic, strong, readonly) NSRegularExpression* extRegex;
@end

@implementation CDVPhotos

NSString* const P_ID = @"id";
NSString* const P_NAME = @"name";
NSString* const P_WIDTH = @"width";
NSString* const P_HEIGHT = @"height";
NSString* const P_LAT = @"latitude";
NSString* const P_LON = @"longitude";
NSString* const P_DATE = @"date";
NSString* const P_TYPE = @"contentType";

NSString* const P_SIZE = @"dimension";
NSString* const P_QUALITY = @"quality";
NSString* const P_AS_DATAURL = @"asDataUrl";

NSString* const P_C_MODE = @"collectionMode";
NSString* const P_C_MODE_ROLL = @"ROLL";
NSString* const P_C_MODE_SMART = @"SMART";
NSString* const P_C_MODE_ALBUMS = @"ALBUMS";
NSString* const P_C_MODE_MOMENTS = @"MOMENTS";

NSString* const T_DATA_URL = @"data:image/jpeg;base64,%@";
NSString* const T_DATE_FORMAT = @"YYYY-MM-dd\'T\'HH:mm:ssZZZZZ";
NSString* const T_EXT_PATTERN = @"^(.+)\\.([a-z]{3,4})$";

NSInteger const DEF_SIZE = 120;
NSInteger const DEF_QUALITY = 80;
NSString* const DEF_NAME = @"No Name";

NSString* const E_COLLECTION_MODE = @"Unsupported collection mode";
NSString* const E_PHOTO_NO_DATA = @"Specified photo has no data";
NSString* const E_PHOTO_ID_UNDEF = @"Photo ID is undefined";
NSString* const E_PHOTO_ID_WRONG = @"Photo with specified ID wasn't found";
NSString* const E_PHOTO_NOT_IMAGE = @"Data with specified ID isn't an image";

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
    NSDictionary* options = [self argOf:command atIndex:0 withDefault:@{}];

    PHFetchResult<PHAssetCollection*>* fetchResultAssetCollections
    = [self fetchCollections:options];
    if (fetchResultAssetCollections == nil) {
        [self failure:command withMessage:E_COLLECTION_MODE];
        return;
    }

    NSMutableArray<NSDictionary*>* result
    = [NSMutableArray arrayWithCapacity:fetchResultAssetCollections.count];

    CDVPhotos* __weak weakSelf = self;
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
    [self success:command withArray:result];
}

- (void) photos:(CDVInvokedUrlCommand*)command {
    NSArray* collectionIds = [self argOf:command atIndex:0 withDefault:nil];

    PHFetchResult<PHAssetCollection*>* fetchResultAssetCollections
    = collectionIds == nil || collectionIds.count == 0
    ? [self fetchCollections:@{}]
    : [PHAssetCollection fetchAssetCollectionsWithLocalIdentifiers:collectionIds
                                                           options:nil];
    if (fetchResultAssetCollections == nil) {
        [self failure:command withMessage:E_COLLECTION_MODE];
        return;
    }

    NSMutableArray<NSDictionary*>* result = [NSMutableArray array];
    CDVPhotos* __weak weakSelf = self;
    [fetchResultAssetCollections enumerateObjectsUsingBlock:
     ^(PHAssetCollection* _Nonnull assetCollection, NSUInteger idx, BOOL* _Nonnull stop) {
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
              PHAssetResource* resource = [weakSelf resourceForAsset:asset];
              if (resource != nil) {
                  NSTextCheckingResult* match
                  = [weakSelf.extRegex
                     firstMatchInString:resource.originalFilename
                     options:0
                     range:NSMakeRange(0, resource.originalFilename.length)];
                  if (match != nil) {
                      NSString* name = [resource.originalFilename
                                        substringWithRange:[match rangeAtIndex:1]];
                      NSString* ext = [[resource.originalFilename
                                        substringWithRange:[match rangeAtIndex:2]]
                                       uppercaseString];
                      NSString* type = weakSelf.extType[ext];
                      if (![weakSelf isNull:type]) {
                          NSMutableDictionary<NSString*, NSObject*>* assetItem
                          = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                             asset.localIdentifier, P_ID,
                             name, P_NAME,
                             type, P_TYPE,
                             [weakSelf.dateFormat stringFromDate:asset.creationDate], P_DATE,
                             @(asset.pixelWidth), P_WIDTH,
                             @(asset.pixelHeight), P_HEIGHT,
                             nil];
                          if (![weakSelf isNull:asset.location]) {
                              CLLocationCoordinate2D coord = asset.location.coordinate;
                              [assetItem setValue:@(coord.latitude) forKey:P_LAT];
                              [assetItem setValue:@(coord.longitude) forKey:P_LON];
                          }
                          [result addObject:assetItem];
                      }
                  }
              }
          }];
     }];
    [self success:command withArray:result];
}

- (void) thumbnail:(CDVInvokedUrlCommand*)command {
    PHAsset* asset = [self assetByCommand:command];
    if (asset == nil) return;

    NSDictionary* options = [self argOf:command atIndex:1 withDefault:@{}];

    NSInteger size = [options[P_SIZE] integerValue];
    if (size <= 0) size = DEF_SIZE;
    NSInteger quality = [options[P_QUALITY] integerValue];
    if (quality <= 0) quality = DEF_QUALITY;
    BOOL asDataUrl = [options[P_AS_DATAURL] boolValue];

    PHImageRequestOptions* reqOptions = [[PHImageRequestOptions alloc] init];
    reqOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
    reqOptions.networkAccessAllowed = YES;

    CDVPhotos* __weak weakSelf = self;
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
         NSData* data = UIImageJPEGRepresentation(result, (CGFloat) quality / 100);
         if (asDataUrl) {
             NSString* dataUrl = [NSString stringWithFormat:T_DATA_URL,
                                  [data base64EncodedStringWithOptions:0]];
             [weakSelf success:command withMessage:dataUrl];
         } else [weakSelf success:command withData:data];
     }];
}

- (void) image:(CDVInvokedUrlCommand*)command {
    PHAsset* asset = [self assetByCommand:command];
    if (asset == nil) return;

    CDVPhotos* __weak weakSelf = self;

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
}

#pragma mark - Auxiliary functions

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

- (PHAssetResource*) resourceForAsset:(PHAsset*)asset {
    PHAssetResource* __block result = nil;
    [[PHAssetResource assetResourcesForAsset:asset] enumerateObjectsUsingBlock:
     ^(PHAssetResource* _Nonnull resource, NSUInteger idx, BOOL* _Nonnull stop) {
         if (resource.type == PHAssetResourceTypePhoto) {
             result = resource;
             *stop = YES;
         }
     }];
    return result;
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

- (void) success:(CDVInvokedUrlCommand*)command withMessage:(NSString*)message {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_OK
                       messageAsString:message]
     callbackId:command.callbackId];
}

- (void) success:(CDVInvokedUrlCommand*)command withArray:(NSArray*)array {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_OK
                       messageAsArray:array]
     callbackId:command.callbackId];
}

- (void) success:(CDVInvokedUrlCommand*)command withData:(NSData*)data {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_OK
                       messageAsArrayBuffer:data]
     callbackId:command.callbackId];
}

- (void) failure:(CDVInvokedUrlCommand*)command withMessage:(NSString*)message {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult
                       resultWithStatus:CDVCommandStatus_ERROR
                       messageAsString:message]
     callbackId:command.callbackId];
}

@end
