//
//  FBWebViewWindowController.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBWebViewWindowController.h"
#import "FBCocoa.h"
#import "FBConnect_Internal.h"
#import "NSString+.h"

#define kBrowserMinHeight 180
#define kBrowserMaxHeight 600
#define kBrowserLoadTimeout 15.0


@interface FBWebViewWindowController (Private)

- (void)queueRetryWithDelay:(NSTimeInterval)delay;
- (void)cancelRetry;
- (void)attemptLoad;

@end


@implementation FBWebViewWindowController

- (id)initWithConnect:(FBConnect*)connect
              rootURL:(NSString*)url
               target:(id)obj
             selector:(SEL)sel
{
  self = [super initWithWindowNibName:@"FBWebViewWindow"];
  if (self) {
    parent    = connect;
    rootURL   = [url retain];
    target    = obj;
    selector  = sel;
    success   = NO;

    // force the window to be loaded
    [self focus];
  }

  return self;
}

- (void)dealloc
{
  [rootURL    release];
  [req        release];
  [lastURL    release];
  [retryTimer release];

  [super dealloc];
}

- (void)focus
{
  [[self window] center];
  [NSApp activateIgnoringOtherApps:YES];
  [[self window] makeKeyAndOrderFront:self];
}

- (NSURL*)lastURL
{
  return lastURL;
}

- (void)setLastURL:(NSURL*)url
{
  [url retain];
  [lastURL release];
  lastURL = url;
}

-(BOOL)success
{
  return success;
}

- (void)windowDidLoad
{
  [[[webView mainFrame] frameView] setAllowsScrolling:NO];

  #ifndef NSWindowCollectionBehaviorCanJoinAllSpaces
    #define NSWindowCollectionBehaviorCanJoinAllSpaces 1 << 0
  #endif

  // keep the window on top (modal) and make it the key.
  if ([[self window] respondsToSelector:@selector(setCollectionBehavior:)]) {
    [[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
  }
  [NSApp activateIgnoringOtherApps:YES];
  [[self window] setLevel:NSFloatingWindowLevel];
  [[self window] makeKeyAndOrderFront:self];
}

- (void)showWithParams:(NSDictionary *)params
{
  NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];

  NSString* successURL =
    [NSString stringWithFormat:
     @"%@?accepted_permissions=xxRESULTTOKENxx",
     [parent loginSuccessURL]];
  
  NSString* failureURL = [parent loginFailureURL];

  [allParams setObject:kAPIVersion  forKey:@"v"];
  [allParams setObject:@"1"         forKey:@"fbconnect"];
  [allParams setObject:@"popup"     forKey:@"display"];
  [allParams setObject:failureURL   forKey:@"cancel_url"];
  [allParams setObject:successURL   forKey:@"next"];
  [allParams setObject:@"1"         forKey:@"return_session"];
  [allParams setObject:@"1"         forKey:@"extern"];

  NSString *url = [NSString stringWithFormat:@"%@?%@", rootURL, [NSString urlEncodeArguments:allParams]];
  req = [[NSURLRequest requestWithURL:[NSURL URLWithString:url]] retain];
  [self attemptLoad];
}

- (void)keyDown:(NSEvent *)event
{
  if ((([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask) &&
      [[event charactersIgnoringModifiers] isEqualToString:@"w"]) {
    [[self window] close];
  } else {
    [super keyDown:event];
  }
}

- (void)windowWillClose:(NSNotification *)notification
{
  [self cancelRetry];
  if (target && selector && [target respondsToSelector:selector]) {
    [target performSelector:selector withObject:nil];
  }
}

- (void)queueRetryWithDelay:(NSTimeInterval)delay
{
  if (retryTimer) {
    [self cancelRetry];
  }
  retryTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                target:self
                                              selector:@selector(attemptLoad)
                                              userInfo:nil
                                               repeats:NO];
}

- (void)cancelRetry
{
  if (retryTimer) {
    [retryTimer invalidate];
  }
  retryTimer = nil;
}

- (void)attemptLoad
{
  if (req == nil) {
    NSLog(@"No request was provided");
    success = NO;
    [[self window] close];
    return;
  }
  if (webView) {
    [[webView mainFrame] loadRequest:req];
    [self showWindow:self];
  }
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
  [[self window] setTitle:@"Facebook Connect — Loading\u2026"];
  [progressIndicator startAnimation:self];

  // reset timer before retry
  [self queueRetryWithDelay:kBrowserLoadTimeout];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
  // reset timer before retry
  [self queueRetryWithDelay:kBrowserLoadTimeout];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
  // stop timer for retry and retry immediately!
  [self cancelRetry];
  [self attemptLoad];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
  // stop timer for retry
  [self cancelRetry];

  [[self window] setTitle:@"Facebook Connect"];
  [progressIndicator stopAnimation:self];

  // resize window to fit
  NSRect currentRect = [[self window] frame];
  int height = [[sender stringByEvaluatingJavaScriptFromString:@"document.body.offsetHeight;"] intValue];
  height = MAX(kBrowserMinHeight, MIN(kBrowserMaxHeight, height));
  height += currentRect.size.height - [webView bounds].size.height;
  [[self window] setFrame:NSMakeRect(currentRect.origin.x,
                                     currentRect.origin.y + 0.5 * (currentRect.size.height - height),
                                     currentRect.size.width,
                                     height) display:YES animate:YES];
}

-                (void)webView:(WebView*)webView
decidePolicyForNewWindowAction:(NSDictionary*)actionInformation
                       request:(NSURLRequest*)request
                  newFrameName:(NSString*)frameName
              decisionListener:(id<WebPolicyDecisionListener>)listener
{
  // This is a delegate method where we decide what to do when the WebView
  // wants to open a new window, such as when a link that wants a new window
  // is clicked. We want to show those in the user's web browser, not in the
  // WebView. (Note this method also gets called on the initial -loadRequest:.)
  if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue]
      == WebNavigationTypeLinkClicked) {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
  } else {
    [listener use];
  }
}

-                 (void)webView:(WebView*)webView
decidePolicyForNavigationAction:(NSDictionary*)actionInformation
                        request:(NSURLRequest*)request
                          frame:(WebFrame*)frame
               decisionListener:(id<WebPolicyDecisionListener>)listener
{
  // This is a delegate method where we decide what to do when a navigation
  // action occurs. The only reason the WebView should be going to another
  // page is if a form (the login form) is submitted; if the user clicks a link,
  // we want to take them there in their normal web browser.
  if ([[actionInformation objectForKey:WebActionNavigationTypeKey] intValue]
      == WebNavigationTypeLinkClicked) {
    [listener ignore];
    [[NSWorkspace sharedWorkspace] openURL:[request URL]];
    return;
  }

  // capture new url.
  [lastURL release];
  lastURL = [[[request URL] copy] retain];

  // We want to detect when we've come across the success or failure URLs and act
  // accordingly
  if ([[[request URL] absoluteString] containsString:rootURL]) {
    [listener use];
  } else if ([[[request URL] absoluteString] containsString:[parent loginSuccessURL]]) {
    success = YES;
    [listener ignore];
    [[self window] close];
  } else if ([[[request URL] absoluteString] containsString:[parent loginFailureURL]] ||
             [[[request URL] absoluteString] containsString:@"home.php"]) {
    // Sometimes we get kicked to home.php, which is basically failure
    success = NO;
    [listener ignore];
    [[self window] close];
  } else {
    [listener use];
  }
}

@end
