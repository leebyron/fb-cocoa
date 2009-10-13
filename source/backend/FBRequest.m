//
//  FBRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBRequest.h"
#import "FBCocoa.h"
#import "JSON.h"


@interface FBRequest (Internal)

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

@end

@interface FBRequest (Private)

- (NSError *)errorForResponse:(id)json;
- (NSError *)errorForException:(NSException *)exception;

@end


@interface FBConnect (FBRequestResults)

- (void)failedQuery:(FBRequest *)query withError:(NSError *)err;

@end


@implementation FBRequest

+(FBRequest*) requestWithRequest:(NSString *)requestString
                          parent:(FBConnect *)parent
                          target:(id)tar
                        selector:(SEL)sel
                           error:(SEL)err
{
  return [[[FBRequest alloc] initWithRequest:requestString
                                      parent:parent
                                      target:tar
                                    selector:sel
                                       error:err] autorelease];
}

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err
{
  if (self = [super init]) {
    requestStarted = false;

    target = [tar retain];
    method = sel;
    errorMethod = err;

    parentConnect = [parent retain];
    request = [requestString retain];
    responseBuffer = [[NSMutableData alloc] init];
  }
  return self;
}

-(void)dealloc
{
  [target release];

  [request release];
  [responseBuffer release];
  [parentConnect release];
  [connection release];

  [super dealloc];
}

- (void)start
{
  if (requestStarted) {
    NSLog(@"can't start the same request twice");
    return;
  }
  requestStarted = true;
  [self retain];
  @try {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kRESTServerURL, request]];

    #ifdef NSURLRequestReloadIgnoringLocalCacheData
      NSURLRequestCachePolicy policy = NSURLRequestReloadIgnoringLocalCacheData;
    #else
      NSURLRequestCachePolicy policy = NSURLRequestUseProtocolCachePolicy;
    #endif

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:policy timeoutInterval:kRequestTimeout];
    [req setHTTPMethod:@"GET"];
    [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    [req setValue:@"FBConnect/0.2 (OS X)" forHTTPHeaderField:@"User-Agent"];

    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
  } @catch (NSException *exception) {
    [self requestFailure:[self errorForException:exception]];

    // peace!
    [self release];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [responseBuffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSString* jsonString = [[NSString alloc] initWithData:responseBuffer encoding:NSUTF8StringEncoding];
  SBJsonParser* jsonParser = [SBJsonParser new];
  id json = [jsonParser fragmentWithString:jsonString];
  [jsonString release];
  if (!json) {
    NSError* jsonError = [NSString stringWithFormat:@"JSON Parsing error: %@", [jsonParser errorTrace]];
    [self requestFailure:[NSError errorWithDomain:kFBErrorDomainKey
                                             code:FBAPIUnknownError
                                         userInfo:[NSDictionary dictionaryWithObject:jsonError
                                                                              forKey:kFBErrorMessageKey]]];
  } else {
    [self evaluateResponse:json];
  }
  [jsonParser release];

  // peace!
  [self release];
}

- (void)evaluateResponse:(id)json
{
  if (json == nil || ([json isKindOfClass:[NSDictionary class]] && [json objectForKey:@"error_code"] != nil)) {
    NSError *err = [self errorForResponse:json];
    [self requestFailure:err];
  } else {
    [self requestSuccess:json];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)err
{
  [self requestFailure:err];

  // peace!
  [self release];
}

- (void)requestSuccess:(id)json
{
  if (target && method && [target respondsToSelector:method]) {
    [target performSelector:method withObject:json];
  }
}

- (void)requestFailure:(NSError *)err
{
  [parentConnect failedQuery:self withError:err];

  if (target && errorMethod && [target respondsToSelector:errorMethod]) {
    [target performSelector:errorMethod withObject:err];
  }
}

#pragma mark Private Methods
- (NSError *)errorForResponse:(id)json
{
  if (json == nil || ![json isKindOfClass:[NSDictionary class]] || [json objectForKey:@"error_code"] == nil) {
    return [NSError errorWithDomain:kFBErrorDomainKey
                               code:FBAPIUnknownError
                           userInfo:[NSDictionary dictionaryWithObject:@"nil response"
                                                                forKey:kFBErrorMessageKey]];
  }

  int code = [[json objectForKey:@"error_code"] intValue];
  NSString *message = [json objectForKey:@"error_msg"];
  return [NSError errorWithDomain:kFBErrorDomainKey
                             code:code
                         userInfo:[NSDictionary dictionaryWithObject:message
                                                              forKey:kFBErrorMessageKey]];
}

- (NSError *)errorForException:(NSException *)exception
{
  NSString* message = [NSString stringWithFormat:@"%@: %@", [exception name], [exception reason]];
  NSLog(@"Caught %@", message);
  NSError* e = [NSError errorWithDomain:kFBErrorDomainKey
                                   code:FBAPIUnknownError
                               userInfo:[NSDictionary dictionaryWithObject:message forKey:kFBErrorMessageKey]];
  return e;
}

- (NSString *)description {
  return request;
}

@end
