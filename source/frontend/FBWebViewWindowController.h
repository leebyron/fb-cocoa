//
//  FBWebViewWindowController.h
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface FBWebViewWindowController : NSWindowController {
  IBOutlet WebView *webView;
  IBOutlet NSProgressIndicator *progressIndicator;

  id target;
  SEL selector;

  BOOL success;
  NSTimer* retryTimer;
  NSString* rootURL;
  NSURLRequest* req;
  NSURL* lastURL;
}

- (id)initWithRootURL:(NSString*)url
               target:(id)obj
             selector:(SEL)sel;

- (void)focus;
- (NSURL*)lastURL;
- (void)setLastURL:(NSURL*)url;
- (BOOL)success;
- (void)showWithParams:(NSDictionary *)params;

@end
