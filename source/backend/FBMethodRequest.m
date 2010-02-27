//
//  FBRequest.m
//  FBCocoa
//
//  Created by Lee Byron on 7/30/09.
//  Copyright 2009 Facebook. All rights reserved.
//

#import "FBMethodRequest.h"
#import "FBCocoa.h"
#import "FBConnect_Internal.h"
#import "JSON.h"


@interface FBMethodRequest (Internal)

-(id)initWithRequest:(NSString*)requestString
              parent:(FBConnect*)parent
              target:(id)tar
            selector:(SEL)sel;

- (id)initWithData:(NSData*)postData
            parent:(FBConnect*)parent
            target:(id)tar
          selector:(SEL)sel;

- (void)evaluateResponse:(id)json;

@end

@interface FBMethodRequest (Private)

- (NSError*)errorForResponse:(id)json;
- (NSError*)errorForException:(NSException*)exception;
- (void)finished;

@end


@interface FBConnect (FBRequestResults)

- (void)failedQuery:(FBMethodRequest*)query
          withError:(NSError*)err;

@end


@implementation FBMethodRequest

+ (FBMethodRequest*) requestWithRequest:(NSString*)requestString
                                 parent:(FBConnect*)parent
                                 target:(id)tar
                               selector:(SEL)sel
{
  return [[[FBMethodRequest alloc] initWithRequest:requestString
                                            parent:parent
                                            target:tar
                                          selector:sel] autorelease];
}

+ (FBMethodRequest*)requestWithData:(NSData*)postData
                             parent:(FBConnect*)parent
                             target:(id)tar
                           selector:(SEL)sel
{
  return [[[FBMethodRequest alloc] initWithData:postData
                                         parent:parent
                                         target:tar
                                       selector:sel] autorelease];
}

- (id)initWithRequest:(NSString*)requestString
               parent:(FBConnect*)parent
               target:(id)tar
             selector:(SEL)sel
{
  if (self = [super initWithTarget:tar selector:sel]) {
    requestStarted  = NO;
    requestFinished = NO;
    parentConnect   = [parent retain];
    request         = [requestString retain];
    responseBuffer  = [[NSMutableData alloc] init];
  }
  return self;
}

- (id)initWithData:(NSData*)postData
            parent:(FBConnect*)parent
            target:(id)tar
          selector:(SEL)sel
{
  if (self = [super initWithTarget:tar selector:sel]) {
    requestStarted  = NO;
    requestFinished = NO;
    parentConnect   = [parent retain];
    data            = [postData retain];
    responseBuffer  = [[NSMutableData alloc] init];
  }
  return self;
}

- (void)dealloc
{
  [request release];
  [data release];
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
    NSURL* url;
    if (request) {
      url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@", [parentConnect restURL], request]];
    } else {
      url = [NSURL URLWithString:[parentConnect restURL]];
    }

    #ifdef NSURLRequestReloadIgnoringLocalCacheData
      NSURLRequestCachePolicy policy = NSURLRequestReloadIgnoringLocalCacheData;
    #else
      NSURLRequestCachePolicy policy = NSURLRequestUseProtocolCachePolicy;
    #endif

    NSMutableURLRequest* req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:policy
                                                   timeoutInterval:kRequestTimeout];
    if (data) {
      [req setHTTPBody:data];
      [req setHTTPMethod:@"POST"];
      NSString* contentType =
        [NSString stringWithFormat:@"multipart/form-data; boundary=%@",
                                   kPostFormDataBoundary];
      [req addValue:contentType forHTTPHeaderField:@"Content-Type"];
    } else {
      [req setHTTPMethod:@"GET"];
      [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    }
    [req setValue:@"FBConnect/0.3 (OS X)" forHTTPHeaderField:@"User-Agent"];

    if (connection) {
      [connection cancel];
      [connection release];
      connection = nil;
    }
    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
  } @catch (NSException* exception) {
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

- (void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)aData
{
  [responseBuffer appendData:aData];
}

- (void)connectionDidFinishLoading:(NSURLConnection*)connection
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
  if (json == nil ||
      ([json isKindOfClass:[NSDictionary class]] &&
       [json objectForKey:@"error_code"] != nil) ||
      json == 0
    ) {
    [self failure:[self errorForResponse:json]];
  } else {
    [self success:json];
  }
}

- (void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)err
{
  [self failure:err];
  [self finished];
}

- (void)failure:(NSError*)err
{
  [parentConnect failedQuery:self withError:err];
  [super failure:err];
}

#pragma mark Private Methods
- (NSError*)errorForResponse:(id)json
{
  if (json == nil ||
      ![json isKindOfClass:[NSDictionary class]] ||
      [json objectForKey:@"error_code"] == nil) {
    return [NSError errorWithDomain:kFBErrorDomainKey
                               code:FBAPIUnknownError
                           userInfo:[NSDictionary dictionaryWithObject:@"nil response"
                                                                forKey:kFBErrorMessageKey]];
  }

  int code = [[json objectForKey:@"error_code"] intValue];
  NSString* message = [json objectForKey:@"error_msg"];
  return [NSError errorWithDomain:kFBErrorDomainKey
                             code:code
                         userInfo:[NSDictionary dictionaryWithObject:message
                                                              forKey:kFBErrorMessageKey]];
}

- (NSError*)errorForException:(NSException*)exception
{
  NSString* message = [NSString stringWithFormat:@"%@: %@", [exception name], [exception reason]];
  NSLog(@"Caught %@", message);
  return [NSError errorWithDomain:kFBErrorDomainKey
                             code:FBAPIUnknownError
                         userInfo:[NSDictionary dictionaryWithObject:message forKey:kFBErrorMessageKey]];
}

- (NSString*)description {
  return request;
}

@end
