#import <Cordova/CDV.h>

@interface CDVPhotos : CDVPlugin

- (void) collections:(CDVInvokedUrlCommand*)command;
- (void) photos:(CDVInvokedUrlCommand*)command;
- (void) thumbnail:(CDVInvokedUrlCommand*)command;
- (void) image:(CDVInvokedUrlCommand*)command;

@end
