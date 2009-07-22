//
//  FBSession.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBSession.h"
#import "FBCrypto.h"
#import "FBWebViewWindowController.h"

#define kRESTServerURL @"http://www.facebook.com/restserver.php?"
#define kLoginURL @"http://www.facebook.com/login.php?api_key=%@&v=1.0&auth_token=%@"
#define kAPIVersion @"1.0"

/*
 * These are shortcuts for calling delegate methods. They check to see if there
 * is a delegate and if the delegate responds to the selector passed as the
 * first argument. DELEGATEn is the call you use when there are n additional
 * arguments beyond "self" (since delegate methods should have the delegating
 * object as the first parameter).
 */
#define DELEGATE0(sel) {if (delegate && [delegate respondsToSelector:(sel)]) {\
  [delegate performSelector:(sel) withObject:self];}}
#define DELEGATE1(sel, arg) {if (delegate && [delegate respondsToSelector:(sel)]) {\
  [delegate performSelector:(sel) withObject:self withObject:(arg)];}}

enum {
  kIdle,
  kCreateToken,
  kGetSession,
  kFQLQuery,
} ProtocolState;


@interface FBSession (Private)

- (NSString *)sigForArguments:(NSDictionary *)dict;
- (NSString *)urlEncodeArguments:(NSDictionary *)dict;
- (void)sendRequestForMethod:(NSString *)method args:(NSDictionary *)dict;
- (NSError *)errorForResponse:(NSXMLDocument *)xml;

- (void)createTokenResponseComplete;
- (void)getSessionResponseComplete;
- (void)FQLQueryResponseComplete;

- (void)webViewWindowClosed;

@end


@implementation FBSession

+ (FBSession *)sessionWithAPIKey:(NSString *)key
                          secret:(NSString *)secret
                        delegate:(id)obj
{
  return [[[self alloc] initWithAPIKey:key secret:secret delegate:obj] autorelease];
}

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj
{
  if (!(self = [super init])) {
    return nil;
  }

  APIKey = [key retain];
  appSecret = [secret retain];
  delegate = obj;

  responseBuffer = [[NSMutableData alloc] init];
  state = kIdle;

  windowController =
    [[FBWebViewWindowController alloc] initWithCloseTarget:self
                                                  selector:@selector(webViewWindowClosed)];

  return self;
}

- (void)dealloc
{
  [APIKey release];
  [appSecret release];
  [sessionKey release];
  [sessionSecret release];
  [uid release];
  [authToken release];
  [responseBuffer release];
  [currentConnection release];
  [super dealloc];
}

- (BOOL)startLogin
{
  if (state != kIdle) {
    return NO;
  }
  state = kCreateToken;
  [self sendRequestForMethod:@"Auth.createToken" args:nil];
  return YES;
}

- (BOOL)sendFQLQuery:(NSString *)query
{
  if (state != kIdle) {
    return NO;
  }

  NSDictionary *dict = [NSDictionary dictionaryWithObject:query forKey:@"query"];
  state = kFQLQuery;
  [self sendRequestForMethod:@"Fql.query" args:dict];
  return YES;
}

- (BOOL)hasSessionKey
{
  return (sessionKey != nil);
}

- (NSString *)uid
{
  return uid;
}

- (NSString *)sigForArguments:(NSDictionary *)dict
{
  NSArray *sortedKeys = [[dict allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
  NSMutableString *args = [NSMutableString string];
  for (NSString *key in sortedKeys) {
    [args appendString:key];
    [args appendString:@"="];
    [args appendString:[dict objectForKey:key]];
  }

  if (sessionKey) {
    [args appendString:sessionSecret];
  } else {
    [args appendString:appSecret];
  }
  return [FBCrypto hexMD5:args];
}

- (NSString *)urlEncodeArguments:(NSDictionary *)dict
{
  NSMutableString *result = [NSMutableString string];

  for (NSString *key in dict) {
    if ([result length] > 0) {
      [result appendString:@"&"];
    }
    NSString *encodedKey = [key stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    NSString *encodedValue =
      [[dict objectForKey:key] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    [result appendString:encodedKey];
    [result appendString:@"="];
    [result appendString:encodedValue];
  }
  return result;
}

- (void)sendRequestForMethod:(NSString *)method args:(NSDictionary *)dict
{
  NSMutableDictionary *args;

  if (dict) {
    args = [NSMutableDictionary dictionaryWithDictionary:dict];
  } else {
    args = [NSMutableDictionary dictionary];
  }
  [args setObject:method forKey:@"method"];
  [args setObject:APIKey forKey:@"api_key"];
  [args setObject:kAPIVersion forKey:@"v"];
  [args setObject:@"XML" forKey:@"format"];
  [args setObject:[[NSNumber numberWithLong:time(NULL)] stringValue]
           forKey:@"call_id"];
  if (sessionKey) {
    [args setObject:sessionKey forKey:@"session_key"];
  }

  NSString *sig = [self sigForArguments:args];
  [args setObject:sig forKey:@"sig"];

  NSString *server = kRESTServerURL;
  NSURL *url = [NSURL URLWithString:[server stringByAppendingString:[self urlEncodeArguments:args]]];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
  [req setHTTPMethod:@"GET"];
  [req addValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-type"];

  [currentConnection release];
  currentConnection = [[NSURLConnection alloc] initWithRequest:req delegate:self];
  [responseBuffer setLength:0];
  [currentConnection start];
}

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

- (void)createTokenResponseComplete
{
  NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:responseBuffer
                                                   options:0
                                                     error:nil];
  if ([[[xml rootElement] name] isEqualToString:@"Auth_createToken_response"]) {
    [authToken release];
    authToken = [[[xml rootElement] stringValue] retain];

    NSString *url = [NSString stringWithFormat:kLoginURL, APIKey, authToken];
    [windowController showWithURL:[NSURL URLWithString:url]];
  } else {
    NSError *err = [self errorForResponse:xml];
    DELEGATE1(@selector(session:failedLogin:), err);
  }
  [xml release];
}

- (void)getSessionResponseComplete
{
  NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:responseBuffer
                                                   options:0
                                                     error:nil];
  state = kIdle;
  if ([[[xml rootElement] name] isEqualToString:@"Auth_getSession_response"]) {
    [sessionSecret release];
    [sessionKey release];
    [uid release];
    sessionSecret = nil;
    sessionKey = nil;
    uid = nil;
    for (NSXMLNode *node in [[xml rootElement] children]) {
      if ([[node name] isEqualToString:@"session_key"]) {
        sessionKey = [[node stringValue] retain];
      } else if ([[node name] isEqualToString:@"secret"]) {
        sessionSecret = [[node stringValue] retain];
      } else if ([[node name] isEqualToString:@"uid"]) {
        uid = [[node stringValue] retain];
      }
    }

    DELEGATE0(@selector(sessionCompletedLogin:));
  } else {
    NSError *err = [self errorForResponse:xml];
    DELEGATE1(@selector(session:failedLogin:), err);
  }
  [xml release];
}

- (void)FQLQueryResponseComplete
{
  NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:responseBuffer
                                                   options:0
                                                     error:nil];
  state = kIdle;
  if ([[[xml rootElement] name] isEqualToString:@"Fql_query_response"]) {
    DELEGATE1(@selector(session:completedQuery:), xml);
  } else {
    NSError *err = [self errorForResponse:xml];
    DELEGATE1(@selector(session:failedQuery:), err);
  }
  [xml release];
}

- (void)webViewWindowClosed
{
  if (state == kCreateToken) {
    // The login window just closed; try a getSession request
    state = kGetSession;
    NSDictionary *dict = [NSDictionary dictionaryWithObject:authToken forKey:@"auth_token"];
    [self sendRequestForMethod:@"Auth.getSession" args:dict];
  }
}

@end


@implementation FBSession (NSURLConnectionDelegate)

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
  [responseBuffer appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
  switch (state) {
    case kCreateToken:
      [self createTokenResponseComplete];
      break;
    case kGetSession:
      [self getSessionResponseComplete];
      break;
    case kFQLQuery:
      [self FQLQueryResponseComplete];
      break;
    default:
      break;
  }
}

@end

