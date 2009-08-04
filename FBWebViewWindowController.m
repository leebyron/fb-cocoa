//
//  FBWebViewWindowController.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBWebViewWindowController.h"


@implementation FBWebViewWindowController

- (id)initWithCloseTarget:(id)obj selector:(SEL)sel
{
  self = [super initWithWindowNibName:@"FBWebViewWindow"];
  if (self) {
    target = obj;
    selector = sel;

    // Force the window to be loaded
    [[self window] center];
  }

  return self;
}

- (void)windowDidLoad
{
  [[[webView mainFrame] frameView] setAllowsScrolling:NO];
}

- (void)showWithURL:(NSURL *)url
{
  NSURLRequest *req = [NSURLRequest requestWithURL:url];
  [[webView mainFrame] loadRequest:req];
  [[self window] center];
  [self showWindow:self];
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
  if (target && selector) {
    [target performSelector:selector withObject:nil];
  }
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame
{
  [[self window] setTitle:@"Facebook Connect | Loading\u2026"];
  [progressIndicator startAnimation:self];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
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
  } else {
    [listener use];
  }
}

@end
