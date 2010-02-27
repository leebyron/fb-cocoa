//
//  FBWebViewWindowController.h
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@class FBConnect;

@interface FBWebViewWindowController : NSWindowController {
  IBOutlet WebView *webView;
  IBOutlet NSProgressIndicator *progressIndicator;
  
  FBConnect* parent;

  id target;
  SEL selector;

  BOOL success;
  NSTimer* retryTimer;
  NSString* rootURL;
  NSURLRequest* req;
  NSURL* lastURL;
}

- (id)initWithConnect:(FBConnect*)connect
              rootURL:(NSString*)url
               target:(id)obj
             selector:(SEL)sel;

- (void)focus;
- (NSURL*)lastURL;
- (void)setLastURL:(NSURL*)url;
- (BOOL)success;
- (void)showWithParams:(NSDictionary *)params;

@end
