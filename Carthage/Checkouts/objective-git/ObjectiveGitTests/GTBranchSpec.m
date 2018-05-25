//
//  GTBranchSpec.m
//  ObjectiveGitFramework
//
//  Created by Josh Abernathy on 3/22/13.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

@import ObjectiveGit;
@import Nimble;
@import Quick;

#import "QuickSpec+GTFixtures.h"

QuickSpecBegin(GTBranchSpec)

__block GTRepository *repository;
__block GTBranch *masterBranch;
__block GTBranch *trackingBranch;

beforeEach(^{
	repository = self.testAppFixtureRepository;
	expect(repository).notTo(beNil());

	NSError *error = nil;
	masterBranch = [repository currentBranchWithError:&error];
	expect(masterBranch).notTo(beNil());
	expect(error).to(beNil());

	BOOL success = NO;
	trackingBranch = [masterBranch trackingBranchWithError:&error success:&success];
	expect(trackingBranch).notTo(equal(masterBranch));
	expect(@(success)).to(beTruthy());
	expect(error).to(beNil());
});

describe(@"name", ^{
	it(@"should use just the branch name for a local branch", ^{
		expect(masterBranch.name).to(equal(@"master"));
	});

	it(@"should include the remote name for a tracking branch", ^{
		expect(trackingBranch.name).to(equal(@"origin/master"));
	});
});

describe(@"shortName", ^{
	it(@"should use just the branch name for a local branch", ^{
		expect(masterBranch.shortName).to(equal(@"master"));
	});

	it(@"should not include the remote name for a tracking branch", ^{
		expect(trackingBranch.shortName).to(equal(@"master"));
	});
});

describe(@"remoteName", ^{
	it(@"should return nil for a local branch", ^{
		expect(masterBranch.remoteName).to(beNil());
	});

	it(@"should return the remote name for a tracking branch", ^{
		expect(trackingBranch.remoteName).to(equal(@"origin"));
	});
});

describe(@"branchType", ^{
	it(@"should be GTBranchTypeLocal for a local branch", ^{
		expect(@(masterBranch.branchType)).to(equal(@(GTBranchTypeLocal)));
	});

	it(@"should be GTBranchTypeRemote for a tracking branch", ^{
		expect(@(trackingBranch.branchType)).to(equal(@(GTBranchTypeRemote)));
	});
});

describe(@"-calculateAhead:behind:relativeTo:error:", ^{
	it(@"should calculate ahead/behind relative to the tracking branch", ^{
		size_t ahead = 0;
		size_t behind = 0;
		[masterBranch calculateAhead:&ahead behind:&behind relativeTo:trackingBranch error:NULL];
		expect(@(ahead)).to(equal(@9));
		expect(@(behind)).to(equal(@0));
	});

	it(@"should calculate ahead/behind relative to the local branch", ^{
		size_t ahead = 0;
		size_t behind = 0;
		[trackingBranch calculateAhead:&ahead behind:&behind relativeTo:masterBranch error:NULL];
		expect(@(ahead)).to(equal(@0));
		expect(@(behind)).to(equal(@9));
	});
});

describe(@"-uniqueCommitsRelativeToBranch:error:", ^{
	it(@"should return unique commits relative to the tracking branch", ^{
		NSError *error = nil;
		NSArray *commits = [masterBranch uniqueCommitsRelativeToBranch:trackingBranch error:&error];
		expect(commits).notTo(beNil());
		expect(error).to(beNil());

		NSMutableArray *SHAs = [NSMutableArray array];
		for (GTCommit *commit in commits) {
			[SHAs addObject:commit.SHA];
		}

		NSArray *expectedSHAs = @[
			@"a4bca6b67a5483169963572ee3da563da33712f7",
			@"6b0c1c8b8816416089c534e474f4c692a76ac14f",
			@"f7ecd8f4404d3a388efbff6711f1bdf28ffd16a0",
			@"82dc47f6ba3beecab33080a1136d8913098e1801",
			@"93f5b550149f9f4c702c9de9a8b0a8a357f0c41c",
			@"1d69f3c0aeaf0d62e25591987b93b8ffc53abd77",
			@"3c273013b9b7af154f7e30f785a8affda37f85e1",
			@"6317779b4731d9c837dcc6972b964bdf4211eeef",
			@"9f90c6e24629fae3ef51101bb6448342b44098ef",
		];

		expect(SHAs).to(equal(expectedSHAs));
	});

	it(@"should return no unique commits relative to the local branch", ^{
		NSError *error = nil;
		NSArray *commits = [trackingBranch uniqueCommitsRelativeToBranch:masterBranch error:&error];
		expect(commits).to(equal(@[]));
		expect(error).to(beNil());
	});
});

describe(@"-reloadedBranchWithError:", ^{
	it(@"should reload the branch from disk", ^{
		static NSString * const originalSHA = @"a4bca6b67a5483169963572ee3da563da33712f7";
		static NSString * const updatedSHA = @"6b0c1c8b8816416089c534e474f4c692a76ac14f";
		expect([masterBranch targetCommitWithError:NULL].SHA).to(equal(originalSHA));
		[masterBranch.reference referenceByUpdatingTarget:updatedSHA message:nil error:NULL];

		GTBranch *reloadedBranch = [masterBranch reloadedBranchWithError:NULL];
		expect(reloadedBranch).notTo(beNil());
		expect([reloadedBranch targetCommitWithError:NULL].SHA).to(equal(updatedSHA));
		expect([masterBranch targetCommitWithError:NULL].SHA).to(equal(originalSHA));
	});
});

describe(@"-numberOfCommitsWithError:", ^{
	it(@"should return the count of commits in the branch", ^{
		NSError *error = nil;
		NSUInteger commitCount = [masterBranch numberOfCommitsWithError:&error];
		expect(@(commitCount)).to(equal(@164));
		expect(error).to(beNil());
	});
});

describe(@"-trackingBranchWithError:success:", ^{
	it(@"should return the tracking branch for a local branch that tracks a remote branch", ^{
		NSError *error = nil;
		GTBranch *masterBranch = [repository lookUpBranchWithName:@"master" type:GTBranchTypeLocal success:NULL error:&error];
		expect(masterBranch).notTo(beNil());
		expect(error).to(beNil());

		BOOL success = NO;
		GTBranch *trackingBranch = [masterBranch trackingBranchWithError:&error success:&success];
		expect(trackingBranch).notTo(beNil());
		expect(@(success)).to(beTruthy());
		expect(error).to(beNil());
	});

	it(@"should return nil for a local branch that doesn't track a remote branch", ^{
		GTOID *OID = [[GTOID alloc] initWithSHA:@"6b0c1c8b8816416089c534e474f4c692a76ac14f"];

		NSError *error = nil;
		GTReference *otherRef = [repository createReferenceNamed:@"refs/heads/yet-another-branch" fromOID:OID message:nil error:&error];
		expect(otherRef).notTo(beNil());
		expect(error).to(beNil());

		GTBranch *otherBranch = [GTBranch branchWithReference:otherRef];
		expect(otherBranch).notTo(beNil());

		BOOL success = NO;
		trackingBranch = [otherBranch trackingBranchWithError:&error success:&success];
		expect(trackingBranch).to(beNil());
		expect(@(success)).to(beTruthy());
		expect(error).to(beNil());
	});

	it(@"should return itself for a remote branch", ^{
		NSError *error = nil;
		GTReference *remoteRef = [repository lookUpReferenceWithName:@"refs/remotes/origin/master" error:&error];
		expect(remoteRef).notTo(beNil());
		expect(error).to(beNil());

		GTBranch *remoteBranch = [GTBranch branchWithReference:remoteRef];
		expect(remoteBranch).notTo(beNil());

		BOOL success = NO;
		GTBranch *remoteTrackingBranch = [remoteBranch trackingBranchWithError:&error success:&success];
		expect(remoteTrackingBranch).to(equal(remoteBranch));
		expect(@(success)).to(beTruthy());
		expect(error).to(beNil());
	});
});

describe(@"-updateTrackingBranch:error:", ^{
	__block GTBranch *masterBranch;
	beforeEach(^{
		masterBranch = [repository lookUpBranchWithName:@"master" type:GTBranchTypeLocal success:NULL error:NULL];
		expect(masterBranch).notTo(beNil());
	});

	it(@"should set a tracking branch", ^{
		GTBranch *branch = [repository lookUpBranchWithName:@"feature" type:GTBranchTypeLocal success:NULL error:NULL];
		expect(branch).notTo(beNil());

		BOOL success = NO;
		GTBranch *trackingBranch = [branch trackingBranchWithError:NULL success:&success];
		expect(trackingBranch).to(beNil());
		expect(@(success)).to(beTruthy());

		NSError *error;
		success = [branch updateTrackingBranch:masterBranch error:&error];
		expect(@(success)).to(beTruthy());
		expect(error).to(beNil());

		trackingBranch = [branch trackingBranchWithError:NULL success:&success];
		expect(trackingBranch).notTo(beNil());
		expect(@(success)).to(beTruthy());
	});

	it(@"should unset a tracking branch", ^{
		BOOL success = NO;
		GTBranch *trackingBranch = [masterBranch trackingBranchWithError:NULL success:&success];
		expect(trackingBranch).notTo(beNil());
		expect(@(success)).to(beTruthy());

		success = [masterBranch updateTrackingBranch:nil error:NULL];
		expect(@(success)).to(beTruthy());

		trackingBranch = [masterBranch trackingBranchWithError:NULL success:&success];
		expect(trackingBranch).to(beNil());
		expect(@(success)).to(beTruthy());
	});
		
	it(@"should set a remote tracking branch without branches amount change", ^{
		GTRepository *repository = self.testAppForkFixtureRepository;
		expect(repository).notTo(beNil());
			
		NSError *error = nil;
		BOOL success = NO;
		GTBranch *remoteBranch = [repository lookUpBranchWithName:@"github/BranchC" type:GTBranchTypeRemote success:&success error:&error];
		expect(remoteBranch).notTo(beNil());
		expect(error).to(beNil());
			
		NSArray *beforeBranches = [repository branches:&error];
		expect(error).to(beNil());

		GTBranch *localBranch = [repository createBranchNamed:remoteBranch.shortName fromOID:remoteBranch.OID message:nil error:&error];
		expect(localBranch).notTo(beNil());
		expect(error).to(beNil());
			
		NSArray *inBranches = [repository branches:&error];
		expect(error).to(beNil());

		[localBranch updateTrackingBranch:remoteBranch error:&error];
		expect(error).to(beNil());
			
		NSArray *afterBranches = [repository branches:&error];
		expect(error).to(beNil());
		
		expect(@(beforeBranches.count + 1)).to(equal(@(inBranches.count)));
		expect(@(beforeBranches.count)).to(equal(@(afterBranches.count)));
		
	});
});

describe(@"-rename:force:error", ^{
	__block GTBranch *masterBranch;
	beforeEach(^{
		masterBranch = [repository lookUpBranchWithName:@"master" type:GTBranchTypeLocal success:NULL error:NULL];
		expect(masterBranch).notTo(beNil());
	});

	it(@"should rename the branch", ^{
		NSError *error = nil;
		BOOL success = [masterBranch rename:@"plop" force:NO error:&error];
		expect(@(success)).to(beTruthy());
		expect(error).to(beNil());

		expect(masterBranch.shortName).to(equal(@"plop"));
	});

	it(@"should fail on duplicates", ^{
		NSError *error = nil;
		BOOL success = [masterBranch rename:@"feature" force:NO error:&error];
		expect(@(success)).to(beFalsy());
		expect(error).notTo(beNil());

		expect(masterBranch.shortName).to(equal(@"master"));
	});

	it(@"should rename when forced", ^{
		NSError *error = nil;
		BOOL success = [masterBranch rename:@"feature" force:YES error:&error];
		expect(@(success)).to(beTruthy());
		expect(error).to(beNil());

		expect(masterBranch.shortName).to(equal(@"feature"));
	});
});

afterEach(^{
	[self tearDown];
});

QuickSpecEnd
