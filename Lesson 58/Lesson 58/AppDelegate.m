//
//  AppDelegate.m
//  Lesson 55
//
//  Created by Lucas Derraugh on 8/17/13.
//  Copyright (c) 2013 Lucas Derraugh. All rights reserved.
//

#import "AppDelegate.h"
#import "DesktopEntity.h"

@implementation AppDelegate {
    NSMutableArray *_tableContents;
    NSRange _objectRange;
    NSArray *_currentlyDraggedObjects;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _tableContents = [[NSMutableArray alloc] init];
    NSString *path = @"/Library/Application Support/Apple/iChat Icons/";
    NSURL *url = [[NSURL alloc] initFileURLWithPath:path];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *directoryEnum = [fileManager enumeratorAtURL:url
                                             includingPropertiesForKeys:nil
                                                                options:0
                                                           errorHandler:^BOOL(NSURL *url, NSError *error) {
                                                               return YES;
                                                           }];
    
    for (NSURL *fileURL in directoryEnum) {
        DesktopEntity *entity = [DesktopEntity entityForURL:fileURL];
        if ([entity isKindOfClass:[DesktopEntity class]])
            [_tableContents addObject:entity];
    }
    [_tableView reloadData];
    [_tableView registerForDraggedTypes:@[(id)kUTTypeFileURL]];
    [_tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
}

#pragma mark NSTableView datasource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [_tableContents count];
}

- (id<NSPasteboardWriting>)tableView:(NSTableView *)tableView pasteboardWriterForRow:(NSInteger)row {
    return _tableContents[row];
}

- (NSDictionary *)pasteboardReadingOptions {
    return @{NSPasteboardURLReadingFileURLsOnlyKey: @YES,
             NSPasteboardURLReadingContentsConformToTypesKey: [NSImage imageTypes]};
}

- (BOOL)containsAcceptableURLsFromPasteboard:(NSPasteboard *)pasteboard {
    return [pasteboard canReadObjectForClasses:@[[NSURL class]]
                                       options:[self pasteboardReadingOptions]];
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forRowIndexes:(NSIndexSet *)rowIndexes {
    NSUInteger len = ([rowIndexes lastIndex]+1) - [rowIndexes firstIndex];
    _objectRange = NSMakeRange([rowIndexes firstIndex], len);
    _currentlyDraggedObjects = [_tableContents objectsAtIndexes:rowIndexes];
}

- (void)tableView:(NSTableView *)tableView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    _objectRange = NSMakeRange(0, 0);
    _currentlyDraggedObjects = nil;
}

- (NSDragOperation)tableView:(NSTableView *)tableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)dropOperation {
    if (dropOperation == NSTableViewDropAbove && (_objectRange.location > row || _objectRange.location+_objectRange.length < row)) {
        if ([info draggingSource] == tableView) {
            if ([info draggingSourceOperationMask] == NSDragOperationCopy) {
                info.animatesToDestination = YES;
                return NSDragOperationCopy;
            } else {
                return NSDragOperationMove;
            }
        } else {
            if ([self containsAcceptableURLsFromPasteboard:[info draggingPasteboard]]) {
                info.animatesToDestination = YES;
                return NSDragOperationCopy;
            }
        }
    }
    return NSDragOperationNone;
}

- (void)tableView:(NSTableView *)tableView updateDraggingItemsForDrag:(id<NSDraggingInfo>)draggingInfo {
    if ([draggingInfo draggingSource] != tableView) {
        NSArray *classes = @[[DesktopEntity class], [NSPasteboardItem class]];
        NSTableCellView *tableCellView = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
        __block NSInteger validCount = 0;
        [draggingInfo enumerateDraggingItemsWithOptions:0 forView:tableView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
            if ([draggingItem.item isKindOfClass:[DesktopEntity class]]) {
                DesktopEntity *entity = (DesktopEntity *)draggingItem.item;
                draggingItem.draggingFrame = [tableCellView frame];
                draggingItem.imageComponentsProvider = ^NSArray *{
                    if ([entity isKindOfClass:[DesktopImageEntity class]])
                        [tableCellView.imageView setImage:[(DesktopImageEntity *)entity image]];
                    [tableCellView.textField setStringValue:entity.name];
                    return [tableCellView draggingImageComponents];
                };
                validCount++;
            } else {
                draggingItem.imageComponentsProvider = nil;
            }
        }];
        draggingInfo.numberOfValidItemsForDrop = validCount;
        draggingInfo.draggingFormation = NSDraggingFormationList;
    }
}

- (BOOL)tableView:(NSTableView *)tableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)dropOperation {
    if (_currentlyDraggedObjects == nil || [info draggingSourceOperationMask] == NSDragOperationCopy) {
        [self performInsertWithDragInfo:info row:row];
    } else {
        [tableView beginUpdates];
        [self performDragReorderWithDragInfo:info row:row];
        [tableView endUpdates];
    }
    return YES;
}

- (void)performDragReorderWithDragInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[[DesktopEntity class]];
    [info enumerateDraggingItemsWithOptions:0 forView:_tableView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
        NSInteger newIndex = row+idx;
        DesktopEntity *entity = _currentlyDraggedObjects[idx];
        NSInteger oldIndex = [_tableContents indexOfObject:entity];
        if (oldIndex < newIndex) {
            newIndex -= (idx+1);
        }
        [_tableContents removeObjectAtIndex:oldIndex];
        [_tableContents insertObject:entity atIndex:newIndex];
        [_tableView moveRowAtIndex:oldIndex toIndex:newIndex];
    }];
}

- (void)performInsertWithDragInfo:(id<NSDraggingInfo>)info row:(NSInteger)row {
    NSArray *classes = @[[DesktopEntity class]];
    __block NSInteger insertionIndex = row;
    [info enumerateDraggingItemsWithOptions:0 forView:_tableView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger idx, BOOL *stop) {
        DesktopEntity *entity = draggingItem.item;
        [_tableContents insertObject:entity atIndex:insertionIndex];
        [_tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] withAnimation:NSTableViewAnimationEffectGap];
        draggingItem.draggingFrame = [_tableView frameOfCellAtColumn:0 row:insertionIndex];
        insertionIndex++;
    }];
}

#pragma mark NSTableView delegate

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    DesktopEntity *entity = _tableContents[row];
    if ([entity isKindOfClass:[DesktopFolderEntity class]]) {
        NSTextField *groupCell = [tableView makeViewWithIdentifier:@"GroupCell" owner:self];
        [groupCell setStringValue:entity.name];
        return groupCell;
    } if ([entity isKindOfClass:[DesktopImageEntity class]]) {
        NSTableCellView *cellView = [tableView makeViewWithIdentifier:@"ImageCell" owner:self];
        [cellView.textField setStringValue:entity.name];
        [cellView.imageView setImage:[(DesktopImageEntity *)entity image]];
        return cellView;
    }
    return nil;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row {
    DesktopEntity *entity = _tableContents[row];
    if ([entity isKindOfClass:[DesktopFolderEntity class]]) {
        return YES;
    }
    return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row {
    DesktopEntity *entity = _tableContents[row];
    if ([entity isKindOfClass:[DesktopFolderEntity class]]) {
        return 22;
    }
    return [tableView rowHeight];
}

- (IBAction)insertNewRow:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    [openPanel setAllowsMultipleSelection:YES];
    [openPanel setAllowedFileTypes:[NSImage imageTypes]];
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSOKButton) {
            NSInteger index = [_tableView selectedRow];
            index++;
            NSArray *urls = [openPanel URLs];
            [_tableView beginUpdates];
            for (NSURL *url in urls) {
                DesktopEntity *entity = [DesktopEntity entityForURL:url];
                if (entity) {
                    [_tableContents insertObject:entity atIndex:index];
                    [_tableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:index] withAnimation:NSTableViewAnimationSlideDown];
                    index++;
                }
            }
            [_tableView endUpdates];
            [_tableView scrollRowToVisible:index];
        }
    }];
}

- (IBAction)removeSelectedRows:(id)sender {
    NSIndexSet *indexes = [_tableView selectedRowIndexes];
    [_tableContents removeObjectsAtIndexes:indexes];
    [_tableView removeRowsAtIndexes:indexes withAnimation:NSTableViewAnimationSlideDown];
}

- (IBAction)locateInFinder:(id)sender {
    NSInteger selectedRow = [_tableView rowForView:sender];
    DesktopEntity *entity = _tableContents[selectedRow];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[entity fileURL]]];
}

@end
