//
//  VectorBoolean_Tests.m
//  VectorBoolean Tests
//
//  Created by Adam Wulf on 9/8/13.
//  Copyright (c) 2013 Fortunate Bear, LLC. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "NSBezierPath+Boolean.h"

@interface VectorBoolean_Tests : XCTestCase

@end

@implementation VectorBoolean_Tests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testUnclosedCurveThroughClosedBox{
    //
    // testPath is a curved line that starts
    // out above bounds, and curves through the
    // bounds box until it ends outside on the
    // other side
    
    NSBezierPath* testPath = [NSBezierPath bezierPath];
    [testPath moveToPoint:CGPointMake(100, 50)];
    [testPath curveToPoint:CGPointMake(100, 250)
                controlPoint1:CGPointMake(170, 80)
                controlPoint2:CGPointMake(170, 220)];
    
    
    // simple 100x100 box
    NSBezierPath* bounds = [NSBezierPath bezierPath];
    [bounds moveToPoint:CGPointMake(100, 100)];
    [bounds lineToPoint:CGPointMake(200, 100)];
    [bounds lineToPoint:CGPointMake(200, 200)];
    [bounds lineToPoint:CGPointMake(100, 200)];
    [bounds lineToPoint:CGPointMake(100, 100)];
    [bounds closePath];
    
    NSBezierPath* diff = [bounds fb_intersect:testPath];
    NSBezierPath* inter = [bounds fb_difference:testPath];
    NSBezierPath* un = [bounds fb_union:testPath];
    NSBezierPath* xor = [bounds fb_xor:testPath];
    
    //
    // all of these create a line that attaches to the box and then loops around it
    //
    // instead, the line itself should
    NSLog(@"diff: %@", diff);
    NSLog(@"inter: %@", inter);
    NSLog(@"union: %@", un);
    NSLog(@"xor: %@", xor);
    NSLog(@"done");
    
}

@end
