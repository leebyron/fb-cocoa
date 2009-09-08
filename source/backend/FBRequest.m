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


@interface FBRequest (Private)

- (NSError *)errorForResponse:(id)json;
- (NSError *)errorForException:(NSException *)exception;

@end


@interface FBConnect (FBRequestResults)

- (void)failedQuery:(FBRequest *)query withError:(NSError *)err;

@end


@implementation FBRequest

-(id)initWithRequest:(NSString *)requestString
              parent:(FBConnect *)parent
              target:(id)tar
            selector:(SEL)sel
               error:(SEL)err
{
  if (!(self = [super init])) {
    return nil;
  }

  request = [requestString retain];
  target = [tar retain];
  method = sel;
  parentConnect = parent;
  errorMethod = err;
  responseBuffer = [[NSMutableData alloc] init];

  return self;
}

-(void)dealloc
{
  [request release];
  [target release];
  [responseBuffer release];
  [connection release];
  [super dealloc];
}

- (void)start
{
  @try {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kRESTServerURL, request]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:kRequestTimeout];
    [req setHTTPMethod:@"GET"];
    [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];
    [req setValue:@"FBConnect/0.2 (OS X)" forHTTPHeaderField:@"User-Agent"];

    connection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
  } @catch (NSException *exception) {
    [self requestFailure:[self errorForException:exception]];
  }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [responseBuffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  NSString* jsonString = [[[NSString alloc] initWithData:responseBuffer encoding:NSUTF8StringEncoding] autorelease];
  SBJsonParser* jsonParser = [SBJsonParser new];
  id json = [jsonParser fragmentWithString:jsonString];
  if (!json) {
    NSError* jsonError = [NSString stringWithFormat:@"JSON Parsing error: %@", [jsonParser errorTrace]];
    [self requestFailure:[NSError errorWithDomain:kFBErrorDomainKey
                                             code:FBAPIUnknownError
                                         userInfo:[NSDictionary dictionaryWithObject:jsonError
                                                                              forKey:kFBErrorMessageKey]]];
  }
  [jsonParser release];

  [self evaluateResponse:json];

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

  // laaater!
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
