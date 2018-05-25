//
//  GTObjectTest.m
//  ObjectiveGitFramework
//
//  Created by Timothy Clem on 2/24/11.
//
//  The MIT License
//
//  Copyright (c) 2011 Tim Clem
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

QuickSpecBegin(GTObjectSpec)

__block GTRepository *repo;

beforeEach(^{
	repo = self.bareFixtureRepository;
});

it(@"should fail to look up an empty string", ^{
	NSError *error = nil;
	GTObject *obj = [repo lookUpObjectBySHA:@"" error:&error];

	XCTAssertNotNil(error);
	XCTAssertNil(obj);
	NSLog(@"Error = %@", [error localizedDescription]);
});

it(@"should fail to look up a bad object", ^{
	NSError *error = nil;
	GTObject *obj = [repo lookUpObjectBySHA:@"a496071c1b46c854b31185ea97743be6a8774479" error:&error];

	XCTAssertNotNil(error);
	XCTAssertNil(obj);
	NSLog(@"Error = %@", [error localizedDescription]);
});

it(@"should look up a valid object", ^{
	NSError *error = nil;
	GTObject *obj = [repo lookUpObjectBySHA:@"8496071c1b46c854b31185ea97743be6a8774479" error:&error];

	XCTAssertNil(error, "%@", error.localizedDescription);
	XCTAssertNotNil(obj);
	XCTAssertEqualObjects(obj.type, @"commit");
	XCTAssertEqualObjects(obj.SHA, @"8496071c1b46c854b31185ea97743be6a8774479");
});

it(@"should look up equivalent objects", ^{
	NSError *error = nil;
	GTObject *obj1 = [repo lookUpObjectBySHA:@"8496071c1b46c854b31185ea97743be6a8774479" error:&error];
	GTObject *obj2 = [repo lookUpObjectBySHA:@"8496071c1b46c854b31185ea97743be6a8774479" error:&error];

	XCTAssertNotNil(obj1);
	XCTAssertNotNil(obj2);
	XCTAssertTrue([obj1 isEqual:obj2]);
});

it(@"should read the raw data from an object", ^{
	NSError *error = nil;
	GTObject *obj = [repo lookUpObjectBySHA:@"8496071c1b46c854b31185ea97743be6a8774479" error:&error];

	XCTAssertNotNil(obj);

	GTOdbObject *rawObj = [obj odbObjectWithError:&error];
	XCTAssertNotNil(rawObj);
	XCTAssertNil(error, @"%@", error.localizedDescription);
});

QuickSpecEnd
