//
//  FBBezierContour.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 6/15/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FBBezierCurve;

@interface FBBezierContour : NSObject {
    NSMutableArray *_edges;
}

- (void) addCurve:(FBBezierCurve *)curve;

@property (readonly) NSArray *edges;

@end
