//
//  BranchNetworkScenarioTests.m
//  Branch-TestBed
//
//  Created by Graham Mueller on 4/20/15.
//  Copyright (c) 2015 Branch Metrics. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BranchTest.h"
#import <OCMock/OCMock.h>
#import "Branch.h"
#import "BNCServerRequestQueue.h"
#import "BNCPreferenceHelper.h"

@interface BranchNetworkScenarioTests : BranchTest

@property (assign, nonatomic) BOOL hasExceededExpectations;

@end

@implementation BranchNetworkScenarioTests

- (void)setUp {
    [super setUp];

    // Fake branch key
    id preferenceHelperMock = OCMClassMock([BNCPreferenceHelper class]);
    [[[preferenceHelperMock stub] andReturn:@"foo"] getBranchKey];
}

#pragma mark - Scenario 1

// Connection starts good -- InitSession completes
// Connection drops
// Request is made, should fail and call callback.
// "Re Open" occurs, network is back
// InitSession should occur again
// Subsequent requests should occur as normal
- (void)testScenario1 {
    id serverInterfaceMock = OCMClassMock([BranchServerInterface class]);
    
    Branch *branch = [[Branch alloc] initWithInterface:serverInterfaceMock queue:[[BNCServerRequestQueue alloc] init] cache:[[BNCLinkCache alloc] init]];
    [branch setAppListCheckEnabled:NO];

    XCTestExpectation *scenario1Expectation1 = [self expectationWithDescription:@"Scenario1 Expectation1"];

    // Start off with a good connection
    [self initSessionExpectingSuccess:branch serverInterface:serverInterfaceMock callback:^{
        // Simulate connection drop
        // Expect failure
        [self makeFailingNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
            [self safelyFulfillExpectation:scenario1Expectation1];
        }];
    }];
    
    [self awaitExpectations];
    [self resetExpectations];

    XCTestExpectation *scenario1Expectation2 = [self expectationWithDescription:@"Scenario1 Expectation2"];
    
    // Simulate re-open, expect init to be called again
    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    
    // Then make another request, which should play through fine
    [self makeSuccessfulNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario1Expectation2];
    }];

    [self awaitExpectations];
    [serverInterfaceMock verify];
}


#pragma mark - Scenario 2

// Connection starts bad -- InitSession fails
// Connection drops
// Request is made, should fail and call callback.
// "Re Open" occurs, network is back
// InitSession should occur again
// Subsequent requests should occur as normal
- (void)testScenario2 {
    id serverInterfaceMock = OCMClassMock([BranchServerInterface class]);
    
    Branch *branch = [[Branch alloc] initWithInterface:serverInterfaceMock queue:[[BNCServerRequestQueue alloc] init] cache:[[BNCLinkCache alloc] init]];
    [branch setAppListCheckEnabled:NO];

    XCTestExpectation *scenario2Expectation1 = [self expectationWithDescription:@"Scenario2 Expectation1"];
    
    // Start off with a bad connection
    [self initSessionExpectingFailure:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario2Expectation1];
    }];

    [self awaitExpectations];
    [self resetExpectations];

    XCTestExpectation *scenario2Expectation2 = [self expectationWithDescription:@"Scenario2 Expectation2"];

    // Request should fail
    [self makeFailingNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
        [serverInterfaceMock stopMocking];

        [self safelyFulfillExpectation:scenario2Expectation2];
    }];

    [self awaitExpectations];
    [self resetExpectations];

    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidBecomeActiveNotification object:nil];
    [self overrideBranch:branch initHandler:[self callbackExpectingSuccess:NULL]];

    XCTestExpectation *scenario2Expectation3 = [self expectationWithDescription:@"Scenario2 Expectation3"];
    
    // Then make another request, which should play through fine
    [self makeSuccessfulNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario2Expectation3];
    }];

    [self awaitExpectations];
    [serverInterfaceMock verify];
}


//#pragma mark - Scenario 3
//
//// Connection starts good -- InitSession completes
//// Connection drops
//// Request is made, should fail and call callback.
//// Without closing the app (no re-open event to kick off InitSession), connection returns
//// Subsequent requests should occur as normal
- (void)testScenario3 {
    id serverInterfaceMock = OCMClassMock([BranchServerInterface class]);
    
    Branch *branch = [[Branch alloc] initWithInterface:serverInterfaceMock queue:[[BNCServerRequestQueue alloc] init] cache:[[BNCLinkCache alloc] init]];
    [branch setAppListCheckEnabled:NO];

    XCTestExpectation *scenario3Expectation1 = [self expectationWithDescription:@"Scenario3 Expectation1"];
    
    // Start off with a good connection
    [self initSessionExpectingSuccess:branch serverInterface:serverInterfaceMock callback:^{
        // Simulate connection drop
        // Expect failure
        [self makeFailingNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
            [self safelyFulfillExpectation:scenario3Expectation1];
        }];
    }];

    [self awaitExpectations];
    [self resetExpectations];
    
    XCTestExpectation *scenario3Expectation2 = [self expectationWithDescription:@"Scenario3 Expectation2"];
    
    // Simulate network return, shouldn't call init!
    [serverInterfaceMock stopMocking];
    
    // Request should just work
    [self makeSuccessfulNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario3Expectation2];
    }];

    [self awaitExpectations];
    [serverInterfaceMock verify];
}


//#pragma mark - Scenario 4
//
//// Connection starts bad -- InitSession fails
//// Connection drops
//// Request is made, should fail and call callback.
//// Without closing the app (no re-open event to kick off InitSession), connection returns
//// Subsequent requests should cause an InitSession, which should succeed
//// Request should complete as normal
- (void)testScenario4 {
    id serverInterfaceMock = OCMClassMock([BranchServerInterface class]);
    
    Branch *branch = [[Branch alloc] initWithInterface:serverInterfaceMock queue:[[BNCServerRequestQueue alloc] init] cache:[[BNCLinkCache alloc] init]];
    [branch setAppListCheckEnabled:NO];

    XCTestExpectation *scenario4Expectation1 = [self expectationWithDescription:@"Scenario4 Expectation1"];
    
    // Start off with a bad connection
    [self initSessionExpectingFailure:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario4Expectation1];
    }];
    
    [self awaitExpectations];
    [self resetExpectations];
    
    XCTestExpectation *scenario4Expectation2 = [self expectationWithDescription:@"Scenario4 Expectation2"];

    // Request should fail
    [self makeFailingNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario4Expectation2];
    }];
    
    [self awaitExpectations];
    [self resetExpectations];
    
    XCTestExpectation *scenario4Expectation3 = [self expectationWithDescription:@"Scenario4 Expectation3"];

    // Simulate network return, shouldn't call init!
    [serverInterfaceMock stopMocking];
    
    // However, making another request when not initialized should make an init
    [self mockSuccesfulInit:serverInterfaceMock];
    [self overrideBranch:branch initHandler:[self callbackExpectingSuccess:NULL]];
    
    [self makeSuccessfulNonReplayableRequest:branch serverInterface:serverInterfaceMock callback:^{
        [self safelyFulfillExpectation:scenario4Expectation3];
    }];
    
    [self awaitExpectations];
    [serverInterfaceMock verify];
}


#pragma mark - Internals


- (void)initSessionExpectingSuccess:(Branch *)branch serverInterface:(id)serverInterfaceMock callback:(void (^)(void))callback {
    [self mockSuccesfulInit:serverInterfaceMock];

    [branch initSessionAndRegisterDeepLinkHandler:[self callbackExpectingSuccess:callback]];
}

- (void)initSessionExpectingFailure:(Branch *)branch serverInterface:(id)serverInterfaceMock callback:(void (^)(void))callback {
    __block BNCServerCallback openOrInstallCallback;
    id openOrInstallCallbackCheckBlock = [OCMArg checkWithBlock:^BOOL(BNCServerCallback callback) {
        openOrInstallCallback = callback;
        return YES;
    }];
    
    id openOrInstallInvocation = ^(NSInvocation *invocation) {
        openOrInstallCallback(nil, [NSError errorWithDomain:NSURLErrorDomain code:-1004 userInfo:nil]);
    };

    [[[serverInterfaceMock stub] andDo:openOrInstallInvocation] registerInstall:NO callback:openOrInstallCallbackCheckBlock];
    [[[serverInterfaceMock stub] andDo:openOrInstallInvocation] registerOpen:NO callback:openOrInstallCallbackCheckBlock];
    
    [branch initSessionAndRegisterDeepLinkHandler:[self callbackExpectingFailure:callback]];
}

- (void)makeFailingNonReplayableRequest:(Branch *)branch serverInterface:(id)serverInterfaceMock callback:(void (^)(void))callback {
    __block BNCServerCallback badRequestCallback;
    id badRequestCheckBlock = [OCMArg checkWithBlock:^BOOL(BNCServerCallback callback) {
        badRequestCallback = callback;
        return YES;
    }];
    
    id badRequestInvocation = ^(NSInvocation *invocation) {
        badRequestCallback(nil, [NSError errorWithDomain:NSURLErrorDomain code:-1004 userInfo:nil]);
    };
    
    [[[serverInterfaceMock expect] andDo:badRequestInvocation] getReferralCountsWithCallback:badRequestCheckBlock];
    
    [branch loadActionCountsWithCallback:^(BOOL changed, NSError *error) {
        XCTAssertNotNil(error);
        callback();
    }];
}

- (void)makeSuccessfulNonReplayableRequest:(Branch *)branch serverInterface:(id)serverInterfaceMock callback:(void (^)(void))callback {
    BNCServerResponse *goodResponse = [[BNCServerResponse alloc] init];
    goodResponse.statusCode = @200;
    
    __block BNCServerCallback goodRequestCallback;
    id goodRequestCheckBlock = [OCMArg checkWithBlock:^BOOL(BNCServerCallback callback) {
        goodRequestCallback = callback;
        return YES;
    }];
    
    id goodRequestInvocation = ^(NSInvocation *invocation) {
        goodRequestCallback(goodResponse, nil);
    };
    
    [[[serverInterfaceMock expect] andDo:goodRequestInvocation] getReferralCountsWithCallback:goodRequestCheckBlock];
    
    [branch loadActionCountsWithCallback:^(BOOL changed, NSError *error) {
        XCTAssertNil(error);
        callback();
    }];
}

#pragma mark - Callbacks

- (callbackWithParams)callbackExpectingSuccess:(void (^)(void))callback {
    __block BOOL initCalled = NO;
    return ^(NSDictionary *params, NSError *error) {
        XCTAssertNil(error);
        if (!initCalled && callback) {
            initCalled = YES;
            callback();
        }
    };
}

- (callbackWithParams)callbackExpectingFailure:(void (^)(void))callback {
    __block BOOL initCalled = NO;
    return ^(NSDictionary *params, NSError *error) {
        XCTAssertNotNil(error);
        
        if (!initCalled && callback) {
            initCalled = YES;
            callback();
        }
    };
}

# pragma mark - Init mocking
- (void)mockSuccesfulInit:(id)serverInterfaceMock {
    BNCServerResponse *openInstallResponse = [[BNCServerResponse alloc] init];
    openInstallResponse.data = @{
        @"session_id": @"11111",
        @"identity_id": @"22222",
        @"device_fingerprint_id": @"ae5adt6lkj08",
        @"browser_fingerprint_id": @"ae5adt6lkj08",
        @"link": @"https://bnc.lt/i/11111"
    };
    
    __block BNCServerCallback openOrInstallCallback;
    id openOrInstallCallbackCheckBlock = [OCMArg checkWithBlock:^BOOL(BNCServerCallback callback) {
        openOrInstallCallback = callback;
        return YES;
    }];
    
    id openOrInstallInvocation = ^(NSInvocation *invocation) {
        openOrInstallCallback(openInstallResponse, nil);
    };
    
    [[[serverInterfaceMock stub] andDo:openOrInstallInvocation] registerInstall:NO callback:openOrInstallCallbackCheckBlock];
    [[[serverInterfaceMock stub] andDo:openOrInstallInvocation] registerOpen:NO callback:openOrInstallCallbackCheckBlock];
}

- (void)overrideBranch:(Branch *)branch initHandler:(callbackWithParams)initHandler {
    // Override Branch init by setting internals *shudder*
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    [branch performSelector:@selector(setSessionInitWithParamsCallback:) withObject:initHandler];
#pragma clang diagnostic pop
}

- (NSData *)openResponseData {
    NSDictionary *openResponseDict = @{
        @"session_id": @"112263020234678596",
        @"identity_id": @"98687515069776101",
        @"device_fingerprint_id": @"94938498586381084",
        @"browser_fingerprint_id": [NSNull null],
        @"link": @"https://bnc.lt/i/3SawKbU-1Z",
        @"new_identity_id": @"98687515069776101",
        @"identity": @"test_user_10"
    };
    
    return [NSJSONSerialization dataWithJSONObject:openResponseDict options:kNilOptions error:nil];
}

- (void)safelyFulfillExpectation:(XCTestExpectation *)expectation {
    if (!self.hasExceededExpectations) {
        [expectation fulfill];
    }
}

- (void)awaitExpectations {
    [self waitForExpectationsWithTimeout:1 handler:^(NSError *error) {
        self.hasExceededExpectations = YES;
    }];
}

@end
