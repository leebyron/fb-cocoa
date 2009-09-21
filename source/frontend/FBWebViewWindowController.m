//
//  FBWebViewWindowController.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBWebViewWindowController.h"
#import "NSString+.h"

//#define kLoginURL @"http://www.facebook.com/login.php?api_key=%@&v=1.0&auth_token=%@&popup"
#define kLoginURL @"http://www.facebook.com/login.php?"
#define kLoginFailureURL @"http://www.facebook.com/connect/login_failure.html"
#define kLoginSuccessURL @"http://www.facebook.com/connect/login_success.html"

@implementation FBWebViewWindowController

@synthesize lastURL;

- (id)initWithCloseTarget:(id)obj selector:(SEL)sel
{
  self = [super initWithWindowNibName:@"FBWebViewWindow"];
  if (self) {
    target = obj;
    selector = sel;
    success = NO;

    // Force the window to be loaded
    [[self window] center];
  }

  return self;
}

-(BOOL)success
{
  return success;
}

- (void)windowDidLoad
{
  [[[webView mainFrame] frameView] setAllowsScrolling:NO];

  // keep the window on top (modal) and make it the key.
  if ([[self window] respondsToSelector:@selector(setCollectionBehavior:)]) {
    [[self window] setCollectionBehavior:NSWindowCollectionBehaviorCanJoinAllSpaces];
  }
  [[self window] setLevel:NSFloatingWindowLevel];
  [[self window] makeKeyAndOrderFront:self];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)showWithParams:(NSDictionary *)params
{
  NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];
  [allParams setObject:@"true" forKey:@"fbconnect"];
  [allParams setObject:@"true" forKey:@"nochome"];
  [allParams setObject:@"popup" forKey:@"connect_display"];
  [allParams setObject:@"popup" forKey:@"display"];

  [allParams setObject:kLoginFailureURL forKey:@"cancel_url"];
  [allParams setObject:kLoginSuccessURL forKey:@"next"];
  [allParams setObject:@"true"          forKey:@"return_session"];

  NSString *url = [NSString stringWithFormat:@"%@%@", kLoginURL, [NSString urlEncodeArguments:allParams]];
  req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  [self attemptLoad];
}

- (void)keyDown:(NSEvent *)event
{
  if (([event modifierFlags] & NSCommandKeyMask) &&
      [[event charactersIgnoringModifiers] isEqualToString:@"w"]) {
    [[self window] performClose:self];
  } else {
    [super keyDown:event];
  }
}

- (void)windowWillClose:(NSNotification *)notification
{
  if (target && selector && [target respondsToSelector:selector]) {
    [target performSelector:selector withObject:nil];
  }
}

- (void)attemptLoad
{
  if (req == nil) {
    NSLog(@"No request was provided");
    success = NO;
    [[self window] close];
    return;
  }

  [[webView mainFrame] loadRequest:req];
  [[self window] center];
  [self showWindow:self];
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
  [[self window] setTitle:@"Facebook Connect — Loading\u2026"];
  [progressIndicator startAnimation:self];

  // reset timer before retry
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptLoad) object:nil];
  [self performSelector:@selector(attemptLoad) withObject:nil afterDelay:10.0];
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
  // reset timer before retry
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptLoad) object:nil];
  [self performSelector:@selector(attemptLoad) withObject:nil afterDelay:20.0];
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
  // stop timer for retry and retry immediately!
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptLoad) object:nil];
  [self attemptLoad];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
  // stop timer for retry
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(attemptLoad) object:nil];

  [[self window] setTitle:@"Facebook Connect"];
  [progressIndicator stopAnimation:self];
}

-                (void)webView:(WebView *)webView
decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
                       request:(NSURLRequest *)request
                  newFrameName:(NSString *)frameName
              decisionListener:(id < WebPolicyDecisionListener >)listener
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

-                 (void)webView:(WebView *)webView
decidePolicyForNavigationAction:(NSDictionary *)actionInformation
                        request:(NSURLRequest *)request
                          frame:(WebFrame *)frame
               decisionListener:(id < WebPolicyDecisionListener >)listener
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

  [lastURL release];
  lastURL = [[[request URL] copy] retain];

  // We want to detect when we've come across the success or failure URLs and act
  // accordingly
  if ([[[request URL] absoluteString] containsString:kLoginURL]) {
    [listener use];
  } else if ([[[request URL] absoluteString] containsString:kLoginSuccessURL]) {
    success = YES;
    [listener ignore];
    [[self window] close];
  } else if ([[[request URL] absoluteString] containsString:kLoginFailureURL] ||
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
