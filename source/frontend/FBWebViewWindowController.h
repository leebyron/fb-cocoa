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

  NSURLRequest* req;
  BOOL success;
  NSTimer* retryTimer;
  NSURL* lastURL;
}

@property(retain) NSURL *lastURL;

-(BOOL)success;

- (id)initWithCloseTarget:(id)obj selector:(SEL)sel;
- (void)showWithParams:(NSDictionary *)params;
- (void)attemptLoad;

@end
