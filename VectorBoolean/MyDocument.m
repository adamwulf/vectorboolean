//
//  MyDocument.m
//  VectorBoolean
//
//  Created by Andrew Finnell on 5/31/11.
//  Copyright 2011 Fortunate Bear, LLC. All rights reserved.
//

#import "MyDocument.h"
#import "CanvasView.h"
#import "Canvas.h"
#import "NSBezierPath+Boolean.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    }
    return self;
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
    
    [self onReset:nil];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError {
    /*
     Insert code here to write your document to data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning nil.
    You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.
    */
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    }
    return nil;
}

- (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
    /*
    Insert code here to read your document from the given data of the specified type. If outError != NULL, ensure that you create and set an appropriate error when returning NO.
    You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead.
    */
    if (outError) {
        *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
    }
    return YES;
}

- (IBAction) onReset:(id)sender
{
    [_view.canvas clear];
    
    NSBezierPath *rectangle = [NSBezierPath bezierPath];
    [rectangle moveToPoint:NSMakePoint(50, 50)];
    [rectangle lineToPoint:NSMakePoint(350, 50)];
    [rectangle lineToPoint:NSMakePoint(350, 250)];
    [rectangle lineToPoint:NSMakePoint(50, 250)];
    [rectangle lineToPoint:NSMakePoint(50, 50)];
    [_view.canvas addPath:rectangle withColor:[NSColor blueColor]];
    
    NSBezierPath *circle = [NSBezierPath bezierPath];
    static const CGFloat FBMagicNumber = 0.55228475;
    CGFloat controlPointLength = 125 * FBMagicNumber;
    [circle moveToPoint:NSMakePoint(230, 240)];
    [circle curveToPoint:NSMakePoint(355, 365) controlPoint1:NSMakePoint(230, 240 + controlPointLength) controlPoint2:NSMakePoint(355 - controlPointLength, 365)];
    [circle curveToPoint:NSMakePoint(480, 240) controlPoint1:NSMakePoint(355 + controlPointLength, 365) controlPoint2:NSMakePoint(480, 240 + controlPointLength)];
    [circle curveToPoint:NSMakePoint(355, 115) controlPoint1:NSMakePoint(480, 240 - controlPointLength) controlPoint2:NSMakePoint(355 + controlPointLength, 115)];
    [circle curveToPoint:NSMakePoint(230, 240) controlPoint1:NSMakePoint(355 - controlPointLength, 115) controlPoint2:NSMakePoint(230, 240 - controlPointLength)];
    [_view.canvas addPath:circle withColor:[NSColor redColor]];

    [_view setNeedsDisplay:YES];
}

- (IBAction) onUnion:(id)sender
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_union:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onIntersect:(id)sender
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_intersect:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onDifference:(id)sender // Punch
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_difference:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

- (IBAction) onJoin:(id)sender // XOR
{
    [self onReset:sender];
    
    NSBezierPath *result = [[_view.canvas pathAtIndex:0] fb_xor:[_view.canvas pathAtIndex:1]];
    [_view.canvas clear];
    [_view.canvas addPath:result withColor:[NSColor blueColor]];
}

@end
