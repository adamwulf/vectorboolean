//
//  FBBezierIntersection.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/6/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "FBBezierIntersection.h"


@implementation FBBezierIntersection

@synthesize location=_location;
@synthesize curve1=_curve1;
@synthesize t1=_t1;
@synthesize curve2=_curve2;
@synthesize t2=_t2;
@synthesize tangent=_tangent;

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc
{
    [_curve1 release];
    [_curve2 release];
    
    [super dealloc];
}

@end
