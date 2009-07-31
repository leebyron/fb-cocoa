//
//  FBQuery.m
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBQuery.h"
#import "FBSession.h"

#define kErrorCodeInvalidSession 102

@interface FBQuery (Private)

- (NSError *)errorForResponse:(NSXMLDocument *)xml;

@end


@implementation FBQuery

-(id)initWithRequest:(NSURLRequest *)req target:(id)tar selector:(SEL)sel error:(SEL)err
{
  if (!(self = [super initWithRequest:req delegate:self])) {
    return nil;
  }

  target = [tar retain];
  method = sel;
  errorMethod = err;
  responseBuffer = [[NSMutableData alloc] init];

  return self;
}

-(void)dealloc
{
  NSLog(@"removing an FBQuery");
  [target release];
  [responseBuffer release];
  [super dealloc];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [responseBuffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:responseBuffer
                                                   options:0
                                                     error:nil];
  BOOL isError = ([[[xml rootElement] name] isEqualToString:@"error_response"]);
  if (isError) {
    NSError *err = [self errorForResponse:xml];

    if ([[FBSession session] usingSavedSession] && [err code] == kErrorCodeInvalidSession) {
      // We were using a session key that we'd saved as permanent, and got
      // back an error saying it was invalid. Throw away the saved session
      // data and start a login from scratch.      
      [[FBSession session] refreshSession];
    }
    
    if (target && errorMethod && [target respondsToSelector:errorMethod]) {
      [target performSelector:errorMethod withObject:err];
    }
  } else {
    if (target && method && [target respondsToSelector:method]) {
      [target performSelector:method withObject:xml];
    }
  }
}


#pragma mark Private Methods
- (NSError *)errorForResponse:(NSXMLDocument *)xml
{
  if (![[[xml rootElement] name] isEqualToString:@"error_response"]) {
    return nil;
  }
  
  int code = -1;
  NSString *message = nil;
  for (NSXMLNode *node in [[xml rootElement] children]) {
    if ([[node name] isEqualToString:@"error_code"]) {
      code = [[node stringValue] intValue];
    } else if ([[node name] isEqualToString:@"error_msg"]) {
      message = [node stringValue];
    }
  }
  
  return [NSError errorWithDomain:kFBErrorDomainKey
                             code:code
                         userInfo:[NSDictionary dictionaryWithObject:message
                                                              forKey:kFBErrorMessageKey]];
}

@end
