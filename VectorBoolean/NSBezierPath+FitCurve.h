//
//  NSBezierPath+FitCurve.h
//  VectorBrush
//
//  Created by Andrew Finnell on 5/28/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSBezierPath (FitCurve)

- (NSBezierPath *) fb_fitCurve:(CGFloat)errorThreshold;

@end
