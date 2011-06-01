//
//  CanvasView.h
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class Canvas;

@interface CanvasView : NSView {
    Canvas *_canvas;    
}

@property (readonly) Canvas *canvas;

@end
