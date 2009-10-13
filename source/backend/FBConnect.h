//
//  FBConnect.h
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FBRequest.h"

#define kFBErrorDomainKey @"kFBErrorDomainKey"
#define kFBErrorMessageKey @"kFBErrorMessageKey"


@class FBConnect;
@class FBSessionState;
@class FBWebViewWindowController;
@class FBCallback;

/*!
 * @category FBConnectDelegate(NSObject)
 * These are methods that FBConnect may call on its delegate. They are all
 * optional.
 */
@interface NSObject (FBConnectDelegate)

/*!
 * Called when the FBConnect has completed logging in to Facebook.
 */
- (void)FBConnectLoggedIn:(FBConnect *)fbc;

/*!
 * Called when a login request has failed.
 */
- (void)FBConnectErrorLoggingIn:(FBConnect *)fbc;

/*!
 * Called when the FBConnect has completed logging out of Facebook.
 */
- (void)FBConnectLoggedOut:(FBConnect *)fbc;

/*!
 * Called when a logout request has failed.
 */
- (void)FBConnectErrorLoggingOut:(FBConnect *)fbc;

@end


/*!
 * @class FBConnect
 *
 * FBConnect handles all transactions with the Facebook API: logging in and
 * sending FQL queries.
 */
@interface FBConnect : NSObject {
  NSString *APIKey;
  NSString *appSecret;
  FBSessionState *sessionState;
  id delegate;
  BOOL isLoggedIn;

  NSSet *requiredPermissions;
  NSSet *optionalPermissions;
  NSMutableSet *requestedPermissions;

  BOOL isBatch;
  NSMutableArray *pendingBatchRequests;

  FBCallback* permissionCallback;

  FBWebViewWindowController *windowController;
}


////////////////////////////////////////////////////////////////////////////////
// Creating an FBConnect instance

/*!
 * Convenience constructor for an FBConnect.
 * @param key Your API key, provided by Facebook.
 * @param delegate An object that will receive delegate method calls when
 * certain events happen in the session. See FBConnectDelegate.
 */
+ (FBConnect *)sessionWithAPIKey:(NSString *)key
                        delegate:(id)obj;

/*!
 * If your application is going to call methods which require an application
 * secret, you must specify it here. Otherwise it is best to not include it in
 * your application which may easily be decompiled and compromised.
 *
 * http://wiki.developers.facebook.com/index.php/Session_Secret_and_API_Methods
 */
- (void)setSecret:(NSString *)secret;


////////////////////////////////////////////////////////////////////////////////
// Logging in, logging out, permissions

/*!
 * Causes the session to start the login process. This method is asynchronous;
 * i.e. it returns immediately, and the session is not necessarily logged in
 * when this method returns. The receiver's delegate will receive a
 * -FBConnectLoggedIn: or -FBConnectErrorLoggingIn: message when the process
 * completes. See FBConnectDelegate.
 *
 * Note that in the process of logging in, FBConnect may cause a window to
 * appear onscreen, displaying a Facebook webpage where the user must enter
 * their login credentials.
 *
 * Required Permissions is a set of permissions the user must grant for this
 * application to run. If any are refused, the login will not complete.
 *
 * Optional Permissions is a set of permissions which the user is not required
 * to grant for the application to function.
 *
 * http://wiki.developers.facebook.com/index.php/Extended_application_permission
 */
- (void)loginWithRequiredPermissions:(NSSet*)req
                 optionalPermissions:(NSSet*)opt;

/*!
 * Logs out the current session. If a user defaults key for storing persistent
 * sessions has been set, this method clears the stored session, if any.
 */
- (void)logout;

/*!
 * Returns true if this Connect session is logged in and valid
 */
- (BOOL)isLoggedIn;

/*!
 * Returns the logged-in user's uid as a string. If the session has not been
 * logged in, returns nil. Note that this may return a non-nil value despite
 * the session key being expired.
 */
- (NSString *)uid;

/*!
 * If these permissions don't exist, launch a WebKit window requesting them.
 * Calls selector on target when request permissions window has closed, with an
 * array of accepted permissions as the object.
 */
- (void)requestPermissions:(NSSet*)perms
                    target:(id)target
                  selector:(SEL)selector;

/*!
 * Tests to see if the user has accepted a particular permission
 *
 * @result True if the permission has been granted
 */
- (BOOL)hasPermission:(NSString*)perm;


////////////////////////////////////////////////////////////////////////////////
// Calling API Methods

/*!
 * Sends an API request with a particular method.
 */
- (id<FBRequest>)callMethod:(NSString *)method
           withArguments:(NSDictionary *)dict
                  target:(id)target
                selector:(SEL)selector
                   error:(SEL)error;

/*!
 * Sends an FQL query within the session. See the Facebook Developer Wiki for
 * information about FQL. This method is asynchronous; the receiver's delegate
 * will receive a -session:receivedResponse: message when the process completes.
 * See FBConnectDelegate.
 */
- (id<FBRequest>)fqlQuery:(NSString *)query
                target:(id)target
              selector:(SEL)selector
                 error:(SEL)error;

/*!
 * Sends an FQL.multiquery request. See the Facebook Developer Wiki for
 * information about FQL. This method is asynchronous; the receiver's delegate
 * will receive a -session:receivedResponse: message when the process completes.
 * See FBConnectDelegate.
 *
 * @param queries A dictionary mapping strings (query names) to strings
 * (FQL query strings).
 */
- (id<FBRequest>)fqlMultiquery:(NSDictionary *)queries
                     target:(id)target
                   selector:(SEL)selector
                      error:(SEL)error;


////////////////////////////////////////////////////////////////////////////////
// API Method Batch requests

/*!
 * Call to start a Batch API Request
 *
 * Batch requests delay any subsequent API Method calls until "sendBatch" is
 * called, resulting in one HTTP request which can result in higher performance.
 *
 * Note: there is limit of 20 individual operations that can be performed in a
 * single batch execution.
 *
 * [connectSession startBatch];
 * [connectSession callMethod:@"Stream.publish" ...];
 * [connectSession callMethod:@"Stream.get" ...];
 * [connectSession sendBatch];
 */
- (void)startBatch;

/*!
 * @returns YES if startBatch has been called and sendBatch has not
 */
- (BOOL)pendingBatch;

/*!
 * If a batch request has been started, this cancels the batch
 */
- (void)cancelBatch;

/*!
 * Sends the collected API requests as a Batch Run
 */
- (id<FBRequest>)sendBatch;

@end
