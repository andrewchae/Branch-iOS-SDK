//
//  Branch_SDK_Load_Tests.m
//  Branch-TestBed
//
//  Created by Qinwei Gong on 2/23/15.
//  Copyright (c) 2015 Branch Metrics. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <OCMock/OCMock.h>
#import "Branch.h"
#import "BNCPreferenceHelper.h"
#import "BNCServerInterface.h"
#import "BNCEncodingUtils.h"
#import "BNCServerRequestQueue.h"

@interface Branch_SDK_Load_Tests : XCTestCase

@end

@implementation Branch_SDK_Load_Tests

- (void)testLoad {
    id preferenceHelperMock = OCMClassMock([BNCPreferenceHelper class]);
    id serverInterfaceMock = OCMClassMock([BranchServerInterface class]);

    Branch *branch = [[Branch alloc] initWithInterface:serverInterfaceMock queue:[[BNCServerRequestQueue alloc] init] cache:[[BNCLinkCache alloc] init]];
    [branch setAppListCheckEnabled:NO];
    
    BNCServerResponse *linkResponse = [[BNCServerResponse alloc] init];
    linkResponse.data = @{ @"url": @"https://bnc.lt/l/3PxZVFU-BK" };
    
    BNCServerResponse *openInstallResponse = [[BNCServerResponse alloc] init];
    openInstallResponse.data = @{
        @"session_id": @"112263020234678596",
        @"identity_id": @"98687515069776101",
        @"device_fingerprint_id": @"94938498586381084",
        @"browser_fingerprint_id": [NSNull null],
        @"link": @"https://bnc.lt/i/3SawKbU-1Z",
        @"new_identity_id": @"98687515069776101",
        @"identity": @"test_user_10"
    };
    
    // Stub all the requests
    __block BNCServerCallback urlCallback;
    [[[serverInterfaceMock stub] andDo:^(NSInvocation *invocation) {
        urlCallback(linkResponse, nil);
    }] createCustomUrl:[OCMArg any] callback:[OCMArg checkWithBlock:^BOOL(BNCServerCallback callback) {
        urlCallback = callback;
        return YES;
    }]];
    
    id openOrInstallCallbackCheckBlock = [OCMArg checkWithBlock:^BOOL(BNCServerCallback callback) {
        callback(openInstallResponse, nil);
        return YES;
    }];
    
    [[serverInterfaceMock stub] registerInstall:NO callback:openOrInstallCallbackCheckBlock];
    [[serverInterfaceMock stub] registerOpen:NO callback:openOrInstallCallbackCheckBlock];
    
    // Fake branch key
    [[[preferenceHelperMock stub] andReturn:@"foo"] getBranchKey];
    
    for (int i = 0; i < 1000; i++) {
        [branch getShortURLWithParams:nil andChannel:[NSString stringWithFormat:@"%d", i] andFeature:nil andCallback:^(NSString *url, NSError *error) {
            XCTAssertNil(error);
            XCTAssertNotNil(url);
        }];
    }
    
    XCTestExpectation *getShortURLExpectation = [self expectationWithDescription:@"Test getShortURL"];
    [branch getShortURLWithParams:nil andChannel:nil andFeature:@"feature" andCallback:^(NSString *url, NSError *error) {
        XCTAssertNil(error);
        XCTAssertEqualObjects(url, @"https://bnc.lt/l/3PxZVFU-BK");
        [getShortURLExpectation fulfill];
    }];
    
    [self waitForExpectationsWithTimeout:10 handler:NULL];
}

@end

