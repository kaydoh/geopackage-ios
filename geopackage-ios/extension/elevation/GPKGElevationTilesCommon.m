//
//  GPKGElevationTilesCommon.m
//  geopackage-ios
//
//  Created by Brian Osborn on 11/11/16.
//  Copyright © 2016 NGA. All rights reserved.
//

#import "GPKGElevationTilesCommon.h"
#import "GPKGGeoPackageConstants.h"
#import "GPKGProperties.h"
#import "GPKGElevationTilesAlgorithms.h"
#import "GPKGProjectionFactory.h"
#import "GPKGProjectionTransform.h"
#import "GPKGElevationSourcePixel.h"

NSString * const GPKG_ELEVATION_TILES_EXTENSION_NAME = @"elevation_tiles";
NSString * const GPKG_PROP_ELEVATION_TILES_EXTENSION_DEFINITION = @"geopackage.extensions.elevation_tiles";

@interface GPKGElevationTilesCommon ()

@property (nonatomic, strong) GPKGTileMatrixSet *tileMatrixSet;
@property (nonatomic, strong) GPKGGriddedCoverageDao *griddedCoverageDao;
@property (nonatomic, strong) GPKGGriddedTileDao *griddedTileDao;
@property (nonatomic, strong) GPKGGriddedCoverage *griddedCoverage;
@property (nonatomic, strong) GPKGProjection *requestProjection;
@property (nonatomic, strong) GPKGProjection *elevationProjection;
@property (nonatomic, strong) GPKGBoundingBox *elevationBoundingBox;
@property (nonatomic) BOOL sameProjection;

@end

@implementation GPKGElevationTilesCommon

-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage andTileMatrixSet: (GPKGTileMatrixSet *) tileMatrixSet andWidth: (NSNumber *) width andHeight: (NSNumber *) height andProjection: (GPKGProjection *) requestProjection{
    self = [super initWithGeoPackage:geoPackage];
    if(self != nil){
        self.extensionName = [NSString stringWithFormat:@"%@%@%@", GPKG_GEO_PACKAGE_EXTENSION_AUTHOR, GPKG_EX_EXTENSION_NAME_DIVIDER, GPKG_ELEVATION_TILES_EXTENSION_NAME];
        self.definition = [GPKGProperties getValueOfProperty:GPKG_PROP_ELEVATION_TILES_EXTENSION_DEFINITION];
        self.zoomIn = true;
        self.zoomOut = true;
        self.zoomInBeforeOut = true;
        self.algorithm = GPKG_ETA_NEAREST_NEIGHBOR;
        
        self.tileMatrixSet = tileMatrixSet;
        self.griddedCoverageDao = [geoPackage getGriddedCoverageDao];
        self.griddedTileDao = [geoPackage getGriddedTileDao];
        [self queryGriddedCoverage];
        
        self.width = width;
        self.height = height;
        self.requestProjection = requestProjection;
        self.elevationProjection = [GPKGProjectionFactory getProjectionWithSrs:[[geoPackage getTileMatrixSetDao] getSrs:tileMatrixSet]];
        self.elevationBoundingBox = [tileMatrixSet getBoundingBox];
        
        // Check if the projections have the same units
        if(requestProjection != nil){
            self.sameProjection = [requestProjection getUnit] == [self.elevationProjection getUnit];
        }else{
            self.sameProjection = true;
        }
    }
    return self;
}

-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage andTileMatrixSet: (GPKGTileMatrixSet *) tileMatrixSet{
    return [self initWithGeoPackage:geoPackage andTileMatrixSet:tileMatrixSet andWidth:nil andHeight:nil andProjection:nil];
}

-(GPKGTileMatrixSet *) tileMatrixSet{
    return _tileMatrixSet;
}

-(GPKGGriddedCoverageDao *) griddedCoverageDao{
    return _griddedCoverageDao;
}

-(GPKGGriddedTileDao *) griddedTileDao{
    return _griddedTileDao;
}

-(GPKGProjection *) requestProjection{
    return _requestProjection;
}

-(GPKGProjection *) elevationProjection{
    return _elevationProjection;
}

-(GPKGBoundingBox *) elevationBoundingBox{
    return _elevationBoundingBox;
}

-(BOOL) isSameProjection{
    return _sameProjection;
}

-(NSArray *) getOrCreate{
    
    // Create tables
    [self.geoPackage createGriddedCoverageTable];
    [self.geoPackage createGriddedTileTable];
    
    NSMutableArray * extensions = [[NSMutableArray alloc] init];
    
    GPKGExtensions * coverage = [self getOrCreateWithExtensionName:self.extensionName andTableName:GPKG_EGC_TABLE_NAME andColumnName:nil andDefinition:self.definition andScope:GPKG_EST_READ_WRITE];
    GPKGExtensions * tile = [self getOrCreateWithExtensionName:self.extensionName andTableName:GPKG_EGT_TABLE_NAME andColumnName:nil andDefinition:self.definition andScope:GPKG_EST_READ_WRITE];
    GPKGExtensions * table = [self getOrCreateWithExtensionName:self.extensionName andTableName:self.tileMatrixSet.tableName andColumnName:GPKG_TT_COLUMN_TILE_DATA andDefinition:self.definition andScope:GPKG_EST_READ_WRITE];
    
    [extensions addObject:coverage];
    [extensions addObject:tile];
    [extensions addObject:table];
    
    return extensions;
}

-(BOOL) has{
    
    BOOL exists = [self hasWithExtensionName:self.extensionName andTableName:self.tileMatrixSet.tableName andColumnName:GPKG_TT_COLUMN_TILE_DATA];
    
    return exists;
}

-(GPKGGriddedCoverage *) griddedCoverage{
    return _griddedCoverage;
}

-(GPKGGriddedCoverage *) queryGriddedCoverage{
    if([self.griddedCoverageDao tableExists]){
        self.griddedCoverage = [self.griddedCoverageDao queryByTileMatrixSet:self.tileMatrixSet];
    }
    return self.griddedCoverage;
}

-(GPKGResultSet *) griddedTile{
    GPKGResultSet * griddedTile = nil;
    if([self.griddedTileDao tableExists]){
        griddedTile = [self.griddedTileDao queryByTableName:_tileMatrixSet.tableName];
    }
    return griddedTile;
}

-(GPKGGriddedTile *) griddedTileWithTileId: (int) tileId{
    GPKGGriddedTile * griddedTile = nil;
    if([self.griddedTileDao tableExists]){
        griddedTile = [self.griddedTileDao queryByTableName:_tileMatrixSet.tableName andTileId:tileId];
    }
    return griddedTile;
}

-(NSDecimalNumber *) dataNull{
    NSDecimalNumber * dataNull = nil;
    if(self.griddedCoverage != nil){
        dataNull = self.griddedCoverage.dataNull;
    }
    return dataNull;
}

-(BOOL) isDataNull: (double) value{
    NSDecimalNumber * dataNull = [self dataNull];
    BOOL isDataNull = dataNull != nil && [dataNull doubleValue] == value;
    return isDataNull;
}

+(NSArray *) tablesForGeoPackage: (GPKGGeoPackage *) geoPackage{
    return [geoPackage getTablesByType:GPKG_CDT_ELEVATION_TILES];
}

/**
 * Reproject the elevations to the requested projection
 *
 * @param elevations
 *            elevations
 * @param requestedElevationsWidth
 *            requested elevations width
 * @param requestedElevationsHeight
 *            requested elevations height
 * @param requestBoundingBox
 *            request bounding box in the request projection
 * @param transformRequestToElevation
 *            transformation from request to elevations
 * @param elevationBoundingBox
 *            elevations bounding box
 * @return projected elevations
 */
-(NSArray *) reprojectElevations: (NSArray *) elevations withWidth: (int) requestedElevationsWidth andHeight: (int) requestedElevationsHeight andRequestBoundingBox: (GPKGBoundingBox *) requestBoundingBox andProjectionTransform: (GPKGProjectionTransform *) transformRequestToElevation andElevationBoundingBox: (GPKGBoundingBox *) elevationBoundingBox{
    
    double requestedWidthUnitsPerPixel = ([requestBoundingBox.maxLongitude doubleValue] - [requestBoundingBox.minLongitude doubleValue]) / requestedElevationsWidth;
    double requestedHeightUnitsPerPixel = ([requestBoundingBox.maxLatitude doubleValue] - [requestBoundingBox.minLatitude doubleValue]) / requestedElevationsHeight;
    
    double tilesDistanceWidth = [elevationBoundingBox.maxLongitude doubleValue] - [elevationBoundingBox.minLongitude doubleValue];
    double tilesDistanceHeight = [elevationBoundingBox.maxLatitude doubleValue] - [elevationBoundingBox.minLatitude doubleValue];
    
    int width = (int) ((NSArray *)[elevations objectAtIndex:0]).count;
    int height = (int) elevations.count;
    
    NSMutableArray * projectedElevations = [[NSMutableArray alloc] initWithCapacity:requestedElevationsHeight];
    
    // Retrieve each elevation in the unprojected elevations
    for (int y = 0; y < requestedElevationsHeight; y++) {
        NSMutableArray * elevationsRow = [[NSMutableArray alloc] initWithCapacity:requestedElevationsWidth];
        [projectedElevations addObject:elevationsRow];
        for (int x = 0; x < requestedElevationsWidth; x++) {
            
            double longitude = [requestBoundingBox.minLongitude doubleValue]
            + (x * requestedWidthUnitsPerPixel);
            double latitude = [requestBoundingBox.maxLatitude doubleValue]
            - (y * requestedHeightUnitsPerPixel);
            CLLocationCoordinate2D fromCoord = CLLocationCoordinate2DMake(latitude, longitude);
            CLLocationCoordinate2D toCoord = [transformRequestToElevation transform:fromCoord];
            double projectedLongitude = toCoord.longitude;
            double projectedLatitude = toCoord.latitude;
            
            int xPixel = (int) round(((projectedLongitude - [elevationBoundingBox.minLongitude doubleValue]) / tilesDistanceWidth)
                   * width);
            int yPixel = (int) round((([elevationBoundingBox.maxLatitude doubleValue] - projectedLatitude) / tilesDistanceHeight)
                   * height);
            
            xPixel = MAX(0, xPixel);
            xPixel = MIN(width - 1, xPixel);
            
            yPixel = MAX(0, yPixel);
            yPixel = MIN(height - 1, yPixel);
            
            NSDecimalNumber * elevation = (NSDecimalNumber *)[((NSArray *)[elevations objectAtIndex:yPixel]) objectAtIndex:xPixel];
            [elevationsRow addObject:elevation];
        }
    }
    
    return projectedElevations;
}

/**
 * Get the elevations from the rows dictionary
 *
 * @param row
 *            row number
 * @param column
 *            column number
 * @return elevations
 */
-(NSArray *) getElevationsFromDictionary: (NSDictionary *) dictionary atRow: (int) row andColumn: (int) column{
    return (NSArray *)[((NSDictionary *)[dictionary objectForKey:[NSNumber numberWithInt:row]]) objectForKey:[NSNumber numberWithInt:column]];
}

/**
 * Format the unbounded results from elevation tiles into a single double
 * array of elevation
 *
 * @param tileMatrix
 *            tile matrix
 * @param rowsDictionary
 *            rows dictionary
 * @param tileCount
 *            tile count
 * @param minRow
 *            min row
 * @param maxRow
 *            max row
 * @param minColumn
 *            min column
 * @param maxColumn
 *            max column
 * @return elevations
 */
-(NSArray *) formatUnboundedResultsWithTileMatrix: (GPKGTileMatrix *) tileMatrix andRowsDictionary: (NSDictionary *) rowsDictionary andTileCount: (int) tileCount andMinRow: (int) minRow andMaxRow: (int) maxRow andMinColumn: (int) minColumn andMaxColumn: (int) maxColumn{
    
    // Handle formatting the results
    NSMutableArray * elevations = nil;
    if(rowsDictionary.count != 0){
        
        // If only one tile result, use the elevations as the result
        if (tileCount == 1) {
            elevations = [self getElevationsFromDictionary:rowsDictionary atRow:minRow andColumn:minColumn];
        } else {
            
            // Else, combine all results into a single elevations result
            
            // Get the top left and bottom right elevations
            NSArray * topLeft = [self getElevationsFromDictionary:rowsDictionary atRow:minRow andColumn:minColumn];
            NSArray * bottomRight = [self getElevationsFromDictionary:rowsDictionary atRow:maxRow andColumn:maxColumn];
            
            // Determine the width and height of the top left elevation results
            int firstWidth = (int)((NSArray *)[topLeft objectAtIndex:0]).count;
            int firstHeight = (int) topLeft.count;
            
            // Determine the final result width and height
            int width = firstWidth;
            int height = firstHeight;
            if (minColumn < maxColumn) {
                width += ((NSArray *)[bottomRight objectAtIndex:0]).count;
                int middleColumns = maxColumn - minColumn - 1;
                if (middleColumns > 0) {
                    width += (middleColumns * [tileMatrix.tileWidth intValue]);
                }
            }
            if (minRow < maxRow) {
                height += bottomRight.count;
                long middleRows = maxRow - minRow - 1;
                if (middleRows > 0) {
                    height += (middleRows * [tileMatrix.tileHeight intValue]);
                }
            }
            
            // Create the elevation result array
            elevations = [[NSMutableArray alloc] initWithCapacity:height];
            for(int i = 0; i < height; i++){
                NSMutableArray * initialRow = [[NSMutableArray alloc] initWithCapacity:width];
                for(int j = 0; j < width; j++){
                    [initialRow addObject:[NSNull null]];
                }
                [elevations addObject:initialRow];
            }
            
            // Copy the elevation values from each tile results into the
            // final result arrays
            for(NSNumber * rowKey in rowsDictionary.allKeys){
                
                // Determine the starting base row for this tile
                int row = [rowKey intValue];
                int baseRow = 0;
                if (minRow < row) {
                    baseRow = firstHeight
                        + (int) ((row - minRow - 1) * [tileMatrix.tileHeight intValue]);
                }
                
                // Get the row's columns dictionary
                NSDictionary * columnsDictionary = [rowsDictionary objectForKey:rowKey];
                
                for(NSNumber * columnKey in columnsDictionary.allKeys){
                    
                    // Determine the starting base column for this tile
                    int column = [columnKey intValue];
                    int baseColumn = 0;
                    if (minColumn < column) {
                        baseColumn = firstWidth
                            + (int) ((column - minColumn - 1) * [tileMatrix.tileWidth intValue]);
                    }
                    
                    // Get the tiles elevation values
                    NSArray * values = [rowsDictionary objectForKey:columnKey];
                    
                    // Copy the columns array at each local elevation row to
                    // the global row and column result location
                    for (int localRow = 0; localRow < values.count; localRow++) {
                        
                        int globalRow = baseRow + localRow;
                        
                        NSArray * localRowArray = [values objectAtIndex:localRow];
                        NSMutableArray * elevationsRowArray = [elevations objectAtIndex:globalRow];
                        
                        [elevationsRowArray replaceObjectsInRange:NSMakeRange(baseColumn, localRowArray.count) withObjectsFromArray:localRowArray];
                    }
                }
            }

        }
    }
    
    return elevations;
}

/**
 * Determine the x source pixel location
 *
 * @param x
 *            x pixel
 * @param destLeft
 *            destination left most pixel
 * @param srcLeft
 *            source left most pixel
 * @param widthRatio
 *            source over destination width radio
 * @return x source pixel
 */
-(float) xSourceWithX: (int) x andDestLeft: (float) destLeft andSrcLeft: (float) srcLeft andWidthRatio: (float) widthRatio{
    float middleOfXDestPixel = (x - destLeft) + 0.5f;
    float xSourcePixel = middleOfXDestPixel * widthRatio;
    float xSource = srcLeft + xSourcePixel;
    return xSource;
}

/**
 * Determine the y source pixel location
 *
 * @param y
 *            y pixel
 * @param destTop
 *            destination top most pixel
 * @param srcTop
 *            source top most pixel
 * @param heightRatio
 *            source over destination height radio
 * @return y source pixel
 */
-(float) ySourceWithY: (int) y andDestTop: (float) destTop andSrcTop: (float) srcTop andHeightRatio: (float) heightRatio{
    float middleOfYDestPixel = (y - destTop) + 0.5f;
    float ySourcePixel = middleOfYDestPixel * heightRatio;
    float ySource = srcTop + ySourcePixel;
    return ySource;
}

/**
 * Determine the nearest neighbors of the source pixel, sorted by closest to
 * farthest neighbor
 *
 * @param xSource
 *            x source pixel
 * @param ySource
 *            y source pixel
 * @return nearest neighbor pixels
 */
-(NSArray *) nearestNeighborsWithXSource: (float) xSource andYSource: (float) ySource {
    
    NSMutableArray * results = [[NSMutableArray alloc] init];
    
    // Get the elevation source pixels for x and y
    GPKGElevationSourcePixel * xPixel = [self minAndMaxOfSource:xSource];
    GPKGElevationSourcePixel * yPixel = [self minAndMaxOfSource:ySource];
    
    // Determine which x pixel is the closest, the second closest, and the
    // distance to the second pixel
    int firstX;
    int secondX;
    float xDistance;
    if (xPixel.offset > .5) {
        firstX = xPixel.max;
        secondX = xPixel.min;
        xDistance = 1.0f - xPixel.offset;
    } else {
        firstX = xPixel.min;
        secondX = xPixel.max;
        xDistance = xPixel.offset;
    }
    
    // Determine which y pixel is the closest, the second closest, and the
    // distance to the second pixel
    int firstY;
    int secondY;
    float yDistance;
    if (yPixel.offset > .5) {
        firstY = yPixel.max;
        secondY = yPixel.min;
        yDistance = 1.0f - yPixel.offset;
    } else {
        firstY = yPixel.min;
        secondY = yPixel.max;
        yDistance = yPixel.offset;
    }
    
    // Add the closest neighbor
    [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:firstX], [NSNumber numberWithInt:firstY], nil]];
    
    // Add the second and third neighbor based upon the x and y distances to
    // second coordinates
    if (xDistance <= yDistance) {
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:secondX], [NSNumber numberWithInt:firstY], nil]];
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:firstX], [NSNumber numberWithInt:secondY], nil]];
    } else {
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:firstX], [NSNumber numberWithInt:secondY], nil]];
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:secondX], [NSNumber numberWithInt:firstY], nil]];
    }
    
    // Add the farthest neighbor
    [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:secondX], [NSNumber numberWithInt:secondY], nil]];
    
    // If right on the boundary between the forward and backwards pixel, add
    // the backwards pixel options
    if (xPixel.offset == 0) {
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:xPixel.min - 1], [NSNumber numberWithInt:yPixel.min], nil]];
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:xPixel.min - 1], [NSNumber numberWithInt:yPixel.max], nil]];
    }
    if (yPixel.offset == 0) {
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:xPixel.min], [NSNumber numberWithInt:yPixel.min - 1], nil]];
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:xPixel.max], [NSNumber numberWithInt:yPixel.min - 1], nil]];
    }
    if (xPixel.offset == 0 && yPixel.offset == 0) {
        [results addObject:[[NSArray alloc] initWithObjects:[NSNumber numberWithInt:xPixel.min - 1], [NSNumber numberWithInt:yPixel.min - 1], nil]];
    }
    
    return results;
}

/**
 * Get the min, max, and offset of the source pixel
 *
 * @param source
 *            source pixel
 * @return source pixel information
 */
-(GPKGElevationSourcePixel *) minAndMaxOfSource: (float) source{
    
    int floor = (int) floorf(source);
    int min = floor;
    int max = floor;
    float offset = source - floor;
    if (offset < .5) {
        min--;
        offset += .5f;
    } else if (offset >= .5) {
        max++;
        offset -= .5f;
    }
    
    return [[GPKGElevationSourcePixel alloc] initWithPixel:source andMin:min andMax:max andOffset:offset];
}

/**
 * Get the Bilinear Interpolation elevation value
 *
 * @param sourcePixelX
 *            source pixel x
 * @param sourcePixelY
 *            source pixel y
 * @param values
 *            2 x 2 elevation values as [y][x]
 * @return elevation
 */
-(NSDecimalNumber *) bilinearInterpolationElevationWithSourcePixelX: (GPKGElevationSourcePixel *) sourcePixelX andSourcePixelY: (GPKGElevationSourcePixel *) sourcePixelY andValues: (NSArray *) values{
    return [self bilinearInterpolationElevationWithOffsetX:sourcePixelX.offset andOffsetY:sourcePixelY.offset andMinX:sourcePixelX.min andMaxX:sourcePixelX.max andMinY:sourcePixelY.min andMaxY:sourcePixelY.max andValues:values];
}

/**
 * Get the Bilinear Interpolation elevation value
 *
 * @param offsetX
 *            x source pixel offset
 * @param offsetY
 *            y source pixel offset
 * @param minX
 *            min x value
 * @param maxX
 *            max x value
 * @param minY
 *            min y value
 * @param maxY
 *            max y value
 * @param values
 *            2 x 2 elevation values as [y][x]
 * @return elevation
 */
-(NSDecimalNumber *) bilinearInterpolationElevationWithOffsetX: (float) offsetX andOffsetY: (float) offsetY andMinX: (float) minX andMaxX: (float) maxX andMinY: (float) minY andMaxY: (float) maxY andValues: (NSArray *) values{
    
    NSDecimalNumber * elevation = nil;
    
    if (values != nil) {
        NSArray * top = [values objectAtIndex:0];
        NSArray * bottom = [values objectAtIndex:1];
        elevation = [self bilinearInterpolationElevationWithOffsetX:offsetX andOffsetY:offsetY andMinX:minX andMaxX:maxX andMinY:minY andMaxY:maxY andTopLeft:[top objectAtIndex:0] andTopRight:[top objectAtIndex:1] andBottomLeft:[bottom objectAtIndex:0] andBottomRight:[bottom objectAtIndex:1]];
    }
    
    return elevation;
}

/**
 * Get the Bilinear Interpolation elevation value
 *
 * @param offsetX
 *            x source pixel offset
 * @param offsetY
 *            y source pixel offset
 * @param minX
 *            min x value
 * @param maxX
 *            max x value
 * @param minY
 *            min y value
 * @param maxY
 *            max y value
 * @param topLeft
 *            top left elevation
 * @param topRight
 *            top right elevation
 * @param bottomLeft
 *            bottom left elevation
 * @param bottomRight
 *            bottom right elevation
 * @return elevation
 */
-(NSDecimalNumber *) bilinearInterpolationElevationWithOffsetX: (float) offsetX andOffsetY: (float) offsetY andMinX: (float) minX andMaxX: (float) maxX andMinY: (float) minY andMaxY: (float) maxY andTopLeft: (NSDecimalNumber *) topLeft andTopRight: (NSDecimalNumber *) topRight andBottomLeft: (NSDecimalNumber *) bottomLeft andBottomRight: (NSDecimalNumber *) bottomRight{
    
    NSDecimalNumber * elevation = nil;
    
    if (topLeft != nil && (topRight != nil || minX == maxX)
        && (bottomLeft != nil || minY == maxY)
        && (bottomRight != nil || (minX == maxX && minY == maxY))) {
        
        float diffX = maxX - minX;
        
        double topRow;
        double bottomRow;
        if (diffX == 0) {
            topRow = [topLeft doubleValue];
            bottomRow = [bottomLeft doubleValue];
        } else {
            float diffLeft = offsetX;
            float diffRight = diffX - offsetX;
            topRow = ((diffRight / diffX) * [topLeft doubleValue])
                + ((diffLeft / diffX) * [topRight doubleValue]);
            bottomRow = ((diffRight / diffX) * [bottomLeft doubleValue])
                + ((diffLeft / diffX) * [bottomRight doubleValue]);
        }
        
        float diffY = maxY - minY;
        
        double result;
        if (diffY == 0) {
            result = topRow;
        } else {
            float diffTop = offsetY;
            float diffBottom = diffY - offsetY;
            result = ((diffBottom / diffY) * topRow)
                + ((diffTop / diffY) * bottomRow);
        }
        
        elevation = [[NSDecimalNumber alloc] initWithDouble:result];
    }
    
    return elevation;
}

/**
 * Get the bicubic interpolation elevation from the 4 x 4 elevation values
 *
 * @param values
 *            elevation values
 * @param sourcePixelX
 *            source pixel x
 * @param sourcePixelY
 *            source pixel y
 * @return bicubic elevation
 */
-(NSDecimalNumber *) bicubicInterpolationElevationWithValues: (NSArray *) values andSourcePixelX: (GPKGElevationSourcePixel *) sourcePixelX andSourcePixelY: (GPKGElevationSourcePixel *) sourcePixelY{
    return [self bicubicInterpolationElevationWithValues:values andOffsetX:sourcePixelX.offset andOffsetY:sourcePixelY.offset];
}

/**
 * Get the bicubic interpolation elevation from the 4 x 4 elevation values
 *
 * @param values
 *            elevation values
 * @param offsetX
 *            x source pixel offset
 * @param offsetY
 *            y source pixel offset
 * @return bicubic elevation
 */
-(NSDecimalNumber *) bicubicInterpolationElevationWithValues: (NSArray *) values andOffsetX: (float) offsetX andOffsetY: (float) offsetY{

    NSDecimalNumber * elevation = nil;
    
    NSMutableArray * rowValues = [[NSMutableArray alloc] initWithCapacity:4];
    
    for (int y = 0; y < 4; y++) {
        NSArray * yValues = [values objectAtIndex:y];
        NSDecimalNumber * rowElevation = [self cubicInterpolationElevationWithValue0:[yValues objectAtIndex:0] andValue1:[yValues objectAtIndex:1] andValue2:[yValues objectAtIndex:2] andValue3:[yValues objectAtIndex:3] andOffset:offsetX];
        if (rowElevation == nil) {
            rowValues = nil;
            break;
        }
        [rowValues addObject:rowElevation];
    }
    
    if (rowValues != nil) {
        elevation = [self cubicInterpolationElevationWithValues:rowValues andOffset:offsetY];
    }
    
    return elevation;
}

/**
 * Interpolate 4 values using the offset between value1 and value2
 *
 * @param values
 *            elevation values
 * @param offset
 *            offset between the middle two pixels
 * @return value elevation value
 */
-(NSDecimalNumber *) cubicInterpolationElevationWithValues: (NSArray *) values andOffset: (double) offset{
    
    NSDecimalNumber * elevation = nil;
    if (values != nil) {
        elevation = [self cubicInterpolationElevationWithValue0:values[0] andValue1: values[1]
                                                      andValue2: values[2] andValue3: values[3] andOffset:offset];
    }
    return elevation;
}

/**
 * Interpolate 4 values using the offset between value1 and value2
 *
 * @param value0
 *            index 0 value
 * @param value1
 *            index 1 value
 * @param value2
 *            index 2 value
 * @param value3
 *            index 3 value
 * @param offset
 *            offset between the middle two pixels
 * @return value elevation value
 */
-(NSDecimalNumber *) cubicInterpolationElevationWithValue0: (NSDecimalNumber *) value0 andValue1: (NSDecimalNumber *) value1 andValue2: (NSDecimalNumber *) value2 andValue3: (NSDecimalNumber *) value3 andOffset: (double) offset{
    
    NSDecimalNumber * elevation = nil;
    
    if (value0 != nil && value1 != nil && value2 != nil
        && value3 != nil) {
        
        double coefficient0 = 2 * [value1 doubleValue];
        double coefficient1 = [value2 doubleValue] - [value0 doubleValue];
        double coefficient2 = 2 * [value0 doubleValue] - 5 * [value1 doubleValue] + 4 * [value2 doubleValue] - [value3 doubleValue];
        double coefficient3 = -[value0 doubleValue] + 3 * [value1 doubleValue] - 3 * [value2 doubleValue] + [value3 doubleValue];
        double elevationDouble = (coefficient3 * offset * offset * offset + coefficient2
                     * offset * offset + coefficient1 * offset + coefficient0) / 2;
        elevation = [[NSDecimalNumber alloc] initWithDouble:elevationDouble];
    }
    
    return elevation;
}

/**
 * Pad the bounding box with extra space for the overlapping pixels
 *
 * @param tileMatrix
 *            tile matrix
 * @param boundingBox
 *            bounding box
 * @param overlap
 *            overlapping pixels
 * @return padded bounding box
 */
-(GPKGBoundingBox *) padBoundingBoxWithTileMatrix: (GPKGTileMatrix *) tileMatrix andBoundingBox: (GPKGBoundingBox *) boundingBox andOverlap: (int) overlap{

    double lonPixelPadding = [tileMatrix.pixelXSize doubleValue] * overlap;
    double latPixelPadding = [tileMatrix.pixelYSize doubleValue] * overlap;
    GPKGBoundingBox * paddedBoundingBox = [[GPKGBoundingBox alloc] initWithMinLongitudeDouble:[boundingBox.minLongitude doubleValue] - lonPixelPadding
                                                                        andMaxLongitudeDouble:[boundingBox.maxLongitude doubleValue] + lonPixelPadding
                                                                         andMinLatitudeDouble:[boundingBox.minLatitude doubleValue] - latPixelPadding
                                                                         andMaxLatitudeDouble:[boundingBox.maxLatitude doubleValue] + latPixelPadding];
    return paddedBoundingBox;
}

-(unsigned short) pixelValueWithValues:(unsigned short[]) pixelValues andWidth: (int) width andX: (int) x andY: (int) y{
    return pixelValues[(y * width) + x];
}

-(NSDecimalNumber *) elevationValueWithGriddedTile: (GPKGGriddedTile *) griddedTile andPixelValue: (unsigned short) pixelValue{
    
    NSDecimalNumber * elevation = nil;
    if (![self isDataNull:pixelValue]) {
        elevation = [self pixelValueToElevationWithGriddedTile:griddedTile andPixelValue:[[NSDecimalNumber alloc] initWithUnsignedShort:pixelValue]];
    }
    
    return elevation;
}

-(NSDecimalNumber *) pixelValueToElevationWithGriddedTile: (GPKGGriddedTile *) griddedTile andPixelValue: (NSDecimalNumber *) pixelValue{

    NSDecimalNumber * elevation = nil;
    
    if (self.griddedCoverage != nil
        && [self.griddedCoverage getGriddedCoverageDataType] == GPKG_GCDT_INTEGER) {
        
        double elevationValue = [pixelValue doubleValue];
        
        if (griddedTile != nil) {
            if (griddedTile.scale != nil) {
                elevationValue *= [griddedTile.scale doubleValue];
            }
            if (griddedTile.offset != nil) {
                elevationValue += [griddedTile.offset doubleValue];
            }
        }
        if (self.griddedCoverage.scale != nil) {
            elevationValue *= [self.griddedCoverage.scale doubleValue];
        }
        if (self.griddedCoverage.offset != nil) {
            elevationValue += [self.griddedCoverage.offset doubleValue];
        }
     
        elevation = [[NSDecimalNumber alloc] initWithDouble:elevationValue];
    }
    
    return elevation;
}



@end
