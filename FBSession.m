//
//  FBSession.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBSession.h"
#import "FBCrypto.h"
#import "FBWebViewWindowController.h"
#import "NSStringAdditions.h"

#define kRESTServerURL @"http://api.facebook.com/restserver.php?"
#define kLoginURL @"http://www.facebook.com/login.php?api_key=%@&v=1.0&auth_token=%@&popup"
#define kAPIVersion @"1.0"

#define kSessionSecretDictKey @"kSessionSecretDictKey"
#define kSessionKeyDictKey @"kSessionKeyDictKey"
#define kSessionUIDDictKey @"kSessionUIDDictKey"
#define kErrorCodeInvalidSession 102

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

typedef enum {
  kIdle,
  kCreateToken,
  kWaitingForLoginWindow,
  kGetSession,
  kCallMethod,
  kFQLQuery,
  kFQLMultiquery,
  kExpireSession,
} ProtocolState;


@interface FBSession (Private)

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj;

- (NSString *)sigForArguments:(NSDictionary *)dict;
- (NSString *)urlEncodeArguments:(NSDictionary *)dict;
- (NSError *)errorForResponse:(NSXMLDocument *)xml;

- (void)sendMethodRequest:(NSString *)method withArguments:(NSDictionary *)dict;
- (void)createTokenResponseComplete:(NSXMLDocument *)xml;
- (void)getSessionResponseComplete:(NSXMLDocument *)xml;
- (void)callMethodResponseComplete:(NSXMLDocument *)xml;
- (void)FQLQueryResponseComplete:(NSXMLDocument *)xml;
- (void)FQLMultiqueryResponseComplete:(NSXMLDocument *)xml;
- (void)expireSessionResponseComplete:(NSXMLDocument *)xml;

- (void)webViewWindowClosed;

@end


@implementation FBSession

static FBSession *instance;

+ (FBSession *)session
{
  return instance;
}

+ (FBSession *)sessionWithAPIKey:(NSString *)key
                          secret:(NSString *)secret
                        delegate:(id)obj
{
  instance = [[self alloc] initWithAPIKey:key secret:secret delegate:obj];
  return instance;
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
  usingSavedSession = NO;

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

- (void)setPersistentSessionUserDefaultsKey:(NSString *)key
{
  [key retain];
  [userDefaultsKey release];
  userDefaultsKey = key;
}

- (void)clearStoredPersistentSession
{
  if (userDefaultsKey) {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:userDefaultsKey];
  }
}

- (BOOL)startLogin
{
  if (state != kIdle) {
    return NO;
  }

  NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
  if (userDefaultsKey && [ud objectForKey:userDefaultsKey]) {
    NSDictionary *dict = [ud objectForKey:userDefaultsKey];
    [uid release];
    [sessionKey release];
    [sessionSecret release];
    sessionKey = [[dict objectForKey:kSessionKeyDictKey] retain];
    sessionSecret = [[dict objectForKey:kSessionSecretDictKey] retain];
    uid = [[dict objectForKey:kSessionUIDDictKey] retain];
    usingSavedSession = YES;
    DELEGATE0(@selector(sessionCompletedLogin:));
  } else {
    state = kCreateToken;
    [self sendMethodRequest:@"Auth.createToken" withArguments:nil];
  }
  return YES;
}

- (BOOL)logout
{
  if (state != kIdle) {
    return NO;
  }

  state = kExpireSession;
  [self sendMethodRequest:@"Auth.expireSession" withArguments:nil];
  return YES;
}

- (BOOL)callMethod:(NSString *)method withArguments:(NSDictionary *)dict
{
  if (state != kIdle) {
    return NO;
  }

  state = kCallMethod;
  [self sendMethodRequest:method withArguments:dict];
  return YES;
}

- (BOOL)sendFQLQuery:(NSString *)query
{
  if (state != kIdle) {
    return NO;
  }

  NSDictionary *dict = [NSDictionary dictionaryWithObject:query forKey:@"query"];
  state = kFQLQuery;
  [self sendMethodRequest:@"Fql.query" withArguments:dict];
  return YES;
}

- (BOOL)sendFQLMultiquery:(NSDictionary *)queries
{
  if (state != kIdle) {
    return NO;
  }

  // Encode the NSDictionary in JSON.
  NSString *entryFormat = @"\"%@\" : \"%@\"";
  NSMutableArray *entries = [NSMutableArray array];
  for (NSString *key in queries) {
    NSString *escapedKey = [key stringByEscapingQuotesAndBackslashes];
    NSString *escapedVal = [[queries objectForKey:key] stringByEscapingQuotesAndBackslashes];
    [entries addObject:[NSString stringWithFormat:entryFormat, escapedKey,
                        escapedVal]];
  }

  NSString *finalString = [NSString stringWithFormat:@"{%@}",
                           [entries componentsJoinedByString:@","]];

  NSDictionary *dict = [NSDictionary dictionaryWithObject:finalString forKey:@"queries"];
  state = kFQLMultiquery;
  [self sendMethodRequest:@"Fql.multiquery" withArguments:dict];
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

- (void)sendMethodRequest:(NSString *)method withArguments:(NSDictionary *)dict
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

- (void)createTokenResponseComplete:(NSXMLDocument *)xml
{
  [authToken release];
  authToken = [[[xml rootElement] stringValue] retain];
  state = kWaitingForLoginWindow;

  NSString *url = [NSString stringWithFormat:kLoginURL, APIKey, authToken];
  [windowController showWithURL:[NSURL URLWithString:url]];
}

- (void)getSessionResponseComplete:(NSXMLDocument *)xml
{
  BOOL storeSession = NO;
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
    } else if ([[node name] isEqualToString:@"expires"]) {
      if ([[node stringValue] isEqualToString:@"0"] && userDefaultsKey) {
        storeSession = YES;
      }
    }
  }

  if (storeSession) {
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:sessionKey,
                          kSessionKeyDictKey, sessionSecret,
                          kSessionSecretDictKey, uid, kSessionUIDDictKey, nil];
    [[NSUserDefaults standardUserDefaults] setObject:dict forKey:userDefaultsKey];
  }
  DELEGATE0(@selector(sessionCompletedLogin:));
}

- (void)callMethodResponseComplete:(NSXMLDocument *)xml
{
  DELEGATE1(@selector(session:completedCallMethod:), xml);
}

- (void)FQLQueryResponseComplete:(NSXMLDocument *)xml
{
  DELEGATE1(@selector(session:completedQuery:), xml);
}

- (void)FQLMultiqueryResponseComplete:(NSXMLDocument *)xml
{
  DELEGATE1(@selector(session:completedMultiquery:), xml);
}

- (void)expireSessionResponseComplete:(NSXMLDocument *)xml
{
  [sessionKey release];
  sessionKey = nil;
  [sessionSecret release];
  sessionSecret = nil;
  [uid release];
  uid = nil;
  [self clearStoredPersistentSession];
  DELEGATE0(@selector(sessionCompletedLogout:));
}

- (void)webViewWindowClosed
{
  if (state == kWaitingForLoginWindow) {
    // The login window just closed; try a getSession request
    state = kGetSession;
    NSDictionary *dict = [NSDictionary dictionaryWithObject:authToken forKey:@"auth_token"];
    [self sendMethodRequest:@"Auth.getSession" withArguments:dict];
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
  NSXMLDocument *xml = [[NSXMLDocument alloc] initWithData:responseBuffer
                                                   options:0
                                                     error:nil];
  BOOL isError = ([[[xml rootElement] name] isEqualToString:@"error_response"]);
  if (isError) {
    NSError *err = [self errorForResponse:xml];
    if (usingSavedSession && [err code] == kErrorCodeInvalidSession) {
      // We were using a session key that we'd saved as permanent, and got
      // back an error saying it was invalid. Throw away the saved session
      // data and start a login from scratch.
      [sessionKey release];
      sessionKey = nil;
      [sessionSecret release];
      sessionSecret = nil;
      [uid release];
      uid = nil;
      usingSavedSession = NO;
      [self clearStoredPersistentSession];
      state = kIdle;
      [self startLogin];
    } else {
      switch (state) {
        case kCreateToken:
          DELEGATE1(@selector(session:failedLogin:), err);
          break;
        case kGetSession:
          DELEGATE1(@selector(session:failedLogin:), err);
          break;
        case kCallMethod:
          DELEGATE1(@selector(session:failedCallMethod:), err);
          break;          
        case kFQLQuery:
          DELEGATE1(@selector(session:failedQuery:), err);
          break;
        case kFQLMultiquery:
          DELEGATE1(@selector(session:failedMultiquery:), err);
          break;
        case kExpireSession:
          DELEGATE1(@selector(session:failedLogout:), err);
        default:
          break;
      }
      state = kIdle;
    }
  } else {
    ProtocolState tempState = state;
    state = kIdle;
    switch (tempState) {
      case kCreateToken:
        [self createTokenResponseComplete:xml];
        break;
      case kGetSession:
        [self getSessionResponseComplete:xml];
        break;
      case kCallMethod:
        [self callMethodResponseComplete:xml];
        break;                  
      case kFQLQuery:
        [self FQLQueryResponseComplete:xml];
        break;
      case kFQLMultiquery:
        [self FQLMultiqueryResponseComplete:xml];
        break;
      case kExpireSession:
        [self expireSessionResponseComplete:xml];
        break;
      default:
        break;
    }
  }
  [xml release];
}

@end

