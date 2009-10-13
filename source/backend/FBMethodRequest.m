//
//  FBRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBMethodRequest.h"
#import "FBCocoa.h"
#import "JSON.h"


@interface FBMethodRequest (Internal)

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err;

- (void)evaluateResponse:(id)json;

@end

@interface FBMethodRequest (Private)

- (NSError *)errorForResponse:(id)json;
- (NSError *)errorForException:(NSException *)exception;
- (void)finished;

@end


@interface FBConnect (FBRequestResults)

- (void)failedQuery:(FBMethodRequest *)query withError:(NSError *)err;

@end


@implementation FBMethodRequest

+(FBMethodRequest*) requestWithRequest:(NSString *)requestString
                          parent:(FBConnect *)parent
                          target:(id)tar
                        selector:(SEL)sel
                           error:(SEL)err
{
  return [[[FBMethodRequest alloc] initWithRequest:requestString
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
  if (self = [super initWithTarget:tar
                          selector:sel
                             error:err]) {
    requestStarted  = NO;
    requestFinished = NO;
    parentConnect   = [parent retain];
    request         = [requestString retain];
    responseBuffer  = [[NSMutableData alloc] init];
  }
  return self;
}

-(void)dealloc
{
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
  requestStarted = YES;
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

    if (connection) {
      [connection cancel];
      [connection release];
      connection = nil;
    }
    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
  } @catch (NSException *exception) {
    [self failure:[self errorForException:exception]];
    [self finished];
  }
}

- (void)finished
{
  requestFinished = YES;

  // peace!
  [self release];
}

- (void)retry
{
  // if it hasn't started, it's probably part of a batch or something, don't retry!
  if (!requestStarted) {
    return;
  }

  requestStarted  = NO;
  requestFinished = NO;
  [self start];
}

- (void)cancel
{
  // if we've already finished, it's too late.
  if (requestFinished) {
    return;
  }

  [connection cancel];
  [self failure:[NSError errorWithDomain:kFBErrorDomainKey
                                    code:FBAPIUnknownError
                                userInfo:[NSDictionary dictionaryWithObject:@"Request Cancelled"
                                                                     forKey:kFBErrorMessageKey]]];
  requestFinished = YES;
  [self finished];
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
    [self failure:[NSError errorWithDomain:kFBErrorDomainKey
                                      code:FBAPIUnknownError
                                  userInfo:[NSDictionary dictionaryWithObject:jsonError
                                                                       forKey:kFBErrorMessageKey]]];
  } else {
    [self evaluateResponse:json];
  }
  [jsonParser release];

  // peace!
  [self finished];
}

- (void)evaluateResponse:(id)json
{
  if (json == nil || ([json isKindOfClass:[NSDictionary class]] && [json objectForKey:@"error_code"] != nil)) {
    NSError *err = [self errorForResponse:json];
    [self failure:err];
  } else {
    [self success:json];
  }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)err
{
  [self failure:err];
  [self finished];
}

- (void)failure:(NSError *)err
{
  [parentConnect failedQuery:self withError:err];
  [super failure:err];
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
