//
//  FBSession.m
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import "FBSession.h"
#import "FBQuery.h"
#import "FBCrypto.h"
#import "FBWebViewWindowController.h"
#import "NSStringAdditions.h"

#define kRESTServerURL @"http://api.facebook.com/restserver.php?"
//#define kLoginURL @"http://www.facebook.com/login.php?api_key=%@&v=1.0&auth_token=%@&popup"
#define kLoginURL @"http://www.facebook.com/login.php?"
#define kLoginFailureURL @"http://www.facebook.com/connect/login_failure.html"
#define kLoginSuccessURL @"http://www.facebook.com/connect/login_success.html"

#define kAPIVersion @"1.0"

#define kSessionSecretDictKey @"kSessionSecretDictKey"
#define kSessionKeyDictKey @"kSessionKeyDictKey"
#define kSessionUIDDictKey @"kSessionUIDDictKey"

/*
 * These are shortcuts for calling delegate methods. They check to see if there
 * is a delegate and if the delegate responds to the selector passed as the
 * first argument. DELEGATEn is the call you use when there are n additional
 * arguments beyond "self" (since delegate methods should have the delegating
 * object as the first parameter).
 */
#define DELEGATE(sel) {if (delegate && [delegate respondsToSelector:(sel)]) {\
  [delegate performSelector:(sel) withObject:self];}}

typedef enum {
  kNothing,
  kLoginWindow,
  kExtendedPermissionsWindow,
} WindowState;


@interface FBSession (Private)

- (id)initWithAPIKey:(NSString *)key
              secret:(NSString *)secret
            delegate:(id)obj;

- (NSString *)sigForArguments:(NSDictionary *)dict;
- (NSString *)urlEncodeArguments:(NSDictionary *)dict;

- (void)createTokenResponseComplete:(NSXMLDocument *)xml;
- (void)getSessionResponseComplete:(NSXMLDocument *)xml;
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
  isLoggedIn = NO;

  windowController =
    [[FBWebViewWindowController alloc] initWithCloseTarget:self
                                                  selector:@selector(webViewWindowClosed)];
  windowState = kNothing;

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
  [super dealloc];
}

- (BOOL)usingSavedSession
{
  return usingSavedSession;
}

- (BOOL)isLoggedIn
{
  return isLoggedIn;
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

- (void)loginWithParams:(NSDictionary *)params
{
  [params retain];
  [loginParams release];
  loginParams = params;
  if (usingSavedSession) {
    [self validateSession];
  } else {    
    NSMutableDictionary *allLoginParams = [[NSMutableDictionary alloc] initWithDictionary:loginParams];
    [allLoginParams setObject:APIKey forKey:@"api_key"];
    [allLoginParams setObject:@"1.0" forKey:@"v"];
    [allLoginParams setObject:@"true" forKey:@"return_session"];
    [allLoginParams setObject:kLoginFailureURL forKey:@"cancel_url"];
    [allLoginParams setObject:kLoginSuccessURL forKey:@"next"];
    
    NSString *url = [NSString stringWithFormat:@"%@%@", kLoginURL, [self urlEncodeArguments:allLoginParams]];
    [windowController showWithURL:[NSURL URLWithString:url]];
  }
}

- (void)validateSession
{
  [self callMethod:@"users.isAppUser"
     withArguments:nil
            target:self
          selector:@selector(gotLoggedInUser:)
             error:@selector(noLoggedInUser:)]
}

- (void)gotLoggedInUser:(NSXMLDocument *)xml
{
  if ([xml rootElement] != nil) {
    isLoggedIn = YES;
  } else {
    [self noLoggedInUser];
  }
}

- (void)noLoggedInUser:(NSXMLDocument *)xml
{
  [self refreshSession];
}

//TODOTODOTODO
// I stopped about here, adding new session/login functions. nothing has been tested yet. this is probably really half baked


/* some of this shit surely needs to be copied over?
- (void)startLogin
{
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
    DELEGATE(@selector(sessionCompletedLogin:));
  } else {
    [self callMethod:@"Auth.createToken"
       withArguments:nil
              target:self
            selector:@selector(createTokenResponseComplete:)
               error:@selector(failedLogin:)];
  }
}
 */

- (void)logout
{
  [self callMethod:@"Auth.expireSession"
     withArguments:nil
            target:self
          selector:@selector(expireSessionResponseComplete:)
             error:@selector(failedLogout:)];
  [self clearStoredPersistentSession];
}

- (BOOL)hasSessionKey
{
  return (sessionKey != nil);
}

- (NSString *)uid
{
  return uid;
}

//==============================================================================
//==============================================================================
//==============================================================================

- (void)callMethod:(NSString *)method
     withArguments:(NSDictionary *)dict
            target:(id)target
          selector:(SEL)selector
             error:(SEL)error
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

  FBQuery *currentConnection = [[FBQuery alloc] initWithRequest:req target:target selector:selector error:error];
  [currentConnection start];
}

- (void)sendFQLQuery:(NSString *)query
              target:(id)target
            selector:(SEL)selector
               error:(SEL)error
{
  NSDictionary *dict = [NSDictionary dictionaryWithObject:query forKey:@"query"];
  [self callMethod:@"Fql.query"
     withArguments:dict
            target:target
          selector:selector
             error:error];
}

- (void)sendFQLMultiquery:(NSDictionary *)queries
                   target:(id)target
                 selector:(SEL)selector
                    error:(SEL)error
{
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
  [self callMethod:@"Fql.multiquery"
     withArguments:dict
            target:target
          selector:selector
             error:error];
}

//==============================================================================
//==============================================================================
//==============================================================================

#pragma mark Private Methods
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

//==============================================================================
//==============================================================================
//==============================================================================

- (void)createTokenResponseComplete:(NSXMLDocument *)xml
{
  [authToken release];
  authToken = [[[xml rootElement] stringValue] retain];

  NSString *url = [NSString stringWithFormat:kLoginURL, APIKey, authToken];
  windowState = kLoginWindow;
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
  DELEGATE(@selector(sessionCompletedLogin:));
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
  DELEGATE(@selector(sessionCompletedLogout:));
}

- (void)webViewWindowClosed
{
  if (windowState == kLoginWindow) {
    // The login window just closed; try a getSession request
    [self callMethod:@"Auth.getSession"
       withArguments:[NSDictionary dictionaryWithObject:authToken forKey:@"auth_token"]
              target:self
            selector:@selector(getSessionResponseComplete:)
               error:@selector(failedLogin:)];
  }
  windowState = kNothing;
}

- (void)refreshSession
{
  [sessionKey release];
  sessionKey = nil;
  [sessionSecret release];
  sessionSecret = nil;
  [uid release];
  uid = nil;
  usingSavedSession = NO;
  [self clearStoredPersistentSession];
  [self loginWithParams:loginParams];
}

@end
