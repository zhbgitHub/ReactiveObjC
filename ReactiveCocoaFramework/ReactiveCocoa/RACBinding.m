//
//  RACBinding.m
//  ReactiveCocoa
//
//  Created by Uri Baghin on 01/01/2013.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import "RACBinding.h"
#import "RACDisposable.h"
#import "RACReplaySubject.h"
#import "RACSignal+Operations.h"

@interface RACBindingEndpoint ()

// The values for this endpoint.
@property (nonatomic, strong, readonly) RACSignal *values;

// A subscriber will will send values to the other endpoint.
@property (nonatomic, strong, readonly) id<RACSubscriber> otherEndpoint;

- (id)initWithValues:(RACSignal *)values otherEndpoint:(id<RACSubscriber>)otherEndpoint;

@end

@implementation RACBinding

- (id)init {
	self = [super init];
	if (self == nil) return nil;

	RACReplaySubject *factsSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"factsSubject"];
	RACReplaySubject *rumorsSubject = [[RACReplaySubject replaySubjectWithCapacity:1] setNameWithFormat:@"rumorsSubject"];

	// Propagate errors and completion to everything.
	[[factsSubject ignoreValues] subscribe:rumorsSubject];
	[[rumorsSubject ignoreValues] subscribe:factsSubject];

	_endpointForFacts = [[[RACBindingEndpoint alloc] initWithValues:rumorsSubject otherEndpoint:factsSubject] setNameWithFormat:@"endpointForFacts"];
	_endpointForRumors = [[[RACBindingEndpoint alloc] initWithValues:factsSubject otherEndpoint:rumorsSubject] setNameWithFormat:@"endpointForRumors"];

	return self;
}

@end

@implementation RACBindingEndpoint

#pragma mark Lifecycle

- (id)initWithValues:(RACSignal *)values otherEndpoint:(id<RACSubscriber>)otherEndpoint {
	NSCParameterAssert(values != nil);
	NSCParameterAssert(otherEndpoint != nil);

	self = [super init];
	if (self == nil) return nil;

	_values = values;
	_otherEndpoint = otherEndpoint;

	return self;
}

#pragma mark RACSignal

- (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
	return [self.values subscribe:subscriber];
}

#pragma mark <RACSubscriber>

- (void)sendNext:(id)value {
	[self.otherEndpoint sendNext:value];
}

- (void)sendError:(NSError *)error {
	[self.otherEndpoint sendError:error];
}

- (void)sendCompleted {
	[self.otherEndpoint sendCompleted];
}

- (void)didSubscribeWithDisposable:(RACDisposable *)disposable {
	[self.otherEndpoint didSubscribeWithDisposable:disposable];
}


#pragma mark Binding

- (RACDisposable *)bindFromEndpoint:(RACBindingEndpoint *)otherEndpoint {
	NSCParameterAssert(otherEndpoint != nil);

	RACDisposable *otherToSelf = [otherEndpoint subscribe:self];
	RACDisposable *selfToOther = [[self skip:1] subscribe:otherEndpoint];
	return [RACDisposable disposableWithBlock:^{
		[otherToSelf dispose];
		[selfToOther dispose];
	}];
}

@end
