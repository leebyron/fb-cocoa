//
//  FBConnect.h
//  FBCocoa
//
//  Copyright 2009 Facebook Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kFBErrorDomainKey @"kFBErrorDomainKey"
#define kFBErrorMessageKey @"kFBErrorMessageKey"

@class FBConnect;
@class FBSessionState;
@class FBWebViewWindowController;

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
  NSArray *requestedPermissions;

  BOOL isBatch;
  NSMutableArray *pendingBatchRequests;

  BOOL isLoggedIn;
  id delegate;

  FBWebViewWindowController *windowController;
}

/*!
 * Convenience constructor for an FBConnect.
 * @param key Your API key, provided by Facebook.
 * @param secret Your application secret, provided by Facebook.
 * @param delegate An object that will receive delegate method calls when
 * certain events happen in the session. See FBConnectDelegate.
 */
+ (FBConnect *)sessionWithAPIKey:(NSString *)key
                        delegate:(id)obj;

- (id)initWithAPIKey:(NSString *)key
            delegate:(id)obj;

/*!
 * If your application is going to call methods which require an application
 * secret, you must specify it here. Otherwise it is best to not include it in
 * your application which may easily be decompiled and compromised.
 *
 * http://wiki.developers.facebook.com/index.php/Session_Secret_and_API_Methods
 */
- (void)setSecret:(NSString *)secret;

/*!
 * Causes the session to start the login process. This method is asynchronous;
 * i.e. it returns immediately, and the session is not necessarily logged in
 * when this method returns. The receiver's delegate will receive a
 * -sessionCompletedLogin: or -session:failedLogin: message when the process
 * completes. See FBConnectDelegate.
 *
 * Note that in the process of logging in, FBConnect may cause a window to
 * appear onscreen, displaying a Facebook webpage where the user must enter
 * their login credentials.
 *
 * Permissions should be an array of required permissions. For desktop
 * applications, it's highly recommended that you require "offline_access" in
 * order to obtain an infinite session.
 *
 * http://wiki.developers.facebook.com/index.php/Extended_application_permission
 */
- (void)loginWithPermissions:(NSArray *)perms;

/*!
 * Tests to see if the user has accepted a particular permission
 *
 * @result True if the permission has been granted
 */
- (BOOL)hasPermission:(NSString *)perm;

/*!
 * Logs out the current session. If a user defaults key for storing persistent
 * sessions has been set, this method clears the stored session, if any.
 */
- (void)logout;

/*!
 * Returns true if this Connect session is good to go
 */
- (BOOL)isLoggedIn;

/*!
 * Returns the logged-in user's uid as a string. If the session has not been
 * logged in, returns nil. Note that this may return a non-nil value despite
 * the session key being expired.
 */
- (NSString *)uid;

/*!
 * Sends an API request with a particular method.
 */
- (void)callMethod:(NSString *)method
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
- (void)fqlQuery:(NSString *)query
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
- (void)fqlMultiquery:(NSDictionary *)queries
               target:(id)target
             selector:(SEL)selector
                error:(SEL)error;

/*!
 * Call to start a Batch API Request
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
- (void)sendBatch;

@end
