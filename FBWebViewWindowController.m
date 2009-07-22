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

- (void)windowWillClose:(NSNotification *)notification
{
  if (target && selector) {
    [target performSelector:selector withObject:nil];
  }
}

@end
