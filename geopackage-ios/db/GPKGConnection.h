//
//  GPKGConnection.h
//  geopackage-ios
//
//  Created by Brian Osborn on 5/7/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPKGResultSet.h"

@interface GPKGConnection : NSObject


@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *filename;


-(instancetype)initWithDatabaseFilename:(NSString *) filename;

-(GPKGResultSet *) rawQuery:(NSString *) statement;

-(GPKGResultSet *) queryWithTable: (NSString *) table
                       andColumns: (NSArray *) columns
                       andWhere: (NSString *) where
                       andGroupBy: (NSString *) groupBy
                       andHaving: (NSString *) having
                       andOrderBy: (NSString *) orderBy;

-(GPKGResultSet *) queryWithTable: (NSString *) table
                       andColumns: (NSArray *) columns
                       andWhere: (NSString *) where
                       andGroupBy: (NSString *) groupBy
                       andHaving: (NSString *) having
                       andOrderBy: (NSString *) orderBy
                       andLimit: (NSString *) limit;

-(int) count:(NSString *) statement;

-(int) countWithTable: (NSString *) table andWhere: (NSString *) where;

-(long long) insert:(NSString *) statement;

-(int) update:(NSString *) statement;

-(int) updateWithTable: (NSString *) table andValues: (NSMutableDictionary *) values andWhere: (NSString *) where;

-(long long) insertWithTable: (NSString *) table andValues: (NSMutableDictionary *) values;

-(int) delete:(NSString *) statement;

-(int) deleteWithTable: (NSString *) table andWhere: (NSString *) where;

-(void) exec:(NSString *) statement;

-(BOOL) tableExists: (NSString *) table;

-(void) setApplicationId;

-(void) dropTable: (NSString *) table;

-(void)close;

@end
