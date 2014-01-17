//
//  RZCellSizeManager.m
//  Raizlabs
//
//  Created by Alex Rouse on 12/11/13.
//  Copyright (c) 2013 Raizlabs. All rights reserved.
//

#import "RZCellSizeManager.h"

#define kRZCellSizeManagerCellKey               @"RZCellSizeManagerCellKey"
#define kRZCellSizeManagerObjectClassKey        @"RZCellSizeManagerObjectClassKey"
#define kRZCellSizeManagerConfigurationBlockKey @"RZCellSizeManagerConfigurationBlockKey"

/**
 * UICollectionViewCell (AutoLayout)
 *
 * Helper methods for a UICollectionViewCell
 **/

@interface UIView (AutoLayout)

- (void)moveConstraintsToContentView;

@end


@implementation UIView (AutoLayout)

// Taken from : http://stackoverflow.com/questions/18746929/using-auto-layout-in-uitableview-for-dynamic-cell-layouts-heights
// Note that there may be performance issues with this in some cases.  Should only call in on Awake from nib or initialization and not on reuse.
- (void)moveConstraintsToContentView
{
    if ([self isKindOfClass:[UICollectionViewCell class]] || [self isKindOfClass:[UITableViewCell class]])
    {
        for(NSLayoutConstraint *cellConstraint in self.constraints){
            [self removeConstraint:cellConstraint];
            id firstItem = cellConstraint.firstItem == self ? self.contentView : cellConstraint.firstItem;
            id seccondItem = cellConstraint.secondItem == self ? self.contentView : cellConstraint.secondItem;
            NSLayoutConstraint* contentViewConstraint =
            [NSLayoutConstraint constraintWithItem:firstItem
                                         attribute:cellConstraint.firstAttribute
                                         relatedBy:cellConstraint.relation
                                            toItem:seccondItem
                                         attribute:cellConstraint.secondAttribute
                                        multiplier:cellConstraint.multiplier
                                          constant:cellConstraint.constant];
            [self.contentView addConstraint:contentViewConstraint];
        }
    }
}

- (UIView *)contentView
{
    // We know we are a collectionview cell or a tableview cell so this is safe.
    return [(UITableViewCell *)self contentView];
}

@end


/**
 *  RZCellSizeManagerCellConfiguration
 **/
@interface RZCellSizeManagerCellConfiguration : NSObject
@property (nonatomic, strong) id cell;
@property (nonatomic, copy) RZCellSizeManagerConfigBlock configurationBlock;
@property (nonatomic, copy) RZCellSizeManagerHeightBlock heightBlock;
@property (nonatomic, copy) RZCellSizeManagerSizeBlock sizeBlock;
@property (nonatomic, assign) Class objectClass;
@property (nonatomic, strong) NSString* cellClass;
@property (nonatomic, strong) NSString* reuseIdentifier;

+ (instancetype) cellConfigurationWithCell:(id)cell
                                 cellClass:(NSString *)cellClass
                               objectClass:(Class)objectClass
                        configurationBlock:(RZCellSizeManagerConfigBlock)configurationBlock;
+ (instancetype) cellConfigurationWithCell:(id)cell
                                 cellClass:(NSString *)cellClass
                               objectClass:(Class)objectClass
                               heightBlock:(RZCellSizeManagerHeightBlock)heightBlock;
+ (instancetype) cellConfigurationWithCell:(id)cell
                                 cellClass:(NSString *)cellClass
                               objectClass:(Class)objectClass
                                 sizeBlock:(RZCellSizeManagerSizeBlock)sizeBlock;
@end

@implementation RZCellSizeManagerCellConfiguration

+ (instancetype) cellConfigurationWithCell:(id)cell
                                 cellClass:(NSString *)cellClass
                               objectClass:(Class)objectClass
                        configurationBlock:(RZCellSizeManagerConfigBlock)configurationBlock
{
    RZCellSizeManagerCellConfiguration* config = [RZCellSizeManagerCellConfiguration new];
    config.cell = cell;
    config.cellClass = cellClass;
    config.objectClass = objectClass;
    config.configurationBlock = configurationBlock;
    return config;
}

+ (instancetype) cellConfigurationWithCell:(id)cell
                                 cellClass:(NSString *)cellClass
                               objectClass:(Class)objectClass
                               heightBlock:(RZCellSizeManagerHeightBlock)heightBlock;
{
    RZCellSizeManagerCellConfiguration* config = [RZCellSizeManagerCellConfiguration new];
    config.cell = cell;
    config.cellClass = cellClass;
    config.objectClass = objectClass;
    config.heightBlock = heightBlock;
    return config;
}

+ (instancetype) cellConfigurationWithCell:(id)cell
                                 cellClass:(NSString *)cellClass
                               objectClass:(Class)objectClass
                                 sizeBlock:(RZCellSizeManagerSizeBlock)sizeBlock
{
    RZCellSizeManagerCellConfiguration* config = [RZCellSizeManagerCellConfiguration new];
    config.cell = cell;
    config.cellClass = cellClass;
    config.objectClass = objectClass;
    config.sizeBlock = sizeBlock;
    return config;
}

@end


/**
 * RZCellHeightManager
 **/

@interface RZCellSizeManager ()
@property (nonatomic, strong) NSMutableDictionary* cellConfigurations;
@property (nonatomic, strong) id offScreenCell;
@property (nonatomic, strong) NSString* cellClassName;
@property (nonatomic, strong) NSString* cellNibName;
@property (nonatomic, strong) NSCache* cellSizeCache;

@property (nonatomic, assign) BOOL isUsingObjectTypesForLookup;

@property (nonatomic, copy) RZCellSizeManagerConfigBlock configurationBlock;
@property (nonatomic, copy) RZCellSizeManagerHeightBlock heightBlock;
@property (nonatomic, copy) RZCellSizeManagerSizeBlock sizeBlock;
@end

@implementation RZCellSizeManager

#pragma mark - Initializers

/**
 * Initializers for use with the configurationBlock method
 **/
- (instancetype)initWithCellClassName:(NSString *)cellClass
                          objectClass:(Class)objectClass
                   configurationBlock:(RZCellSizeManagerConfigBlock)configurationBlock
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        [self registerCellClassName:cellClass forObjectClass:objectClass configurationBlock:configurationBlock];
    }
    return self;
}

- (instancetype)initWithCellClassName:(NSString *)cellClass
                  cellReuseIdentifier:(NSString *)reuseIdentifier
                   configurationBlock:(RZCellSizeManagerConfigBlock)configurationBlock
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        [self registerCellClassName:cellClass forReuseIdentifier:reuseIdentifier withConfigurationBlock:configurationBlock];
    }
    return self;
}

/**
 * Initializers for use with the HeightBlock method
 **/
- (instancetype)initWithCellClassName:(NSString *)cellClass
                          objectClass:(Class)objectClass
                          heightBlock:(RZCellSizeManagerHeightBlock)heightBlock
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        [self registerCellClassName:cellClass forObjectClass:objectClass withHeightBlock:heightBlock];
    }
    return self;
}
- (instancetype)initWithCellClassName:(NSString *)cellClass
                  cellReuseIdentifier:(NSString *)reuseIdentifier
                          heightBlock:(RZCellSizeManagerHeightBlock)heightBlock
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        [self registerCellClassName:cellClass forReuseIdentifier:reuseIdentifier withHeightBlock:heightBlock];
    }
    return self;
}

/**
 * Initializers for use with the SizeBlock Method
 **/
- (instancetype)initWithCellClassName:(NSString *)cellClass
                          objectClass:(Class)objectClass
                            sizeBlock:(RZCellSizeManagerSizeBlock)sizeBlock
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        [self registerCellClassName:cellClass forObjectClass:objectClass withSizeBlock:sizeBlock];
    }
    return self;
}
- (instancetype)initWithCellClassName:(NSString *)cellClass
                  cellReuseIdentifier:(NSString *)reuseIdentifier
                            sizeBlock:(RZCellSizeManagerSizeBlock)sizeBlock
{
    self = [super init];
    if (self)
    {
        [self commonInit];
        [self registerCellClassName:cellClass forReuseIdentifier:reuseIdentifier withSizeBlock:sizeBlock];
    }
    return self;
}

/**
 * A common init function
 * Initializes the cellConfigurations dictionary and the cellSizeCache.
 **/
- (void)commonInit
{
    self.cellConfigurations = [NSMutableDictionary dictionary];
    self.cellSizeCache = [[NSCache alloc] init];
}

#pragma mark - Registration methods

- (void)registerCellClassName:(NSString *)cellClass
           forReuseIdentifier:(NSString *)reuseIdentifier
       withConfigurationBlock:(RZCellSizeManagerConfigBlock)configurationBlock
{
    id cell = [self configureOffScreenCellWithCellClassName:cellClass];
    
    RZCellSizeManagerCellConfiguration* configuration = [RZCellSizeManagerCellConfiguration cellConfigurationWithCell:cell
                                                                                                            cellClass:cellClass
                                                                                                          objectClass:nil
                                                                                                   configurationBlock:configurationBlock];
    configuration.reuseIdentifier = reuseIdentifier;
    [self.cellConfigurations setObject:configuration forKey:cellClass];
}

- (void)registerCellClassName:(NSString *)cellClass
               forObjectClass:(Class)objectClass
           configurationBlock:(RZCellSizeManagerConfigBlock)configurationBlock
{
    id cell = [self configureOffScreenCellWithCellClassName:cellClass];

    RZCellSizeManagerCellConfiguration* configuration = [RZCellSizeManagerCellConfiguration cellConfigurationWithCell:cell
                                                                                                            cellClass:cellClass
                                                                                                          objectClass:objectClass
                                                                                                   configurationBlock:configurationBlock];
    [self.cellConfigurations setObject:configuration forKey:cellClass];
}

- (void)registerCellClassName:(NSString *)cellClass
               forObjectClass:(Class)objectClass
              withHeightBlock:(RZCellSizeManagerHeightBlock)heightBlock
{
    id cell = [self configureOffScreenCellWithCellClassName:cellClass];
    RZCellSizeManagerCellConfiguration* configuration = [RZCellSizeManagerCellConfiguration cellConfigurationWithCell:cell
                                                                                                            cellClass:cellClass
                                                                                                          objectClass:objectClass
                                                                                                            heightBlock:heightBlock];
    [self.cellConfigurations setObject:configuration forKey:cellClass];
}

- (void)registerCellClassName:(NSString *)cellClass
           forReuseIdentifier:(NSString *)reuseIdentifier
              withHeightBlock:(RZCellSizeManagerHeightBlock)heightBlock
{
    id cell = [self configureOffScreenCellWithCellClassName:cellClass];
    RZCellSizeManagerCellConfiguration* configuration = [RZCellSizeManagerCellConfiguration cellConfigurationWithCell:cell
                                                                                                            cellClass:cellClass
                                                                                                          objectClass:nil
                                                                                                            heightBlock:heightBlock];
    configuration.reuseIdentifier = reuseIdentifier;
    [self.cellConfigurations setObject:configuration forKey:cellClass];
}

- (void)registerCellClassName:(NSString *)cellClass
               forObjectClass:(Class)objectClass
                withSizeBlock:(RZCellSizeManagerSizeBlock)sizeBlock
{
    id cell = [self configureOffScreenCellWithCellClassName:cellClass];
    RZCellSizeManagerCellConfiguration* configuration = [RZCellSizeManagerCellConfiguration cellConfigurationWithCell:cell
                                                                                                            cellClass:cellClass
                                                                                                          objectClass:objectClass
                                                                                                            sizeBlock:sizeBlock];
    [self.cellConfigurations setObject:configuration forKey:cellClass];
}

- (void)registerCellClassName:(NSString *)cellClass
           forReuseIdentifier:(NSString *)reuseIdentifier
                withSizeBlock:(RZCellSizeManagerSizeBlock)sizeBlock
{
    id cell = [self configureOffScreenCellWithCellClassName:cellClass];
    RZCellSizeManagerCellConfiguration* configuration = [RZCellSizeManagerCellConfiguration cellConfigurationWithCell:cell
                                                                                                            cellClass:cellClass
                                                                                                          objectClass:nil
                                                                                                            sizeBlock:sizeBlock];
    configuration.reuseIdentifier = reuseIdentifier;
    [self.cellConfigurations setObject:configuration forKey:cellClass];
}

/**
 * Creates a cell to be stored offscreen to use for AutoLayout.
 * The cell is initially created from a nib that shares the same name as the class passed in.
 *  It will then just allocate an instance using the default init.
 **/
- (id)configureOffScreenCellWithCellClassName:(NSString *)className
{
    if ([self.cellConfigurations objectForKey:className])
    {
        [self.cellConfigurations removeObjectForKey:className];
    }
    
    //Configure the static cell
    id cell = nil;
    if (className)
    {
        UINib* nib = [UINib nibWithNibName:className bundle:nil];
        cell = [[nib instantiateWithOwner:nil options:nil] objectAtIndex:0];
        [cell moveConstraintsToContentView];
    }
    
    if (!cell)
    {
        cell = [[NSClassFromString(className) alloc] init];
    }
    
    NSAssert(cell != nil, @"Cell not created successfully.  Make sure there is a cell with your class name in your project:%@",className);
    return cell;
}

/** 
 * returns the configuration object that is associated with either the object or the reuseIdentifier
 * This will first check to see if we are sending in a reuseIdentifier.  If we do, it will not try and
 *  object match, otherwise it will see if we have an object class regiserted to match the object.
 **/
- (RZCellSizeManagerCellConfiguration *)configurationForObject:(id)object reuseIdentifier:(NSString *)reuseIdentifier
{
    __block RZCellSizeManagerCellConfiguration* configuration = nil;
    if (reuseIdentifier)
    {
        [self.cellConfigurations enumerateKeysAndObjectsUsingBlock:^(id key, RZCellSizeManagerCellConfiguration* obj, BOOL *stop) {
            if ([reuseIdentifier isEqualToString:obj.reuseIdentifier])
            {
                configuration = obj;
                *stop = YES;
            }
        }];
    }
    else
    {
        [self.cellConfigurations enumerateKeysAndObjectsUsingBlock:^(id key, RZCellSizeManagerCellConfiguration* obj, BOOL *stop) {
            if ([object isKindOfClass:obj.objectClass])
            {
                configuration = obj;
                *stop = YES;
            }
        }];
    }
    
    if (!configuration)
    {
        configuration = [[self.cellConfigurations allValues] firstObject];
    }
    
    return configuration;

}

- (NSNumber *)cellHeightForObject:(id)object configuration:(RZCellSizeManagerCellConfiguration *)configuration
{
    NSNumber* height = nil;
    if (configuration)
    {
        if (configuration.configurationBlock)
        {
            configuration.configurationBlock(configuration.cell, object);
            UIView* contentView = [configuration.cell contentView];
            height = @([contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height);
        }
        else if (configuration.heightBlock)
        {
            height = @(configuration.heightBlock(configuration.cell, object));
        }
        
    }
    return height;

}


#pragma mark - Public Methods

- (void)invalidateCellSizeCache
{
    [self.cellSizeCache removeAllObjects];
}

- (void)invalidateCellSizeAtIndexPath:(NSIndexPath *)indexPath
{
    [self.cellSizeCache removeObjectForKey:indexPath];
}

- (void)invalidateCellSizesAtIndexPaths:(NSArray *)indexPaths
{
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath* obj, NSUInteger idx, BOOL *stop) {
        [self.cellSizeCache removeObjectForKey:obj];
    }];
}

- (CGFloat)cellHeightForObject:(id)object indexPath:(NSIndexPath *)indexPath
{
    return [self cellHeightForObject:object indexPath:indexPath cellReuseIdentifier:nil];
}

- (CGFloat)cellHeightForObject:(id)object indexPath:(NSIndexPath *)indexPath cellReuseIdentifier:(NSString *)reuseIdentifier
{
    NSNumber * height = [self.cellSizeCache objectForKey:indexPath];
    if (height == nil)
    {
        RZCellSizeManagerCellConfiguration* configuration = [self configurationForObject:object reuseIdentifier:reuseIdentifier];
        
        height = [self cellHeightForObject:object configuration:configuration];
        
        if (height)
        {
            [self.cellSizeCache setObject:height forKey:indexPath];
        }
    }
    return [height floatValue];
}

- (CGSize)cellSizeForObject:(id)object indexPath:(NSIndexPath *)indexPath
{
    return [self cellSizeForObject:object indexPath:indexPath cellReuseIdentifier:nil];
}

- (CGSize)cellSizeForObject:(id)object indexPath:(NSIndexPath *)indexPath cellReuseIdentifier:(NSString *)reuseIdentifier
{
    id obj = [self.cellSizeCache objectForKey:indexPath];
    CGSize size = CGSizeZero;
    if (obj == nil)
    {
        RZCellSizeManagerCellConfiguration* configuration = [self configurationForObject:object reuseIdentifier:reuseIdentifier];

        BOOL validSize = NO;
        if (configuration)
        {
            if (configuration.configurationBlock)
            {
                configuration.configurationBlock(configuration.cell, object);
                UIView* contentView = [configuration.cell contentView];
                size = [contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
                validSize = YES;

            }
            else if (configuration.heightBlock)
            {
                size = configuration.sizeBlock(configuration.cell, object);
                validSize = YES;

            }
            
        }

        
        if (validSize)
        {
            [self.cellSizeCache setObject:[NSValue valueWithCGSize:size] forKey:indexPath];
        }
        
    }
    else
    {
        // Hopefully we have an NSValue object that has a CGSize value
        if ([obj isKindOfClass:[NSValue class]])
        {
            size = [obj CGSizeValue];
        }
    }
    return size;
}

@end


