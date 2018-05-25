//
//  GTCommitSpec.m
//  ObjectiveGitFramework
//
//  Created by Etienne Samson on 2013-11-07.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

QuickSpecBegin(GTCommitSpec)

__block GTRepository *repository;

beforeEach(^{
	repository = self.bareFixtureRepository;
});

it(@"can read commit data", ^{
	NSError *error = nil;
	NSString *commitSHA = @"8496071c1b46c854b31185ea97743be6a8774479";
	GTCommit *commit = [repository lookUpObjectBySHA:commitSHA error:&error];

	expect(commit).notTo(beNil());
	expect(error).to(beNil());

	expect(commit).to(beAnInstanceOf(GTCommit.class));
	expect(commit.type).to(equal(@"commit"));
	expect(commit.SHA).to(equal(commitSHA));
	expect(commit.OID).to(equal([GTOID oidWithSHA:commitSHA]));

	expect(commit.message).to(equal(@"testing\n"));
	expect(commit.messageSummary).to(equal(@"testing"));
	expect(commit.messageDetails).to(equal(@""));
	expect(commit.commitDate).to(equal([NSDate dateWithTimeIntervalSince1970:1273360386]));

	GTSignature *author = commit.author;
	expect(author).notTo(beNil());
	expect(author.name).to(equal(@"Scott Chacon"));
	expect(author.email).to(equal(@"schacon@gmail.com"));
	expect(author.time).to(equal([NSDate dateWithTimeIntervalSince1970:1273360386]));

	GTSignature *committer = commit.committer;
	expect(committer).notTo(beNil());
	expect(committer.name).to(equal(@"Scott Chacon"));
	expect(committer.email).to(equal(@"schacon@gmail.com"));
	expect(committer.time).to(equal([NSDate dateWithTimeIntervalSince1970:1273360386]));

	expect(commit.tree.SHA).to(equal(@"181037049a54a1eb5fab404658a3a250b44335d7"));
	expect(@(commit.parents.count)).to(equal(@0));
});

it(@"can have multiple parents", ^{
	NSError *error = nil;
	NSString *commitSHA = @"a4a7dce85cf63874e984719f4fdd239f5145052f";
	GTCommit *commit = [repository lookUpObjectBySHA:commitSHA error:&error];
	expect(commit).notTo(beNil());
	expect(error).to(beNil());

	NSArray *commitOIDs = @[@"c47800c7266a2be04c571c04d5a6614691ea99bd", @"9fd738e8f7967c078dceed8190330fc8648ee56a"];
	NSArray *commitParents = commit.parentOIDs;
	expect(@(commitParents.count)).to(equal(@(commitOIDs.count)));
	expect([commitParents valueForKey:@"SHA"]).to(equal(commitOIDs));

	commitParents = commit.parents;
	expect(@(commitParents.count)).to(equal(@(commitOIDs.count)));
	expect([commitParents valueForKeyPath:@"OID.SHA"]).to(equal(commitOIDs));
});

it(@"can identify merges", ^{
	NSError *error;
	NSString *commitSHA = @"a4a7dce85cf63874e984719f4fdd239f5145052f";
	GTCommit *commit = [repository lookUpObjectBySHA:commitSHA error:&error];
	expect(commit).notTo(beNil());

	expect(@(commit.merge)).to(beTruthy());
});

afterEach(^{
	[self tearDown];
});

QuickSpecEnd
