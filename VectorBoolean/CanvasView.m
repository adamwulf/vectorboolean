//
//  CanvasView.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "CanvasView.h"
#import "Canvas.h"


@implementation CanvasView

@synthesize canvas=_canvas;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _canvas = [[Canvas alloc] init];
    }
    
    return self;
}

- (void)dealloc
{
    [_canvas release];

    [super dealloc];
}

- (void)drawRect:(NSRect)dirtyRect
{
    [_canvas drawRect:dirtyRect];
}

@end
