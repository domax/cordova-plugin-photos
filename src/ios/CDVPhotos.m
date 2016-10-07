#import "CDVPhotos.h"
#import <Photos/Photos.h>

@interface CDVPhotos ()
@property (nonatomic, strong, readonly) NSDateFormatter* dateFormat;
@end

@implementation CDVPhotos

NSString* const P_ID = @"id";
NSString* const P_NAME = @"name";
NSString* const P_WIDTH = @"width";
NSString* const P_HEIGHT = @"height";
NSString* const P_LAT = @"latitude";
NSString* const P_LON = @"longitude";
NSString* const P_DATE = @"date";

NSString* const P_SIZE = @"dimension";
NSString* const P_AS_DATAURL = @"asDataUrl";

NSString* const P_C_MODE = @"collectionMode";
NSString* const P_C_MODE_ROLL = @"ROLL";
NSString* const P_C_MODE_SMART = @"SMART";
NSString* const P_C_MODE_ALBUMS = @"ALBUMS";
NSString* const P_C_MODE_MOMENTS = @"MOMENTS";

NSString* const T_DATA_URL = @"data:image/jpeg;base64,%@";

NSInteger const DEF_SIZE = 120;

- (void) pluginInitialize {
    _dateFormat = [[NSDateFormatter alloc] init];
    [_dateFormat setDateFormat:@"YYYY-MM-dd\'T\'HH:mm:ssZZZZZ"];
}

#pragma mark - Command implementations

- (void) collections:(CDVInvokedUrlCommand*)command {
    NSDictionary* options = [self argOf:command atIndex:0 withDefault:@{}];

    PHFetchResult<PHAssetCollection*>* fetchResultAssetCollections
    = [self fetchCollections:options];

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
         if (![weakSelf isNull:assetCollection.startDate]) {
             collectionItem[P_DATE]
             = [weakSelf.dateFormat stringFromDate:assetCollection.startDate];
         }

         [result addObject:collectionItem];
    }];
    [self success:command withArray:result];
}

- (void) photos:(CDVInvokedUrlCommand*)command {
    NSArray* collectionIds = [self argOf:command atIndex:0 withDefault:nil];

    PHFetchResult<PHAssetCollection*>* fetchResultAssetCollections
    = collectionIds == nil
    ? [self fetchCollections:@{}]
    : [PHAssetCollection
       fetchAssetCollectionsWithLocalIdentifiers:collectionIds
       options:[self fetchCollectionsOptions]];

    NSMutableArray<NSDictionary*>* result = [NSMutableArray array];
    CDVPhotos* __weak weakSelf = self;
    [fetchResultAssetCollections enumerateObjectsUsingBlock:
     ^(PHAssetCollection* _Nonnull assetCollection, NSUInteger idx, BOOL* _Nonnull stop) {
         PHFetchOptions* fetchOptions = [[PHFetchOptions alloc] init];
         fetchOptions.sortDescriptors = @[[NSSortDescriptor
                                           sortDescriptorWithKey:@"creationDate"
                                           ascending:NO]];

         PHFetchResult<PHAsset*>* fetchResultAssets =
         [PHAsset fetchAssetsInAssetCollection:assetCollection options:fetchOptions];

         [fetchResultAssets enumerateObjectsUsingBlock:
          ^(PHAsset* _Nonnull asset, NSUInteger idx, BOOL* _Nonnull stop) {
              if (asset.mediaType == PHAssetMediaTypeImage) {
                  NSMutableDictionary<NSString*, NSObject*>* assetItem =
                  [NSMutableDictionary dictionaryWithObjectsAndKeys:
                   asset.localIdentifier, P_ID,
                   [weakSelf.dateFormat stringFromDate:asset.creationDate], P_DATE,
                   @(asset.pixelWidth), P_WIDTH,
                   @(asset.pixelHeight), P_HEIGHT,
                   nil];

                  if (![weakSelf isNull:asset.location]) {
                      CLLocationCoordinate2D coord = asset.location.coordinate;
                      [assetItem setValue:@(coord.latitude) forKey:P_LAT];
                      [assetItem setValue:@(coord.longitude) forKey:P_LON];
                  }

                  PHAssetResource* resource = [self resourceForAsset:asset];
                  if (resource != nil) {
                      [assetItem setValue:resource.originalFilename forKey:P_NAME];
                  }

                  [result addObject:assetItem];
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
    BOOL asDataUrl = [options[P_AS_DATAURL] boolValue];

    PHImageRequestOptions* reqOptions = [[PHImageRequestOptions alloc] init];
    reqOptions.resizeMode = PHImageRequestOptionsResizeModeExact;
    reqOptions.networkAccessAllowed = YES;
//    reqOptions.synchronous = YES;

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
             [weakSelf failure:command withMessage:@"Specified photo has no data"];
             return;
         }
         NSData* data = UIImageJPEGRepresentation(result, 0.8);
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
//    reqOptions.synchronous = YES;
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

//    PHImageRequestID requestId =
    [[PHImageManager defaultManager]
     requestImageDataForAsset:asset
     options:reqOptions
     resultHandler:^(NSData* _Nullable imageData,
                     NSString* _Nullable dataUTI,
                     UIImageOrientation orientation,
                     NSDictionary* _Nullable info) {
//         NSLog(@"info: %@", info);
         NSError* error = info[PHImageErrorKey];
         if (![weakSelf isNull:error]) {
             [weakSelf failure:command withMessage:error.localizedDescription];
             return;
         }
         if ([weakSelf isNull:imageData]) {
             [weakSelf failure:command withMessage:@"Specified photo has no data"];
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
        [self failure:command withMessage:@"Photo ID is undefined"];
        return nil;
    }
    PHFetchResult<PHAsset*>* fetchResultAssets =
    [PHAsset fetchAssetsWithLocalIdentifiers:@[assetId] options:nil];
    if (fetchResultAssets.count == 0) {
        [self failure:command withMessage:@"Photo with specified ID wasn't found"];
        return nil;
    }
    PHAsset* asset = fetchResultAssets.firstObject;
    if (asset.mediaType != PHAssetMediaTypeImage) {
        [self failure:command withMessage:@"Data with specified ID isn't an image"];
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

- (PHFetchOptions*) fetchCollectionsOptions {
    PHFetchOptions* fetchOptions = [[PHFetchOptions alloc] init];
    fetchOptions.sortDescriptors = @[[NSSortDescriptor
                                      sortDescriptorWithKey:@"startDate"
                                      ascending:NO]];
    return fetchOptions;
}

- (PHFetchResult<PHAssetCollection*>*) fetchCollections:(NSDictionary*)options {
    NSString* mode = [self valueFrom:options byKey:P_C_MODE withDefault:P_C_MODE_ROLL];

    PHAssetCollectionType type;
    PHAssetCollectionSubtype subtype;
    if ([P_C_MODE_SMART isEqualToString:mode]) {
        type = PHAssetCollectionTypeSmartAlbum;
        subtype = PHAssetCollectionSubtypeAny;
    } else if ([P_C_MODE_ALBUMS isEqualToString:mode]) {
        type = PHAssetCollectionTypeAlbum;
        subtype = PHAssetCollectionSubtypeAny;
    } else if ([P_C_MODE_MOMENTS isEqualToString:mode]) {
        type = PHAssetCollectionTypeMoment;
        subtype = PHAssetCollectionSubtypeAny;
    } else {
        type = PHAssetCollectionTypeSmartAlbum;
        subtype = PHAssetCollectionSubtypeSmartAlbumUserLibrary;
    }
    return [PHAssetCollection fetchAssetCollectionsWithType:type
                                                    subtype:subtype
                                                    options:[self fetchCollectionsOptions]];
}

#pragma mark - Callback methods

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

- (void) failure:(CDVInvokedUrlCommand*)command withMessage:(NSString*)message {
    [self.commandDelegate
     sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                         messageAsString:message]
     callbackId:command.callbackId];
}

@end
